use crate::error::{Error, Result};
use git2::{build::RepoBuilder, FetchOptions, RemoteCallbacks, Repository};
use std::fs;
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
fn build_callbacks(token: Option<&str>, show_progress: bool) -> RemoteCallbacks<'_> {
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

    if show_progress {
        callbacks.transfer_progress(|stats| {
            if stats.total_objects() > 0 {
                let received = stats.received_objects();
                let total = stats.total_objects();
                let percent = if total > 0 {
                    (received * 100) / total
                } else {
                    0
                };

                if received == total {
                    eprint!(
                        "\rReceiving objects: {}/{} (100%)... done.                    \n",
                        received, total
                    );
                } else {
                    eprint!(
                        "\rReceiving objects: {}/{} ({:3}%)",
                        received, total, percent
                    );
                }
            } else {
                eprint!("\rReceiving objects: {}...", stats.received_objects());
            }
            true
        });
    }

    callbacks
}

/// Clone or pull a repository for a given locale with quiet option
/// Returns action: "clone", "pulled", or "no_updates"
pub fn clone_or_pull_repo_quiet(
    locale: &str,
    repos_dir: &Path,
    token: Option<&str>,
    quiet: bool,
) -> Result<&'static str> {
    let repo_name = format!("{}-data-pipeline", locale);
    let repo_path = "windy-civi-pipelines/".to_string() + &repo_name;
    let target_dir = repos_dir.join(&repo_name);

    // Build clone URL (always use HTTPS, token will be in credentials)
    let clone_url = format!("https://github.com/{}.git", repo_path);

    // Check if repository already exists
    if target_dir.exists() && Repository::open(&target_dir).is_ok() {
        // Repository exists, pull instead
        let repo = Repository::open(&target_dir)
            .map_err(|e| Error::Config(format!("Failed to open repository: {}", e)))?;

        // Pull the latest changes (credentials will be used if token is provided)
        let had_updates = pull_repo_internal(&repo, token, quiet)?;
        return Ok(if had_updates { "pulled" } else { "no_updates" });
    }

    // Remove existing directory if it exists (but is not a git repo)
    if target_dir.exists() {
        if !quiet {
            eprintln!("Removing existing directory: {}", target_dir.display());
        }
        std::fs::remove_dir_all(&target_dir)?;
    }

    // Repository doesn't exist, clone it

    let mut fetch_options = FetchOptions::new();
    fetch_options.depth(1); // Shallow clone
    fetch_options.remote_callbacks(build_callbacks(token, !quiet));

    let mut builder = RepoBuilder::new();
    builder.fetch_options(fetch_options);

    builder.clone(&clone_url, &target_dir).map_err(|e| {
        Error::Config(format!(
            "Failed to shallow clone repository {}: {}",
            repo_path, e
        ))
    })?;

    // After cloning, check if we need to set HEAD to main or master
    let repo = Repository::open(&target_dir)
        .map_err(|e| Error::Config(format!("Failed to open cloned repository: {}", e)))?;

    // Try to find the default branch (main or master)
    // Check local branches first
    let default_branch = if repo.find_branch("main", git2::BranchType::Local).is_ok() {
        "main"
    } else if repo.find_branch("master", git2::BranchType::Local).is_ok() {
        "master"
    } else {
        // Check remote branches
        if repo
            .find_branch("origin/main", git2::BranchType::Remote)
            .is_ok()
        {
            // Create local main branch from remote
            let remote_branch = repo.find_branch("origin/main", git2::BranchType::Remote)?;
            let commit = remote_branch.get().target().ok_or_else(|| {
                Error::Config("Failed to get commit from origin/main".to_string())
            })?;
            let commit_obj = repo.find_commit(commit)?;
            repo.branch("main", &commit_obj, false)?;
            "main"
        } else if repo
            .find_branch("origin/master", git2::BranchType::Remote)
            .is_ok()
        {
            // Create local master branch from remote
            let remote_branch = repo.find_branch("origin/master", git2::BranchType::Remote)?;
            let commit = remote_branch.get().target().ok_or_else(|| {
                Error::Config("Failed to get commit from origin/master".to_string())
            })?;
            let commit_obj = repo.find_commit(commit)?;
            repo.branch("master", &commit_obj, false)?;
            "master"
        } else {
            return Err(Error::Config(
                "Neither 'main' nor 'master' branch found in repository".to_string(),
            ));
        }
    };

    // Set HEAD to the default branch if it's not already set correctly
    if let Ok(head) = repo.head() {
        if let Some(head_name) = head.name() {
            if head_name != format!("refs/heads/{}", default_branch) {
                // HEAD points to a different branch, update it
                repo.set_head(&format!("refs/heads/{}", default_branch))
                    .map_err(|e| {
                        Error::Config(format!("Failed to set HEAD to {}: {}", default_branch, e))
                    })?;
                repo.checkout_head(Some(git2::build::CheckoutBuilder::default().force()))
                    .map_err(|e| {
                        Error::Config(format!("Failed to checkout {}: {}", default_branch, e))
                    })?;
            }
        }
    } else {
        // HEAD doesn't exist, set it to the default branch
        repo.set_head(&format!("refs/heads/{}", default_branch))
            .map_err(|e| {
                Error::Config(format!("Failed to set HEAD to {}: {}", default_branch, e))
            })?;
        repo.checkout_head(Some(git2::build::CheckoutBuilder::default().force()))
            .map_err(|e| Error::Config(format!("Failed to checkout {}: {}", default_branch, e)))?;
    }

    // Clear any progress line
    if !quiet {
        eprint!(
            "\r                                                                                \r"
        );
    }
    Ok("clone")
}

/// Clone or pull a repository for a given locale (clones if doesn't exist, pulls if it does)
pub fn clone_or_pull_repo(locale: &str, repos_dir: &Path, token: Option<&str>) -> Result<()> {
    clone_or_pull_repo_quiet(locale, repos_dir, token, false).map(|_| ())
}

/// Clone a repository for a given locale (deprecated - use clone_or_pull_repo)
pub fn clone_repo(locale: &str, repos_dir: &Path, token: Option<&str>) -> Result<()> {
    clone_or_pull_repo(locale, repos_dir, token)
}

/// Clone a repository for a given locale with quiet option (deprecated - use clone_or_pull_repo_quiet)
pub fn clone_repo_quiet(
    locale: &str,
    repos_dir: &Path,
    token: Option<&str>,
    quiet: bool,
) -> Result<()> {
    clone_or_pull_repo_quiet(locale, repos_dir, token, quiet).map(|_| ())
}

/// Internal function to pull changes from a repository
/// Returns true if updates were made, false if already up to date
fn pull_repo_internal(repo: &Repository, token: Option<&str>, quiet: bool) -> Result<bool> {
    // Determine the current local branch name
    let head = repo
        .head()
        .map_err(|e| Error::Config(format!("Failed to get HEAD: {}", e)))?;

    let local_branch_name = head
        .name()
        .and_then(|name| name.strip_prefix("refs/heads/"))
        .ok_or_else(|| Error::Config("Failed to determine local branch name".to_string()))?;

    // Fetch from remote - try both main and master
    let mut remote = repo
        .find_remote("origin")
        .map_err(|e| Error::Config(format!("Failed to find remote 'origin': {}", e)))?;

    let mut fetch_options = FetchOptions::new();
    fetch_options.remote_callbacks(build_callbacks(token, !quiet));

    // Fetch both main and master branches (only fail if both fail)
    let refspecs = vec![
        "refs/heads/main:refs/remotes/origin/main",
        "refs/heads/master:refs/remotes/origin/master",
    ];

    // Try to fetch both branches - ignore errors for individual branches
    let fetch_result = remote.fetch(&refspecs, Some(&mut fetch_options), None);

    // If fetch completely fails, return error
    if fetch_result.is_err() {
        // Check if at least one branch exists remotely by trying to find them
        let has_main = repo
            .find_branch("origin/main", git2::BranchType::Remote)
            .is_ok();
        let has_master = repo
            .find_branch("origin/master", git2::BranchType::Remote)
            .is_ok();

        if !has_main && !has_master {
            return Err(Error::Config(
                "Failed to fetch from remote and neither 'main' nor 'master' branch found"
                    .to_string(),
            ));
        }
        // If at least one exists, continue (fetch might have partially succeeded)
    }

    // Determine which remote branch to use based on local branch
    // If local is main, use origin/main; if local is master, use origin/master
    // Otherwise, prefer main over master
    let (remote_branch_name, target_local_branch) = if local_branch_name == "main" {
        if repo
            .find_branch("origin/main", git2::BranchType::Remote)
            .is_ok()
        {
            ("origin/main", "main")
        } else if repo
            .find_branch("origin/master", git2::BranchType::Remote)
            .is_ok()
        {
            ("origin/master", "master")
        } else {
            return Err(Error::Config(
                "Neither 'main' nor 'master' branch found in remote repository".to_string(),
            ));
        }
    } else if local_branch_name == "master" {
        if repo
            .find_branch("origin/master", git2::BranchType::Remote)
            .is_ok()
        {
            ("origin/master", "master")
        } else if repo
            .find_branch("origin/main", git2::BranchType::Remote)
            .is_ok()
        {
            ("origin/main", "main")
        } else {
            return Err(Error::Config(
                "Neither 'main' nor 'master' branch found in remote repository".to_string(),
            ));
        }
    } else {
        // Local branch is neither main nor master - prefer main, fallback to master
        if repo
            .find_branch("origin/main", git2::BranchType::Remote)
            .is_ok()
        {
            ("origin/main", "main")
        } else if repo
            .find_branch("origin/master", git2::BranchType::Remote)
            .is_ok()
        {
            ("origin/master", "master")
        } else {
            return Err(Error::Config(
                "Neither 'main' nor 'master' branch found in remote repository".to_string(),
            ));
        }
    };

    let remote_branch = repo
        .find_branch(remote_branch_name, git2::BranchType::Remote)
        .map_err(|e| {
            Error::Config(format!(
                "Failed to find remote branch {}: {}",
                remote_branch_name, e
            ))
        })?;

    let remote_commit = remote_branch.get().target().ok_or_else(|| {
        Error::Config(format!("Failed to get commit from {}", remote_branch_name))
    })?;

    let fetch_commit = repo
        .find_annotated_commit(remote_commit)
        .map_err(|e| Error::Config(format!("Failed to get annotated commit: {}", e)))?;

    // If local branch doesn't match the target, switch to it
    if local_branch_name != target_local_branch {
        // Check if local branch exists, if not create it
        if repo
            .find_branch(target_local_branch, git2::BranchType::Local)
            .is_err()
        {
            let commit_obj = repo.find_commit(remote_commit)?;
            repo.branch(target_local_branch, &commit_obj, false)?;
        }

        repo.set_head(&format!("refs/heads/{}", target_local_branch))
            .map_err(|e| {
                Error::Config(format!(
                    "Failed to set HEAD to {}: {}",
                    target_local_branch, e
                ))
            })?;
        repo.checkout_head(Some(git2::build::CheckoutBuilder::default().force()))
            .map_err(|e| {
                Error::Config(format!("Failed to checkout {}: {}", target_local_branch, e))
            })?;
    }

    let analysis = repo
        .merge_analysis(&[&fetch_commit])
        .map_err(|e| Error::Config(format!("Failed to analyze merge: {}", e)))?;

    if analysis.0.is_up_to_date() {
        // Already up to date
        return Ok(false);
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

        // Updates were made
        return Ok(true);
    } else {
        // Need to merge
        return Err(Error::Config(
            "Repository has diverged and cannot be fast-forwarded. Please resolve manually."
                .to_string(),
        ));
    }
}

/// Pull a repository for a given locale
pub fn pull_repo(locale: &str, repos_dir: &Path, token: Option<&str>) -> Result<()> {
    pull_repo_quiet(locale, repos_dir, token, false)
}

/// Pull a repository for a given locale with quiet option
pub fn pull_repo_quiet(
    locale: &str,
    repos_dir: &Path,
    token: Option<&str>,
    quiet: bool,
) -> Result<()> {
    let repo_name = format!("{}-data-pipeline", locale);
    let repo_path = "windy-civi-pipelines/".to_string() + &repo_name;
    let target_dir = repos_dir.join(&repo_name);

    let repo = match Repository::open(&target_dir) {
        Ok(repo) => repo,
        Err(_) => {
            if !quiet {
                eprintln!("Repository does not exist: {}. Skipping.", repo_path);
            }
            return Ok(());
        }
    };

    // Pull the latest changes (credentials will be used if token is provided)
    if !quiet {
        eprintln!("Pulling repository: {}", repo_path);
    }

    pull_repo_internal(&repo, token, quiet)?;

    // Clear any progress line
    if !quiet {
        eprint!(
            "\r                                                                                \r"
        );
        eprintln!("Successfully pulled {}", repo_path);
    }
    Ok(())
}

/// Calculate the size of a directory in bytes
pub fn get_directory_size(path: &Path) -> Result<u64> {
    if !path.exists() {
        return Ok(0);
    }

    let mut total_size = 0u64;

    fn calculate_size(entry: &fs::DirEntry, total: &mut u64) -> Result<()> {
        let metadata = entry.metadata()?;
        if metadata.is_file() {
            *total += metadata.len();
        } else if metadata.is_dir() {
            // Recursively calculate size of subdirectories
            for sub_entry in fs::read_dir(entry.path())? {
                let sub_entry = sub_entry?;
                calculate_size(&sub_entry, total)?;
            }
        }
        Ok(())
    }

    for entry in fs::read_dir(path)? {
        let entry = entry?;
        calculate_size(&entry, &mut total_size)?;
    }

    Ok(total_size)
}

/// Format bytes into human-readable format
pub fn format_size(bytes: u64) -> String {
    const UNITS: &[&str] = &["B", "KB", "MB", "GB", "TB"];
    const THRESHOLD: f64 = 1024.0;

    if bytes == 0 {
        return "0 B".to_string();
    }

    let bytes_f = bytes as f64;
    let exp = (bytes_f.ln() / THRESHOLD.ln()).floor() as usize;
    let exp = exp.min(UNITS.len() - 1);

    let size = bytes_f / THRESHOLD.powi(exp as i32);

    if exp == 0 {
        format!("{} {}", bytes, UNITS[exp])
    } else {
        format!("{:.1} {}", size, UNITS[exp])
    }
}

/// Get estimated remote repository size by doing a lightweight fetch
/// This fetches only refs and estimates size from transfer progress
pub fn get_remote_repo_size_estimate(
    repo: &Repository,
    token: Option<&str>,
    _quiet: bool,
) -> Result<u64> {
    use std::sync::{Arc, Mutex};

    let mut remote = repo
        .find_remote("origin")
        .map_err(|e| Error::Config(format!("Failed to find remote 'origin': {}", e)))?;

    let size_estimate = Arc::new(Mutex::new(0u64));
    let size_estimate_clone = size_estimate.clone();

    let mut fetch_options = FetchOptions::new();
    let token = token.map(|t| t.to_string());

    let mut callbacks = RemoteCallbacks::new();
    callbacks.credentials(move |_url, _username, _allowed| {
        if let Some(ref token) = token {
            git2::Cred::userpass_plaintext("x-access-token", token)
        } else {
            git2::Cred::default()
        }
    });

    // Track transfer progress to estimate size
    callbacks.transfer_progress(move |stats| {
        // received_bytes() gives us the total bytes received so far
        let bytes = stats.received_bytes() as u64;
        let mut size = size_estimate_clone.lock().unwrap();
        *size = bytes;
        true
    });

    fetch_options.remote_callbacks(callbacks);

    // Do a lightweight fetch - fetch refs only, not objects
    // This will give us size information without downloading everything
    let _fetch_result = remote.fetch(
        &["refs/heads/*:refs/remotes/origin/*"],
        Some(&mut fetch_options),
        None,
    );

    // Even if fetch fails, we might have gotten some size info
    let estimated_size = *size_estimate.lock().unwrap();

    if estimated_size > 0 {
        Ok(estimated_size)
    } else {
        // Fallback: estimate from local pack files if they exist
        let pack_dir = repo.path().join("objects").join("pack");
        if pack_dir.exists() {
            Ok(get_directory_size(&pack_dir).unwrap_or(0))
        } else {
            Ok(0)
        }
    }
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
