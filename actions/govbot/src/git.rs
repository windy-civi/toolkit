use crate::error::{Error, Result};
use git2::{build::RepoBuilder, FetchOptions, RemoteCallbacks, Repository};
use std::path::{Path, PathBuf};

/// Get the default repos directory: $HOME/.govbot/repos
pub fn default_repos_dir() -> Result<PathBuf> {
    let home = std::env::var("HOME")
        .or_else(|_| std::env::var("USERPROFILE"))
        .map_err(|_| {
            Error::Config(
                "Could not determine home directory. Set HOME or USERPROFILE environment variable."
                    .to_string(),
            )
        })?;

    Ok(PathBuf::from(home).join(".govbot").join("repos"))
}

/// Build callbacks for git operations with optional token authentication
fn build_callbacks(token: Option<&str>) -> RemoteCallbacks<'_> {
    let mut callbacks = RemoteCallbacks::new();
    let token = token.map(|t| t.to_string());

    callbacks.credentials(move |_url, _username, _allowed| {
        if let Some(ref token) = token {
            // For GitHub, use "x-access-token" as username with token as password
            // This is the standard GitHub PAT authentication method
            git2::Cred::userpass_plaintext("x-access-token", token)
        } else {
            // Try default credentials if no token provided
            git2::Cred::default()
        }
    });

    callbacks
}

/// Clone a repository for a given locale
pub fn clone_repo(locale: &str, repos_dir: &Path, token: Option<&str>) -> Result<()> {
    let repo_name = format!("{}-data-pipeline", locale);
    let repo_path = "windy-civi-pipelines/".to_string() + &repo_name;
    let target_dir = repos_dir.join(&repo_name);

    // Build clone URL (always use HTTPS, token will be in credentials)
    let clone_url = format!("https://github.com/{}.git", repo_path);

    // Check if repository already exists
    if target_dir.exists() && Repository::open(&target_dir).is_ok() {
        eprintln!("Repository already exists: {}", repo_path);
        eprintln!("Pulling latest changes from {}", target_dir.display());

        // Open existing repository and pull
        let repo = Repository::open(&target_dir)
            .map_err(|e| Error::Config(format!("Failed to open repository: {}", e)))?;

        // Pull the latest changes (credentials will be used if token is provided)
        pull_repo_internal(&repo, token)?;

        eprintln!("Successfully pulled {}", repo_path);
        return Ok(());
    }

    // Remove existing directory if it exists (but is not a git repo)
    if target_dir.exists() {
        eprintln!("Removing existing directory: {}", target_dir.display());
        std::fs::remove_dir_all(&target_dir)?;
    }

    // Clone the repository
    eprintln!("Cloning repository: {}", repo_path);

    let mut fetch_options = FetchOptions::new();
    fetch_options.depth(1); // Shallow clone
    fetch_options.remote_callbacks(build_callbacks(token));

    let mut builder = RepoBuilder::new();
    builder.fetch_options(fetch_options);

    builder.clone(&clone_url, &target_dir).map_err(|e| {
        Error::Config(format!(
            "Failed to shallow clone repository {}: {}",
            repo_path, e
        ))
    })?;

    eprintln!(
        "Successfully cloned {} into {}",
        repo_path,
        target_dir.display()
    );
    Ok(())
}

/// Internal function to pull changes from a repository
fn pull_repo_internal(repo: &Repository, token: Option<&str>) -> Result<()> {
    // Fetch from remote
    let mut remote = repo
        .find_remote("origin")
        .map_err(|e| Error::Config(format!("Failed to find remote 'origin': {}", e)))?;

    let mut fetch_options = FetchOptions::new();
    fetch_options.remote_callbacks(build_callbacks(token));

    remote
        .fetch(
            &["refs/heads/*:refs/remotes/origin/*"],
            Some(&mut fetch_options),
            None,
        )
        .map_err(|e| Error::Config(format!("Failed to fetch from remote: {}", e)))?;

    // Get the remote tracking branch
    let fetch_head = repo
        .find_reference("FETCH_HEAD")
        .map_err(|e| Error::Config(format!("Failed to find FETCH_HEAD: {}", e)))?;

    let fetch_commit = repo
        .reference_to_annotated_commit(&fetch_head)
        .map_err(|e| Error::Config(format!("Failed to get commit from FETCH_HEAD: {}", e)))?;

    // Get the current branch
    let head = repo
        .head()
        .map_err(|e| Error::Config(format!("Failed to get HEAD: {}", e)))?;

    let analysis = repo
        .merge_analysis(&[&fetch_commit])
        .map_err(|e| Error::Config(format!("Failed to analyze merge: {}", e)))?;

    if analysis.0.is_up_to_date() {
        // Already up to date
        return Ok(());
    } else if analysis.0.is_fast_forward() {
        // Fast-forward merge
        let mut reference = head
            .resolve()
            .map_err(|e| Error::Config(format!("Failed to resolve HEAD: {}", e)))?;
        reference
            .set_target(fetch_commit.id(), "Fast-forward")
            .map_err(|e| Error::Config(format!("Failed to update reference: {}", e)))?;
        repo.set_head(reference.name().unwrap())
            .map_err(|e| Error::Config(format!("Failed to set HEAD: {}", e)))?;
        repo.checkout_head(Some(git2::build::CheckoutBuilder::default().force()))
            .map_err(|e| Error::Config(format!("Failed to checkout: {}", e)))?;
    } else {
        // Need to merge
        return Err(Error::Config(
            "Repository has diverged and cannot be fast-forwarded. Please resolve manually."
                .to_string(),
        ));
    }

    Ok(())
}

/// Pull a repository for a given locale
pub fn pull_repo(locale: &str, repos_dir: &Path, token: Option<&str>) -> Result<()> {
    let repo_name = format!("{}-data-pipeline", locale);
    let repo_path = "windy-civi-pipelines/".to_string() + &repo_name;
    let target_dir = repos_dir.join(&repo_name);

    let repo = match Repository::open(&target_dir) {
        Ok(repo) => repo,
        Err(_) => {
            eprintln!("Repository does not exist: {}. Skipping.", repo_path);
            return Ok(());
        }
    };

    // Pull the latest changes (credentials will be used if token is provided)
    eprintln!("Pulling repository: {}", repo_path);

    pull_repo_internal(&repo, token)?;

    eprintln!("Successfully pulled {}", repo_path);
    Ok(())
}

/// Get all available locale repositories in the repos directory
pub fn get_available_locales(repos_dir: &Path) -> Result<Vec<String>> {
    if !repos_dir.exists() {
        return Ok(Vec::new());
    }

    let mut locales = Vec::new();

    for entry in std::fs::read_dir(repos_dir)? {
        let entry = entry?;
        let path = entry.path();

        if path.is_dir() && Repository::open(&path).is_ok() {
            if let Some(dir_name) = path.file_name().and_then(|n| n.to_str()) {
                if let Some(locale) = dir_name.strip_suffix("-data-pipeline") {
                    locales.push(locale.to_string());
                }
            }
        }
    }

    Ok(locales)
}
