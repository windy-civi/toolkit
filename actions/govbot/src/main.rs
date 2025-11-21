use clap::{Parser, Subcommand};
use govbot::prelude::*;
use govbot::git;
use futures::StreamExt;
use futures::stream;
use std::io::{self, BufRead};
use std::path::PathBuf;

/// Type-safe, functional reactive processor for pipeline log files
#[derive(Parser, Debug)]
#[command(name = "govbot")]
#[command(about = "Process pipeline log files with type-safe reactive streams")]
#[command(version)]
struct Args {
    #[command(subcommand)]
    command: Option<Command>,
}

#[derive(Subcommand, Debug)]
enum Command {
    /// Clone or pull data pipeline repositories (default: all locales)
    /// Clones if repository doesn't exist, pulls if it does
    Clone {
        /// Locale names to clone/pull (e.g., usa, il, ca, or "all" for all locales). If not specified, processes all locales.
        #[arg(num_args = 0..)]
        locales: Vec<String>,

        /// Directory containing repositories (default: $HOME/.govbot/repos, or GOVBOT_DIR env var)
        #[arg(long = "govbot-dir")]
        govbot_dir: Option<String>,

        /// GitHub token for authentication (can also use TOKEN env var)
        #[arg(long)]
        token: Option<String>,

        /// Number of parallel operations (default: 4, or GOVBOT_JOBS env var)
        #[arg(long)]
        parallel: Option<usize>,

        /// Show verbose git output
        #[arg(long)]
        verbose: bool,

        /// List available locales instead of cloning/pulling
        #[arg(long)]
        list: bool,
    },

    /// Process and display pipeline log files
    Logs {
        /// Directory containing cloned repositories (default: $HOME/.govbot/repos, or GOVBOT_DIR env var)
        #[arg(long = "govbot-dir")]
        govbot_dir: Option<String>,


        /// Source names to filter (space-separated)
        #[arg(short, long, num_args = 0..)]
        sources: Vec<String>,

        /// Sort order: ASC or DESC
        #[arg(long, default_value = "DESC", value_parser = ["ASC", "DESC"])]
        sort: String,

        /// Limit number of results
        #[arg(long)]
        limit: Option<usize>,

        /// Join options: minimal_metadata,sponsors
        #[arg(long, default_value = "minimal_metadata")]
        join: String,

        /// Read file paths from stdin instead of discovering files
        /// Useful for stdio pipelines: find ... | govbot logs --stdin
        #[arg(long)]
        stdin: bool,
    },
}

fn print_available_commands() {
    println!("Available commands:");
    println!("  clone   Clone or pull data pipeline repositories (default: all locales)");
    println!("  logs    Process and display pipeline log files");
}

fn get_govbot_dir(govbot_dir: Option<String>) -> anyhow::Result<PathBuf> {
    // Check flag first, then environment variable, then default
    if let Some(govbot_dir) = govbot_dir {
        // Append /repos to custom govbot-dir (default already includes /repos)
        Ok(PathBuf::from(govbot_dir).join("repos"))
    } else if let Ok(govbot_dir) = std::env::var("GOVBOT_DIR") {
        // Append /repos to custom govbot-dir from env var
        Ok(PathBuf::from(govbot_dir).join("repos"))
    } else {
        // Fall back to default: $HOME/.govbot/repos
        git::default_repos_dir().map_err(|e| anyhow::anyhow!("{}", e))
    }
}

async fn run_clone_command(cmd: Command) -> anyhow::Result<()> {
    let Command::Clone {
        locales,
        govbot_dir,
        token,
        parallel,
        verbose,
        list,
    } = cmd else {
        unreachable!()
    };

    if list {
        println!("Available locales:");
        let all_locales = govbot::locale::WorkingLocale::all();
        for locale in all_locales {
            println!("  {}", locale.as_lowercase());
        }
        println!("  all (clone all locales)");
        return Ok(());
    }

    // If no locales specified, default to "all"
    let locales = if locales.is_empty() {
        vec!["all".to_string()]
    } else {
        locales
    };

    let repos_dir = get_govbot_dir(govbot_dir)?;
    
    // Create directory if it doesn't exist
    std::fs::create_dir_all(&repos_dir)?;

    // Get token from argument or environment variable
    let env_token = std::env::var("TOKEN").ok();
    let token_str = token.as_deref().or(env_token.as_deref());
    
    // Get parallelization setting
    let num_jobs = parallel
        .or_else(|| std::env::var("GOVBOT_JOBS").ok().and_then(|s| s.parse().ok()))
        .unwrap_or(4);

    // Parse locales and handle "all"
    let mut locales_to_clone = Vec::new();
    for locale in locales {
        let locale = locale.trim().to_lowercase();
        if locale.is_empty() {
            continue;
        }
        
        if locale == "all" {
            // Add all working locales
            let all_locales = govbot::locale::WorkingLocale::all();
            for loc in all_locales {
                locales_to_clone.push(loc.as_lowercase().to_string());
            }
        } else {
            // Validate locale
            let _ = govbot::locale::WorkingLocale::from(locale.as_str());
            locales_to_clone.push(locale);
        }
    }

    if locales_to_clone.is_empty() {
        return Ok(());
    }

    let total = locales_to_clone.len();
    
    // Clone or pull with parallelization
    if total == 1 || num_jobs == 1 {
        // Sequential clone/pull with progress display
        for (idx, locale) in locales_to_clone.iter().enumerate() {
            let current = idx + 1;
            if !verbose {
                eprint!("\r⏳ Processing {} ({}/{})...", locale, current, total);
                std::io::Write::flush(&mut std::io::stderr()).ok();
            }
            
            match git::clone_or_pull_repo_quiet(locale, &repos_dir, token_str, !verbose) {
                Ok(action) => {
                    if !verbose {
                        let action_text = if action == "clone" { "Cloned" } else { "Pulled" };
                        eprint!("\r✓ {}  {} ({}/{})    \n", action_text, locale, current, total);
                    }
                }
                Err(e) => {
                    if !verbose {
                        eprint!("\r✗ Failed  {} ({}/{})    \n", locale, current, total);
                    }
                    eprintln!("  Error: {}", e);
                    return Err(e.into());
                }
            }
        }
    } else {
        // Parallel clone/pull with progress display
        if !verbose {
            eprintln!("Processing {} locales with {} parallel jobs...\n", total, num_jobs);
        }
        
        use std::sync::{Arc, Mutex};
        let completed = Arc::new(Mutex::new(0usize));
        let verbose_flag = verbose;
        
        let clone_futures = stream::iter(locales_to_clone.iter().enumerate())
            .map(|(_idx, locale)| {
                let locale = locale.clone();
                let repos_dir = repos_dir.clone();
                let token = token_str.map(|s| s.to_string());
                let completed = completed.clone();
                let total = total;
                let verbose = verbose_flag;
                
                tokio::task::spawn_blocking(move || {
                    let result = git::clone_or_pull_repo_quiet(&locale, &repos_dir, token.as_deref(), !verbose)
                        .map_err(|e| (locale.clone(), e));
                    
                    if !verbose {
                        let mut count = completed.lock().unwrap();
                        *count += 1;
                        let current = *count;
                        
                        match &result {
                            Ok(action) => {
                                let action_text = if *action == "clone" { "Cloned" } else { "Pulled" };
                                eprint!("\r✓ {}  {} ({}/{})    \n", action_text, locale, current, total);
                            }
                            Err((_, _)) => {
                                eprint!("\r✗ Failed  {} ({}/{})    \n", locale, current, total);
                            }
                        }
                        std::io::Write::flush(&mut std::io::stderr()).ok();
                    }
                    
                    result
                })
            })
            .buffer_unordered(num_jobs);

        let mut errors = Vec::new();
        let mut stream = clone_futures;
        let mut success_count = 0;
        
        while let Some(result) = stream.next().await {
            match result {
                Ok(Ok(_)) => {
                    success_count += 1;
                }
                Ok(Err((locale, e))) => {
                    errors.push((locale, e));
                }
                Err(e) => {
                    errors.push(("unknown".to_string(), govbot::Error::Config(format!("Task join error: {}", e))));
                }
            }
        }

        if !errors.is_empty() {
            if !verbose {
                eprintln!("\n❌ Errors occurred:");
            }
            for (locale, error) in errors {
                eprintln!("  {}: {}", locale, error);
            }
            if !verbose {
                eprintln!("\n✓ Successfully processed: {}/{}", success_count, total);
            }
            return Err(anyhow::anyhow!("Some operations failed"));
        } else {
            if !verbose {
                eprintln!("\n✅ Successfully processed all {} locales!", total);
            }
        }
    }
    Ok(())
}


async fn run_logs_command(cmd: Command) -> anyhow::Result<()> {
    let Command::Logs {
        govbot_dir,
        sources,
        sort,
        limit,
        join,
        stdin,
    } = cmd else {
        unreachable!()
    };

    let git_dir = get_govbot_dir(govbot_dir)?;

    // Build configuration
    let mut builder = ConfigBuilder::new(&git_dir)
        .sort_order_str(&sort)?;

    if let Some(limit) = limit {
        builder = builder.limit(limit);
    }

    if !sources.is_empty() {
        builder = builder.sources(sources);
    }

    let config = builder.join_options_str(&join)?.build()?;

    let processor = PipelineProcessor::new(config.clone());

    if stdin {
        // Read paths from stdin (one per line)
        let stdin = io::stdin();
        let paths = stdin
            .lock()
            .lines()
            .filter_map(|line| line.ok())
            .filter(|line| !line.trim().is_empty());

        let mut stream = PipelineProcessor::process_from_stdin(&config, paths);

        // Write JSON to stdout (one per line)
        while let Some(result) = stream.next().await {
            match result {
                Ok(entry) => {
                    let json = serde_json::to_string(&entry)?;
                    println!("{}", json);
                }
                Err(e) => {
                    eprintln!("Error: {}", e);
                }
            }
        }
    } else {
        // Discover and process files from directory
        let mut stream = processor.process();

        // Write JSON to stdout (one per line)
        while let Some(result) = stream.next().await {
            match result {
                Ok(entry) => {
                    let json = serde_json::to_string(&entry)?;
                    println!("{}", json);
                }
                Err(e) => {
                    eprintln!("Error: {}", e);
                }
            }
        }
    }

    Ok(())
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args = Args::parse();

    match args.command {
        Some(cmd @ Command::Clone { .. }) => {
            run_clone_command(cmd).await
        }
        Some(cmd @ Command::Logs { .. }) => {
            run_logs_command(cmd).await
        }
        None => {
            print_available_commands();
            Ok(())
        }
    }
}
