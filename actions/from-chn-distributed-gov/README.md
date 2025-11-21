# from-chn-distributed-gov

A type-safe, functional reactive Rust library for processing pipeline log files from distributed government data repositories.

## Features

- **Type-safe**: All data structures are strongly typed with Rust's type system
- **Functional Reactive**: Uses async streams (`futures::Stream`) for reactive processing
- **Composable**: Builder pattern for configuration
- **Efficient**: Streams files one at a time, avoiding loading everything into memory
- **Fast Filesystem Traversal**: Uses `jwalk` for parallel directory traversal
- **Stdio Pipeline Support**: Works seamlessly in Unix pipelines
- **Zero-copy where possible**: Uses references and efficient path handling

## Getting Started

### Prerequisites

- Rust toolchain (stable recommended). Install from [rustup.rs](https://rustup.rs/)

### Setup

**Quick setup (recommended):**

Run the setup script to install all dependencies and development tools:

```bash
./setup_dev.sh
```

**Manual setup:**

1. **Clone the repository** (if you haven't already)

2. **Install development dependencies:**

   The project uses `insta` for snapshot testing. All Rust dependencies (including dev dependencies) are automatically installed when you build:

   ```bash
   cargo build
   ```

3. **Install cargo-insta** (required for reviewing snapshot changes):

   ```bash
   cargo install cargo-insta
   ```

   This is a one-time setup. `cargo-insta` is a CLI tool for managing snapshot tests and needs to be installed globally.

4. **Run tests:**

   ```bash
   # Run all tests (this will create snapshots on first run)
   cargo test

   # Run tests with output
   cargo test -- --nocapture
   ```

5. **Build the project:**

   ```bash
   cargo build --release
   ```

That's it! You're ready to start developing.

## Functional Reactive Programming Pattern

This library follows a functional reactive programming (FRP) style:

1. **Streams as First-Class Citizens**: The main API returns a `Stream<Item = Result<LogEntry>>`, allowing for lazy, on-demand processing
2. **Composable Operations**: Configuration is built using a fluent builder pattern
3. **Immutable Configuration**: Once built, configuration is immutable
4. **Reactive Processing**: Files are discovered, sorted, and processed reactively as the stream is consumed
5. **Type-Safe Transformations**: All transformations are type-checked at compile time

The reactive stream pattern allows you to:

- Process files lazily (only when consumed)
- Handle backpressure naturally
- Compose with other stream operations (filter, map, etc.)
- Process large datasets efficiently without loading everything into memory

## Usage

### Basic Example

```rust
use from_chn_distributed_gov::prelude::*;
use futures::StreamExt;

#[tokio::main]
async fn main() -> Result<()> {
    // Build configuration
    let config = ConfigBuilder::new("tmp/git/windy-civi-pipelines")
        .sort_order_str("DESC")?
        .limit(10)
        .join_options_str("minimal_metadata,sponsors")?
        .build()?;

    // Create processor
    let processor = PipelineProcessor::new(config);

    // Process files reactively
    let mut stream = processor.process();

    // Consume the stream
    while let Some(result) = stream.next().await {
        match result {
            Ok(entry) => {
                let json = serde_json::to_string(&entry)?;
                println!("{}", json);
            }
            Err(e) => eprintln!("Error: {}", e),
        }
    }

    Ok(())
}
```

### CLI Usage

The library includes a CLI tool that works as a stdio pipeline:

```bash
# Discover and process files from directory
from-chn-distributed-gov \
  --git-dir tmp/git/windy-civi-pipelines \
  --sort DESC \
  --limit 10 \
  --join minimal_metadata,sponsors \
  usa il

# Read file paths from stdin (useful for pipelines)
find tmp/git/windy-civi-pipelines -name "*.json" -path "*/logs/*" | \
  from-chn-distributed-gov --stdin --sort DESC --limit 10

# Pipe to other tools
from-chn-distributed-gov --git-dir tmp/git/windy-civi-pipelines | \
  jq '.log.action.description' | \
  head -20
```

### Configuration Options

- **--git-dir**: Directory containing cloned repositories (default: `tmp/git/windy-civi-pipelines`)
- **--sources**: Optional list of source names to filter (space-separated, e.g., `usa il`)
- **--sort**: Sort order: `ASC` or `DESC` (default: `DESC`)
- **--limit**: Optional limit on number of results
- **--join**: Comma-separated list of metadata to join (default: `minimal_metadata`):
  - `minimal_metadata`: Title, description, and sources
  - `sponsors`: Sponsor information
- **--stdin**: Read file paths from stdin instead of discovering files (one path per line)

### Reactive Processing

The library uses `futures::Stream` for reactive processing. Files are discovered, sorted, and processed lazily, allowing for efficient memory usage even with large datasets.

### Type Safety

All data structures are strongly typed:

- `LogEntry`: Complete log entry with metadata
- `LogContent`: Either full JSON or vote event result
- `VoteEventResult`: Type-safe enum for vote results
- `Config`: Type-safe configuration

## Stdio Pipeline Support

The tool is designed to work seamlessly in Unix pipelines:

1. **Output to stdout**: All results are written as JSON lines to stdout
2. **Errors to stderr**: All errors and warnings go to stderr
3. **Read from stdin**: Use `--stdin` to process file paths from stdin
4. **Streaming**: Processes files one at a time, perfect for large datasets

Example pipeline:

```bash
# Find files, process them, filter with jq, and count
find . -name "*.json" -path "*/logs/*" | \
  from-chn-distributed-gov --stdin | \
  jq 'select(.log.action.classification[] == "passage")' | \
  wc -l
```

## Performance

- Uses `jwalk` for fast parallel filesystem traversal (faster than `walkdir`)
- Async I/O with `tokio` for non-blocking file operations
- Streams files one at a time to minimize memory usage
- Parallel directory traversal leverages multiple CPU cores

## Testing

This project uses [insta](https://insta.rs/) for snapshot testing, which is the industry standard for snapshot testing in Rust.

### Running Tests

```bash
# Run all tests
cargo test

# Run tests with output
cargo test -- --nocapture
```

### Snapshot Testing

This project uses two types of snapshot tests:

1. **API snapshot tests** (`tests/api_snapshot_tests.rs`): Test individual components and data structures using the library API
2. **CLI snapshot tests from examples** (`tests/cli_snapshots_from_examples.rs`): Test the CLI tool by running example commands and capturing their output

#### CLI Snapshot Tests from Examples

CLI snapshot tests run the actual CLI tool with commands from `examples/` and capture the output. This ensures that:
- The CLI works correctly end-to-end
- Example commands in documentation are verified
- Output format remains consistent

**Example files:**

Example commands are stored in `examples/` (e.g., `examples/basic.sh`). Each example is automatically tested and its output is snapshotted.

**Adding a new example:**

1. Create a new shell script in `examples/` (e.g., `examples/my_example.sh`)
2. The test in `tests/cli_snapshots_from_examples.rs` will automatically discover and test it:

```rust
#[test]
fn test_my_example() {
    if !test_data_exists() {
        eprintln!("Skipping test_my_example: test data directory not found");
        return;
    }
    
    let args = &[
        "--git-dir", "tmp/git/windy-civi-pipelines",
        // ... your arguments
    ];
    
    let (stdout, _, exit_code) = run_cli_command(args);
    insta::assert_snapshot!("my_example_output", stdout);
    assert_eq!(exit_code, 0);
}
```

**Reviewing and updating snapshots:**

After making changes that affect output, you'll need to review and update snapshots:

```bash
# Install cargo-insta (one-time setup)
cargo install cargo-insta

# Review snapshot changes interactively
cargo insta review

# Accept all changes automatically (use with caution)
cargo insta accept

# Reject all changes
cargo insta reject
```

**Snapshot files:**

Snapshots are stored in `tests/snapshots/` and should be committed to version control. They serve as regression tests to ensure output remains consistent.

## Migration from Shell Script

This Rust library provides the same functionality as the original `main.sh` script but with:

- Type safety at compile time
- Better error handling
- Reactive streams for efficient processing
- Composable API with builder pattern
- Faster filesystem traversal with `jwalk`
- Native stdio pipeline support
- Industry-standard snapshot testing with `insta`
