#!/bin/bash

set -e

echo "==================================="
echo "Govbot Development Environment Setup"
echo "==================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if running in correct directory
if [ ! -d "actions/govbot" ]; then
    echo -e "${RED}Error: Must run from toolkit repository root${NC}"
    exit 1
fi

echo -e "${YELLOW}[1/6] Checking Rust installation...${NC}"
if ! command -v rustc &> /dev/null; then
    echo "Rust not found. Installing rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    echo -e "${GREEN}✓ Rust installed${NC}"
else
    RUST_VERSION=$(rustc --version)
    echo -e "${GREEN}✓ Rust already installed: $RUST_VERSION${NC}"
fi

echo ""
echo -e "${YELLOW}[2/6] Checking Cargo tools...${NC}"
if ! command -v just &> /dev/null; then
    echo "Installing 'just' command runner..."
    cargo install just
    echo -e "${GREEN}✓ just installed${NC}"
else
    JUST_VERSION=$(just --version)
    echo -e "${GREEN}✓ just already installed: $JUST_VERSION${NC}"
fi

echo ""
echo -e "${YELLOW}[3/6] Setting up environment variables...${NC}"
# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    cat > .env << 'EOF'
# Govbot Configuration
# Copy this to .env and customize as needed

# GitHub Personal Access Token (required for private repos)
# Create at: https://github.com/settings/tokens
# Required scopes: repo (for private repos)
TOKEN=

# Custom directory for data repositories (default: $HOME/.govbot)
# GOVBOT_DIR=$HOME/.govbot

# Number of parallel clone/pull operations (default: 4)
# GOVBOT_JOBS=4

# Rust build configuration
RUST_BACKTRACE=1
EOF
    echo -e "${GREEN}✓ Created .env file (please configure TOKEN if needed)${NC}"
else
    echo -e "${GREEN}✓ .env file already exists${NC}"
fi

echo ""
echo -e "${YELLOW}[4/6] Creating data directories...${NC}"
GOVBOT_DIR="${GOVBOT_DIR:-$HOME/.govbot}"
mkdir -p "$GOVBOT_DIR/repos"
echo -e "${GREEN}✓ Created $GOVBOT_DIR/repos${NC}"

echo ""
echo -e "${YELLOW}[5/6] Installing Rust dependencies and building govbot...${NC}"
cd actions/govbot
cargo build
cd ../..
echo -e "${GREEN}✓ Govbot built successfully${NC}"

echo ""
echo -e "${YELLOW}[6/6] Verifying installation...${NC}"
cd actions/govbot
if cargo run --bin govbot -- --help > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Govbot is working correctly${NC}"
else
    echo -e "${RED}✗ Govbot test failed${NC}"
    exit 1
fi
cd ../..

echo ""
echo -e "${GREEN}==================================="
echo "Setup Complete! 🎉"
echo "===================================${NC}"
echo ""
echo "Quick Start:"
echo "  1. Edit .env file and add your GitHub TOKEN (if needed)"
echo "  2. Source environment: source .env"
echo "  3. Run govbot:"
echo "     cd actions/govbot"
echo "     cargo run --bin govbot -- clone usa il    # Clone USA and Illinois data"
echo "     cargo run --bin govbot -- logs --help      # See log processing options"
echo ""
echo "Development commands (using just):"
echo "  cd actions/govbot"
echo "  just test          # Run tests"
echo "  just build         # Build debug version"
echo "  just build-release # Build optimized version"
echo "  just review        # Review snapshot test changes"
echo ""
echo "Data will be stored in: $GOVBOT_DIR/repos"
echo ""
