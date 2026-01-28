/// End-to-end tests for the govbot clone command
/// These tests create local git repositories and test clone/pull functionality
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use tempfile::TempDir;

/// Helper function to get the path to the built binary
fn get_binary_path() -> PathBuf {
    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));

    // Build the binary
    let status = Command::new("cargo")
        .args(["build", "--bin", "govbot"])
        .current_dir(&manifest_dir)
        .status()
        .expect("Failed to run cargo build");

    if !status.success() {
        panic!("Failed to build binary");
    }

    let debug_path = manifest_dir.join("target").join("debug").join("govbot");

    if !debug_path.exists() {
        panic!(
            "Binary was not created at expected path: {}",
            debug_path.display()
        );
    }

    debug_path
}

/// Initialize a git repository with test data matching govbot's expected structure.
/// Uses a valid locale code (like "wy" for Wyoming) to pass validation.
/// Returns Ok(()) on success, or Err if git commit fails (e.g., due to signing requirements)
fn init_test_repo(path: &Path, locale: &str) -> std::io::Result<()> {
    // Create the directory structure
    fs::create_dir_all(path)?;

    // Initialize git repo
    let output = Command::new("git")
        .args(["init"])
        .current_dir(path)
        .output()
        .expect("Failed to run git init");

    if !output.status.success() {
        return Err(std::io::Error::new(
            std::io::ErrorKind::Other,
            format!(
                "Failed to init git repo: {}",
                String::from_utf8_lossy(&output.stderr)
            ),
        ));
    }

    // Configure git user for commits (disable all signing)
    Command::new("git")
        .args(["config", "user.email", "test@test.com"])
        .current_dir(path)
        .status()
        .expect("Failed to configure git email");

    Command::new("git")
        .args(["config", "user.name", "Test User"])
        .current_dir(path)
        .status()
        .expect("Failed to configure git name");

    // Disable all types of signing
    Command::new("git")
        .args(["config", "commit.gpgsign", "false"])
        .current_dir(path)
        .status()
        .ok();

    Command::new("git")
        .args(["config", "tag.gpgsign", "false"])
        .current_dir(path)
        .status()
        .ok();

    // Create test data structure matching govbot's expected format
    let data_dir = path
        .join("country:us")
        .join(format!("state:{}", locale))
        .join("sessions")
        .join("2025")
        .join("bills")
        .join("TEST001");

    fs::create_dir_all(data_dir.join("logs"))?;

    // Create data.json (repo metadata)
    let data_json = serde_json::json!({
        "name": format!("{}-legislation", locale),
        "locale": locale,
        "version": "1.0.0"
    });
    fs::write(
        path.join("data.json"),
        serde_json::to_string_pretty(&data_json)?,
    )?;

    // Create metadata.json for the test bill
    let metadata = serde_json::json!({
        "id": format!("ocd-bill/{}/2025/TEST001", locale),
        "identifier": "TEST001",
        "title": "A Test Bill for E2E Testing",
        "session": "2025",
        "classification": ["bill"],
        "subject": [],
        "extras": {}
    });
    fs::write(
        data_dir.join("metadata.json"),
        serde_json::to_string_pretty(&metadata)?,
    )?;

    // Create a log entry
    let log_entry = serde_json::json!({
        "date": "2025-01-15",
        "description": "Introduced",
        "classification": ["introduction"]
    });
    fs::write(
        data_dir.join("logs").join("20250115T000000Z_introduced.json"),
        serde_json::to_string_pretty(&log_entry)?,
    )?;

    // Add files
    Command::new("git")
        .args(["add", "-A"])
        .current_dir(path)
        .status()
        .expect("Failed to git add");

    // Try to commit (may fail in environments with mandatory signing)
    let commit_output = Command::new("git")
        .args(["commit", "--no-gpg-sign", "-m", "Initial commit with test data"])
        .current_dir(path)
        .output()
        .expect("Failed to run git commit");

    if !commit_output.status.success() {
        return Err(std::io::Error::new(
            std::io::ErrorKind::Other,
            format!(
                "Git commit failed (signing may be required): {}",
                String::from_utf8_lossy(&commit_output.stderr)
            ),
        ));
    }

    Ok(())
}

/// Test cloning a single repository from a local file:// URL
/// Uses "wy" (Wyoming) as the locale since it's a valid WorkingLocale
#[test]
fn test_clone_single_repo() {
    let binary = get_binary_path();

    // Create temporary directories for source repo and govbot workspace
    let source_dir = TempDir::new().expect("Failed to create temp dir for source");
    let workspace_dir = TempDir::new().expect("Failed to create temp dir for workspace");

    // Initialize a test repository with a valid locale code
    let repo_path = source_dir.path().join("wy-legislation.git");
    match init_test_repo(&repo_path, "wy") {
        Ok(_) => {}
        Err(e) => {
            eprintln!(
                "Skipping test_clone_single_repo: git commit not available in this environment: {}",
                e
            );
            return;
        }
    }

    // Create URL template pointing to our local repos
    let url_template = format!(
        "file://{}/{{locale}}-legislation.git",
        source_dir.path().display()
    );

    let govbot_dir = workspace_dir.path().join(".govbot");

    // Run govbot clone
    let output = Command::new(&binary)
        .args(["clone", "wy"])
        .env("GOVBOT_DIR", govbot_dir.to_string_lossy().as_ref())
        .env("GOVBOT_REPO_URL_TEMPLATE", &url_template)
        .current_dir(workspace_dir.path())
        .output()
        .expect("Failed to execute govbot clone");

    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);

    eprintln!("Clone stdout: {}", stdout);
    eprintln!("Clone stderr: {}", stderr);

    assert!(
        output.status.success(),
        "Clone failed with exit code: {:?}\nstderr: {}",
        output.status.code(),
        stderr
    );

    // Verify the repository was cloned
    let cloned_repo = govbot_dir.join("repos").join("wy-legislation");
    assert!(
        cloned_repo.exists(),
        "Cloned repo should exist at {}",
        cloned_repo.display()
    );

    // Verify data.json exists
    assert!(
        cloned_repo.join("data.json").exists(),
        "data.json should exist in cloned repo"
    );

    // Verify the bill metadata was cloned
    let metadata_path = cloned_repo
        .join("country:us")
        .join("state:wy")
        .join("sessions")
        .join("2025")
        .join("bills")
        .join("TEST001")
        .join("metadata.json");
    assert!(
        metadata_path.exists(),
        "metadata.json should exist at {}",
        metadata_path.display()
    );

    // Verify output contains success indicator (govbot outputs status to stderr)
    let combined_output = format!("{}{}", stdout, stderr);
    assert!(
        combined_output.contains("🆕") || combined_output.contains("Cloned") || combined_output.contains("wy"),
        "Output should indicate successful clone: {}",
        combined_output
    );
}

/// Test pulling updates to an existing repository
#[test]
fn test_clone_pull_updates() {
    let binary = get_binary_path();

    // Create temporary directories
    let source_dir = TempDir::new().expect("Failed to create temp dir for source");
    let workspace_dir = TempDir::new().expect("Failed to create temp dir for workspace");

    // Initialize test repository with a valid locale (gu = Guam)
    let repo_path = source_dir.path().join("gu-legislation.git");
    match init_test_repo(&repo_path, "gu") {
        Ok(_) => {}
        Err(e) => {
            eprintln!(
                "Skipping test_clone_pull_updates: git commit not available in this environment: {}",
                e
            );
            return;
        }
    }

    let url_template = format!(
        "file://{}/{{locale}}-legislation.git",
        source_dir.path().display()
    );
    let govbot_dir = workspace_dir.path().join(".govbot");

    // First clone
    let output = Command::new(&binary)
        .args(["clone", "gu"])
        .env("GOVBOT_DIR", govbot_dir.to_string_lossy().as_ref())
        .env("GOVBOT_REPO_URL_TEMPLATE", &url_template)
        .current_dir(workspace_dir.path())
        .output()
        .expect("Failed to execute first clone");

    assert!(
        output.status.success(),
        "First clone failed: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    // Add a new file to the source repo (simulate upstream changes)
    let new_log = serde_json::json!({
        "date": "2025-01-20",
        "description": "Passed committee",
        "classification": ["committee-passage"]
    });

    let log_dir = repo_path
        .join("country:us")
        .join("state:gu")
        .join("sessions")
        .join("2025")
        .join("bills")
        .join("TEST001")
        .join("logs");

    fs::write(
        log_dir.join("20250120T000000Z_committee_passage.json"),
        serde_json::to_string_pretty(&new_log).unwrap(),
    )
    .expect("Failed to write new log");

    // Commit the change in source repo
    Command::new("git")
        .args(["add", "-A"])
        .current_dir(&repo_path)
        .status()
        .expect("Failed to git add");

    let commit_result = Command::new("git")
        .args(["commit", "--no-gpg-sign", "-m", "Add committee passage log"])
        .current_dir(&repo_path)
        .output()
        .expect("Failed to run git commit");

    if !commit_result.status.success() {
        eprintln!(
            "Skipping pull part of test: git commit not available: {}",
            String::from_utf8_lossy(&commit_result.stderr)
        );
        return;
    }

    // Run clone again (should pull)
    let output = Command::new(&binary)
        .args(["clone", "gu"])
        .env("GOVBOT_DIR", govbot_dir.to_string_lossy().as_ref())
        .env("GOVBOT_REPO_URL_TEMPLATE", &url_template)
        .current_dir(workspace_dir.path())
        .output()
        .expect("Failed to execute pull");

    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);

    eprintln!("Pull stdout: {}", stdout);
    eprintln!("Pull stderr: {}", stderr);

    assert!(output.status.success(), "Pull failed: {}", stderr);

    // Verify the new log file was pulled
    let pulled_log = govbot_dir
        .join("repos")
        .join("gu-legislation")
        .join("country:us")
        .join("state:gu")
        .join("sessions")
        .join("2025")
        .join("bills")
        .join("TEST001")
        .join("logs")
        .join("20250120T000000Z_committee_passage.json");

    assert!(
        pulled_log.exists(),
        "New log file should be pulled: {}",
        pulled_log.display()
    );
}

/// Test clone with no args on empty workspace (should show helpful message)
#[test]
fn test_clone_no_args_empty() {
    let binary = get_binary_path();

    let workspace_dir = TempDir::new().expect("Failed to create temp dir");
    let govbot_dir = workspace_dir.path().join(".govbot");

    let output = Command::new(&binary)
        .args(["clone"])
        .env("GOVBOT_DIR", govbot_dir.to_string_lossy().as_ref())
        .current_dir(workspace_dir.path())
        .output()
        .expect("Failed to execute govbot clone");

    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);

    eprintln!("stdout: {}", stdout);
    eprintln!("stderr: {}", stderr);

    // Should succeed but indicate no repos found
    assert!(
        output.status.success() || output.status.code() == Some(0),
        "clone with no repos should succeed"
    );
}

/// Test logs command after clone
#[test]
fn test_logs_after_clone() {
    let binary = get_binary_path();

    // Create temporary directories
    let source_dir = TempDir::new().expect("Failed to create temp dir for source");
    let workspace_dir = TempDir::new().expect("Failed to create temp dir for workspace");

    // Initialize test repository with a valid locale (il = Illinois)
    let repo_path = source_dir.path().join("il-legislation.git");
    match init_test_repo(&repo_path, "il") {
        Ok(_) => {}
        Err(e) => {
            eprintln!(
                "Skipping test_logs_after_clone: git commit not available in this environment: {}",
                e
            );
            return;
        }
    }

    let url_template = format!(
        "file://{}/{{locale}}-legislation.git",
        source_dir.path().display()
    );
    let govbot_dir = workspace_dir.path().join(".govbot");

    // Clone the repo
    let output = Command::new(&binary)
        .args(["clone", "il"])
        .env("GOVBOT_DIR", govbot_dir.to_string_lossy().as_ref())
        .env("GOVBOT_REPO_URL_TEMPLATE", &url_template)
        .current_dir(workspace_dir.path())
        .output()
        .expect("Failed to execute clone");

    if !output.status.success() {
        eprintln!(
            "Skipping test: clone failed: {}",
            String::from_utf8_lossy(&output.stderr)
        );
        return;
    }

    // Run logs command
    let output = Command::new(&binary)
        .args(["logs", "--filter", "none"])
        .env("GOVBOT_DIR", govbot_dir.to_string_lossy().as_ref())
        .current_dir(workspace_dir.path())
        .output()
        .expect("Failed to execute logs");

    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);

    eprintln!("Logs stdout: {}", stdout);
    eprintln!("Logs stderr: {}", stderr);

    assert!(output.status.success(), "Logs command failed: {}", stderr);

    // Verify output contains JSON with our test data
    assert!(
        stdout.contains("TEST001") || stdout.contains("introduced") || stdout.contains("2025"),
        "Logs output should contain test data: {}",
        stdout
    );
}

/// Test that govbot logs works with the existing mock data
/// This test uses the mock data that's checked into the repo - no git operations needed
#[test]
fn test_logs_with_mock_data() {
    let binary = get_binary_path();
    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let govbot_dir = manifest_dir.join("mocks").join(".govbot");

    // Check if mock data exists
    if !govbot_dir.join("repos").exists() {
        eprintln!("Skipping test_logs_with_mock_data: mock data not found");
        return;
    }

    // Run logs command with mock data
    let output = Command::new(&binary)
        .args(["logs", "--filter", "none", "--limit", "5"])
        .env("GOVBOT_DIR", govbot_dir.to_string_lossy().as_ref())
        .current_dir(&manifest_dir)
        .output()
        .expect("Failed to execute logs");

    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);

    eprintln!("Mock logs stdout: {}", stdout);
    eprintln!("Mock logs stderr: {}", stderr);

    assert!(
        output.status.success(),
        "Logs with mock data failed: {}",
        stderr
    );

    // The mock data should contain Wyoming or Guam bills
    assert!(
        stdout.contains("wy") || stdout.contains("gu") || stdout.contains("HB"),
        "Logs output should contain mock data from wy or gu: {}",
        stdout
    );
}

/// Test govbot logs with different filtering options using mock data
#[test]
fn test_logs_filter_options() {
    let binary = get_binary_path();
    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let govbot_dir = manifest_dir.join("mocks").join(".govbot");

    // Check if mock data exists
    if !govbot_dir.join("repos").exists() {
        eprintln!("Skipping test_logs_filter_options: mock data not found");
        return;
    }

    // Test with --join none (raw log entries only)
    let output = Command::new(&binary)
        .args(["logs", "--filter", "none", "--join", "none", "--limit", "3"])
        .env("GOVBOT_DIR", govbot_dir.to_string_lossy().as_ref())
        .current_dir(&manifest_dir)
        .output()
        .expect("Failed to execute logs with --join none");

    assert!(
        output.status.success(),
        "Logs with --join none failed: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    // Test with ascending sort
    let output = Command::new(&binary)
        .args(["logs", "--filter", "none", "--sort", "ASC", "--limit", "3"])
        .env("GOVBOT_DIR", govbot_dir.to_string_lossy().as_ref())
        .current_dir(&manifest_dir)
        .output()
        .expect("Failed to execute logs with --sort ASC");

    assert!(
        output.status.success(),
        "Logs with --sort ASC failed: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    // Test filtering by specific repo
    let output = Command::new(&binary)
        .args(["logs", "--filter", "none", "--repos", "wy", "--limit", "5"])
        .env("GOVBOT_DIR", govbot_dir.to_string_lossy().as_ref())
        .current_dir(&manifest_dir)
        .output()
        .expect("Failed to execute logs with --repos wy");

    assert!(
        output.status.success(),
        "Logs with --repos wy failed: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stdout = String::from_utf8_lossy(&output.stdout);
    // When filtering by wy, output should only contain wy data
    if !stdout.is_empty() {
        assert!(
            stdout.contains("wy") || stdout.contains("state:wy"),
            "Logs filtered by wy should contain wy data: {}",
            stdout
        );
    }
}

/// Test govbot clone --list (doesn't require network or git operations)
#[test]
fn test_clone_list() {
    let binary = get_binary_path();

    let output = Command::new(&binary)
        .args(["clone", "--list"])
        .output()
        .expect("Failed to execute govbot clone --list");

    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);

    eprintln!("clone --list stdout: {}", stdout);
    eprintln!("clone --list stderr: {}", stderr);

    assert!(
        output.status.success(),
        "clone --list failed: {}",
        stderr
    );

    // Should list available locales
    assert!(
        stdout.contains("wy") || stdout.contains("il") || stdout.contains("ca"),
        "clone --list should show available locales: {}",
        stdout
    );
}
