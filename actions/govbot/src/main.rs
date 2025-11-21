use clap::{Parser, Subcommand};
use govbot::prelude::*;
use futures::StreamExt;
use std::io::{self, BufRead};

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
    /// Process and display pipeline log files
    Logs {
        /// Directory containing cloned repositories
        #[arg(long, default_value = "tmp/git/windy-civi-pipelines")]
        git_dir: String,

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
    println!("  logs    Process and display pipeline log files");
}

async fn run_logs_command(cmd: Command) -> anyhow::Result<()> {
    let Command::Logs {
        git_dir,
        sources,
        sort,
        limit,
        join,
        stdin,
    } = cmd;

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
        Some(cmd @ Command::Logs { .. }) => {
            run_logs_command(cmd).await
        }
        None => {
            print_available_commands();
            Ok(())
        }
    }
}
