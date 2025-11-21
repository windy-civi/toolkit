#!/bin/bash
set -e

echo "🚀 Setting up development environment for from-chn-distributed-gov..."

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    echo "❌ Error: Rust/Cargo is not installed."
    echo "   Please install Rust from https://rustup.rs/"
    exit 1
fi

echo "✅ Rust toolchain found: $(rustc --version)"

# Install Rust dependencies (including dev dependencies)
echo ""
echo "📦 Installing Rust dependencies..."
cargo build

# Check if cargo-insta is installed
if ! command -v cargo-insta &> /dev/null; then
    echo ""
    echo "📦 Installing cargo-insta (required for snapshot testing)..."
    cargo install cargo-insta
else
    echo "✅ cargo-insta already installed: $(cargo-insta --version 2>/dev/null || echo 'installed')"
fi

# Run tests to generate initial snapshots
echo ""
echo "🧪 Running tests to generate initial snapshots..."
cargo test --no-fail-fast || {
    echo "⚠️  Some tests failed, but this is expected if test data is not available."
    echo "   Snapshots will be created when you run tests with the proper test data."
}

echo ""
echo "✅ Development environment setup complete!"
echo ""
echo "Next steps:"
echo "  - Run tests: cargo test"
echo "  - Review snapshots: cargo insta review"
echo "  - Build release: cargo build --release"

