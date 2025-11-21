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

## Migration from Shell Script

This Rust library provides the same functionality as the original `main.sh` script but with:
- Type safety at compile time
- Better error handling
- Reactive streams for efficient processing
- Composable API with builder pattern
- Faster filesystem traversal with `jwalk`
- Native stdio pipeline support

