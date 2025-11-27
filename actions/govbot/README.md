# govbot

A CLI tool to download private copies of government legislation for analysis.

## Install

Install + configure the latest nightly build with a single command:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/windy-civi/toolkit/main/actions/govbot/scripts/install-nightly.sh)"
```

The script will:

- Install it to `~/.govbot/bin/govbot` (creating the directory if needed)
- Append `export PATH="$HOME/.govbot/bin:$PATH"` to your first available shell profile (`~/.zshrc`, `~/.zprofile`, `~/.bash_profile`, `~/.bashrc`, or `~/.profile`) if it's not already set
- Auto-source the profile so `govbot` is immediately available

After the script finishes, you can start using it right away:

```bash
govbot # to see help
govbot clone # to download/update everything
govbot clone {{locale}} {{locale}} # to download specific items
govbot delete {{locale}} # to delete specific items
govbot delete all # to delete everything
```

## Development

- Install [Rust Toolchain](https://rustup.rs/)
- `cargo install just` for task runner
- `just setup` for dev setup
- `just` to see available to see available commands

We build snapshots off `examples`. Add examples to make a test.
