# Govbot Development Environment Setup

This guide will help you set up your development environment for working on `actions/govbot` with Claude Code.

## Quick Start

### Automated Setup

Run the automated setup script from the repository root:

```bash
./dev-setup.sh
```

This script will:
- ✅ Check/install Rust toolchain
- ✅ Install `just` command runner
- ✅ Create `.env` configuration file
- ✅ Set up data directories
- ✅ Build govbot in debug mode
- ✅ Verify installation

### Manual Setup

If you prefer manual setup or need to troubleshoot:

#### 1. Install Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

#### 2. Install Just (optional but recommended)

```bash
cargo install just
```

#### 3. Configure Environment

```bash
# Copy example configuration
cp .env.example .env

# Edit .env and add your GitHub token (if needed for private repos)
# Get token from: https://github.com/settings/tokens
# Required scope: repo
```

#### 4. Build Govbot

```bash
cd actions/govbot
cargo build
```

## Understanding Govbot

### What It Does

Govbot is a Rust CLI tool and GitHub Action that:
- **Clones** legislative data repositories from GitHub (windy-civi-pipelines organization)
- **Processes** JSON log files containing bill actions, votes, and events
- **Streams** data efficiently using async Rust

### Data Repositories

Govbot clones repositories for 39 U.S. jurisdictions (38 states + federal):

```
https://github.com/windy-civi-pipelines/{locale}-data-pipeline.git
```

**Available locales:** AR, DE, FL, GA, GU, IA, IL, KS, KY, LA, MN, MO, MP, MT, NC, ND, NE, NH, NJ, NM, NV, OK, OR, PA, PR, RI, SC, TN, TX, UT, VI, VT, WA, WI, WV, WY, USA

### Where Data Lives

By default, data is cloned to:
```
$HOME/.govbot/repos/
├── ar-data-pipeline/
├── il-data-pipeline/
├── usa-data-pipeline/
└── ...
```

You can customize this location with the `GOVBOT_DIR` environment variable.

## Daily Development Workflow

### Building

```bash
cd actions/govbot

# Debug build (fast compile, slower runtime)
cargo build
# or: just build

# Release build (slow compile, optimized runtime)
cargo build --release
# or: just build-release
```

### Running Govbot

```bash
cd actions/govbot

# Clone data repositories
cargo run --bin govbot -- clone usa il ca    # Clone specific locales
cargo run --bin govbot -- clone              # Clone all locales
cargo run --bin govbot -- clone --list       # List available locales

# Process logs
cargo run --bin govbot -- logs --sources usa il --limit 10

# Advanced log filtering
cargo run --bin govbot -- logs \
  --sources usa \
  --join minimal_metadata,sponsors \
  --sort DESC \
  --limit 100

# Delete repositories
cargo run --bin govbot -- delete il ca       # Delete specific locales
cargo run --bin govbot -- delete all         # Delete all
```

### Testing

```bash
cd actions/govbot

# Run all tests
cargo test
# or: just test

# Run tests with output
cargo test -- --nocapture
# or: just test-verbose

# Run specific test
cargo test test_name
```

### Snapshot Testing

Govbot uses the `insta` crate for snapshot testing:

```bash
cd actions/govbot

# Review pending snapshots
just review

# Accept all pending snapshots
just accept

# Reject all pending snapshots
just reject
```

### Code Quality

```bash
cd actions/govbot

# Format code
cargo fmt

# Lint code
cargo clippy

# Check without building
cargo check
```

## Working with Claude Code

### Common Tasks

#### Adding a New Feature

```bash
# Example: Add support for filtering by date range
cd actions/govbot

# 1. Modify code in src/
# 2. Run tests
cargo test

# 3. Review snapshot changes
just review

# 4. Build and test manually
cargo run --bin govbot -- logs --sources usa --limit 5
```

#### Debugging

```bash
# Enable debug logging
export RUST_LOG=govbot=debug

# Run with backtrace
export RUST_BACKTRACE=1
cargo run --bin govbot -- clone usa

# Or use the VS Code debugger with launch.json
```

#### Testing with Real Data

```bash
# Clone a small dataset first
cargo run --bin govbot -- clone ri  # Rhode Island is smallest

# Process its logs
cargo run --bin govbot -- logs --sources ri

# Inspect the data structure
ls -la ~/.govbot/repos/ri-data-pipeline/
```

### Useful Environment Variables

```bash
# Add to .env file:

# Show detailed logs
RUST_LOG=govbot=debug,info

# Use custom data directory
GOVBOT_DIR=/tmp/govbot-test

# Increase parallel operations
GOVBOT_JOBS=8

# GitHub token for private repos
TOKEN=ghp_your_token_here
```

## Project Structure

```
actions/govbot/
├── src/
│   ├── main.rs              # CLI entry point
│   ├── git.rs               # Git operations (clone, pull, delete)
│   ├── processor.rs         # Log file processing
│   ├── config.rs            # Configuration management
│   ├── types.rs             # Type definitions
│   ├── locale_generated.rs  # Auto-generated locale enum
│   └── lib.rs               # Library exports
├── tests/                   # Integration tests
├── examples/                # Usage examples
├── Cargo.toml               # Dependencies
├── justfile                 # Task runner commands
├── action.yml               # GitHub Action definition
└── README.md                # Main documentation
```

## Troubleshooting

### Rust Not Found

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

### Build Errors

```bash
# Clean and rebuild
cd actions/govbot
cargo clean
cargo build
```

### Git Clone Failures

```bash
# Check if TOKEN is set correctly
echo $TOKEN

# Try with verbose output
RUST_LOG=debug cargo run -- clone usa
```

### Snapshot Test Failures

```bash
# Review what changed
just review

# If changes are expected, accept them
just accept

# If changes are wrong, fix code and reject
just reject
```

## Tips for Claude Code

1. **Always build first**: Run `cargo build` before testing to catch compile errors early

2. **Use small datasets**: Start with small locales (RI, DE, MT) for faster testing

3. **Check snapshots**: After changes, always review snapshot tests with `just review`

4. **Read the code**: Start by reading `/home/user/toolkit/actions/govbot/src/main.rs` to understand the CLI structure

5. **Test incrementally**: Test each change before moving to the next feature

6. **Use just**: The `justfile` has convenient commands - run `just` to see all available tasks

## Additional Resources

- [Govbot README](./actions/govbot/README.md) - Main documentation
- [Cargo Book](https://doc.rust-lang.org/cargo/) - Cargo documentation
- [Just Manual](https://just.systems/) - Just command runner
- [Insta Guide](https://insta.rs/) - Snapshot testing

## Next Steps

After setup:

1. ✅ Run `cargo build` to ensure everything compiles
2. ✅ Run `cargo test` to verify tests pass
3. ✅ Try `cargo run --bin govbot -- clone --list` to see available locales
4. ✅ Clone a small dataset: `cargo run --bin govbot -- clone ri`
5. ✅ Process logs: `cargo run --bin govbot -- logs --sources ri --limit 5`

You're now ready to work on govbot! 🚀
