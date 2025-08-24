#!/usr/bin/env bash

# install-user-apps.sh

set -euo pipefail
trap 'echo "Error in ${0##*/} at line $LINENO" >&2; exit 1' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CARGO_HOME="$HOME/.cargo"
ZSHRC_FILE="$HOME/.zshrc" # Define path to .zshrc

info() { echo "[INFO] $*"; }
error_exit() {
  echo "[ERROR] $*" >&2
  exit 1
}

info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*" >&2; }
error_exit() {
  echo "[ERROR] $*" >&2
  exit 1
}

info "--- User Application Setup Initiated (running as $(whoami)) ---"

# --- FNM & Node.js ---
install_fnm_and_node() {
  info "--- Configuring FNM and installing Node.js LTS ---"
  if ! command -v fnm &>/dev/null; then
    error_exit "fnm command not found, system install may have failed."
  fi

  # Check if fnm is already configured in .zshrc to prevent duplicates
  if ! grep -q 'fnm env' "$ZSHRC_FILE" &>/dev/null; then
    info "Adding fnm to .zshrc..."
    # Create .zshrc if it doesn't exist, then append the line
    touch "$ZSHRC_FILE"
    echo '' >>"$ZSHRC_FILE" # Add a newline for separation
    echo '# FNM (Fast Node Manager)' >>"$ZSHRC_FILE"
    echo 'eval "$(fnm env --use-on-cd)"' >>"$ZSHRC_FILE"
  else
    info "fnm is already configured in .zshrc."
  fi

  # Source the .zshrc to make fnm available in the current script session
  # We need to be careful here as sourcing can have side effects. A subshell is safer.
  info "Sourcing .zshrc in a subshell to load fnm for this script..."
  (
    # shellcheck source=/dev/null
    . "$ZSHRC_FILE"

    info "Installing latest Node.js LTS version..."
    fnm install --lts

    info "Setting the new LTS version as the default..."
    # Get the latest installed version (which will be the one we just installed)
    LATEST_LTS_VERSION=$(fnm list | grep -o 'v[0-9]*\.[0-9]*\.[0-9]*' | sort -V | tail -n 1)
    if [ -n "$LATEST_LTS_VERSION" ]; then
      fnm default "$LATEST_LTS_VERSION"
      info "Node.js LTS version $LATEST_LTS_VERSION set as default."
    else
      warn "Could not determine the latest LTS version to set as default."
    fi
  ) || warn "Subshell for fnm commands failed. Node.js may not be configured."

  info "--- FNM and Node.js Setup Finished ---"
}

# --- Rust (via rustup) ---
install_rust() {
  info "--- Configuring Rust via rustup ---"
  if ! command -v rustup &>/dev/null; then
    error_exit "rustup command not found, system install may have failed."
  fi

  info "Ensuring .cargo directory exists and adding it to PATH..."
  mkdir -p "$CARGO_HOME/bin"
  export PATH="$CARGO_HOME/bin:$PATH"

  info "Setting default rust toolchain..."
  rustup default stable

  info "Installing common Rust components (clippy, rustfmt)..."
  rustup component add clippy rustfmt
  rustup update
  info "--- Rust Setup Finished ---"
}

# --- Main Execution ---
install_fnm_and_node
install_rust

# --- Call Next Script ---
info "--- User Application Setup Complete ---"
info "Proceeding to Dotfiles Configuration..."
next_script_dotfiles="${SCRIPT_DIR}/configure-dotfiles.sh"
if [ -f "$next_script_dotfiles" ] && [ -x "$next_script_dotfiles" ]; then
  "$next_script_dotfiles"
else
  error_exit "$next_script_dotfiles not found or not executable. Cannot proceed."
fi

info "install-user-apps.sh finished successfully."
exit 0
