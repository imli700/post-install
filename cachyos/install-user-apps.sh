#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Error in ${0##*/} at line $LINENO" >&2; exit 1' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CARGO_HOME="$HOME/.cargo"

info() { echo "[INFO] $*"; }
error_exit() {
  echo "[ERROR] $*" >&2
  exit 1
}

info "--- User Application Setup Initiated (running as $(whoami)) ---"

# --- Skipping FNM/Node.js installation ---
info "--- Skipping FNM/Node.js installation ---"


# --- Rust (via rustup) ---
install_rust() {
  info "--- Configuring Rust via rustup ---"
  if ! command -v rustup &> /dev/null; then
    error_exit "rustup command not found, system install may have failed."
  fi

  info "Ensuring .cargo directory exists and adding it to PATH..."
  # THE ROBUST FIX: Manually create the directory and add it to the script's PATH.
  # This removes any dependency on rustup's specific behavior for directory creation.
  mkdir -p "$CARGO_HOME/bin"
  export PATH="$CARGO_HOME/bin:$PATH"

  info "Setting default rust toolchain..."
  # Now rustup can install binaries into the directory we already created and added to PATH.
  rustup default stable
  
  info "Installing common Rust components (clippy, rustfmt)..."
  rustup component add clippy rustfmt
  rustup update
  info "--- Rust Setup Finished ---"
}


# --- Main Execution ---
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
