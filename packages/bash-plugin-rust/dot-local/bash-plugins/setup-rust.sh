#!/bin/bash

# Rust
export CARGO_HOME="$LOCAL/cargo"
export RUSTUP_HOME="$LOCAL/rustup"
if [ -f "$CARGO_HOME/env" ]; then
    source "$CARGO_HOME/env"
else
    setup-rust() {
        rm -irf "$CARGO_HOME" "$RUSTUP_HOME"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
        source "$CARGO_HOME/env"
        cargo component add rust-src rust-analyzer
        cargo install zoxide tree-sitter-cli --locked
        eval "$(zoxide init bash)"
    }
fi

# Zoxide
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init bash)"
fi

