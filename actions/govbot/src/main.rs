use clap::{Parser, Subcommand};
use govbot::prelude::*;
use govbot::git;
use futures::StreamExt;
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
    /// Clone data pipeline repositories for specified locales
    Clone {
        /// Locale names to clone (e.g., usa, il, ca)
        #[arg(num_args = 1..)]
        locales: Vec<String>,

        /// Directory to clone repositories into (default: $HOME/.govbot/repos, or GOVBOT_DIR env var)
        #[arg(long = "govbot-dir")]
        govbot_dir: Option<String>,

        /// GitHub token for authentication (can also use TOKEN env var)
        #[arg(long)]
        token: Option<String>,
    },

    /// Pull latest changes from data pipeline repositories
    Pull {
        /// Locale names to pull (if not specified, pulls all available repos)
        #[arg(num_args = 0..)]
        locales: Vec<String>,

        /// Directory containing repositories (default: $HOME/.govbot/repos, or GOVBOT_DIR env var)
        #[arg(long = "govbot-dir")]
        govbot_dir: Option<String>,

        /// GitHub token for authentication (can also use TOKEN env var)
        #[arg(long)]
        token: Option<String>,
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
    println!("  clone   Clone data pipeline repositories for specified locales");
    println!("  pull    Pull latest changes from data pipeline repositories");
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

fn run_clone_command(cmd: Command) -> anyhow::Result<()> {
    let Command::Clone {
        locales,
        govbot_dir,
        token,
    } = cmd else {
        unreachable!()
    };

    if locales.is_empty() {
        println!("Available locales:");
        let all_locales = govbot::locale::WorkingLocale::all();
        for locale in all_locales {
            println!("  {}", locale.as_lowercase());
        }
        return Ok(());
    }

    let repos_dir = get_govbot_dir(govbot_dir)?;
    
    // Create directory if it doesn't exist
    std::fs::create_dir_all(&repos_dir)?;

    // Get token from argument or environment variable
    let env_token = std::env::var("TOKEN").ok();
    let token_str = token.as_deref().or(env_token.as_deref());
    
    for locale in locales {
        let locale = locale.trim();
        if locale.is_empty() {
            continue;
        }
        
        if let Err(e) = git::clone_repo(locale, &repos_dir, token_str) {
            eprintln!("Error cloning {}: {}", locale, e);
            return Err(e.into());
        }
    }

    println!("\nCloning completed successfully!");
    Ok(())
}

fn run_pull_command(cmd: Command) -> anyhow::Result<()> {
    let Command::Pull {
        locales,
        govbot_dir,
        token,
    } = cmd else {
        unreachable!()
    };

    let repos_dir = get_govbot_dir(govbot_dir)?;

    if !repos_dir.exists() {
        return Err(anyhow::anyhow!(
            "Repos directory does not exist: {}. Use 'govbot clone' first.",
            repos_dir.display()
        ));
    }

    // Get token from argument or environment variable
    let env_token = std::env::var("TOKEN").ok();
    let token_str = token.as_deref().or(env_token.as_deref());
    
    let locales_to_pull = if locales.is_empty() {
        // Pull all available repos
        git::get_available_locales(&repos_dir)?
    } else {
        locales.into_iter().map(|l| l.trim().to_string()).collect()
    };

    if locales_to_pull.is_empty() {
        println!("No repositories found to pull.");
        return Ok(());
    }

    for locale in locales_to_pull {
        if locale.is_empty() {
            continue;
        }
        
        if let Err(e) = git::pull_repo(&locale, &repos_dir, token_str) {
            eprintln!("Error pulling {}: {}", locale, e);
            return Err(e.into());
        }
    }

    println!("\nPulling completed successfully!");
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
            run_clone_command(cmd)
        }
        Some(cmd @ Command::Pull { .. }) => {
            run_pull_command(cmd)
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
