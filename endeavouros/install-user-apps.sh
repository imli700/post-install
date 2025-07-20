#!/bin/bash

# --- Standard Error Handling ---
set -e
trap 'echo "An error occurred in $(basename "$0") at line $LINENO. Exiting..." >&2; exit 1' ERR

################################################################################
# USER APPLICATION INSTALLATION SCRIPT (PHASE 2)                               #
#------------------------------------------------------------------------------#
# PURPOSE:                                                                     #
# - Install user-specific applications (FNM, Rust).                            #
# - This script is run AS THE REGULAR USER.                                    #
# - Calls the next script (configure-dotfiles.sh).                             #
################################################################################

# --- Configuration Variables ---
if [ -z "$SCRIPT_REPO_ROOT" ]; then
  echo "Error: SCRIPT_REPO_ROOT environment variable not set." >&2
  exit 1
fi
FNM_DIR="$HOME/.local/share/fnm"

# --- Helper Functions ---
error_exit() {
  echo "Error: $1" >&2
  exit 1
}

echo "--- User Application Setup Initiated (running as $(whoami)) ---"

# --- FNM, Node, and Global NPM Packages ---
install_fnm_node_and_globals() {
  echo "--- Installing fnm, Node.js, and Global NPM Packages ---"
  mkdir -p "$FNM_DIR"

  if [ -x "$FNM_DIR/fnm" ]; then
    echo "fnm appears to be already installed in $FNM_DIR."
  else
    echo "Installing fnm (Fast Node Manager)..."
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$FNM_DIR" --skip-shell
    if ! [ -x "$FNM_DIR/fnm" ]; then
      error_exit "fnm installation failed."
    fi
    echo "fnm installed to $FNM_DIR."
  fi

  # Temporarily add fnm to PATH for this script session
  export PATH="$FNM_DIR:$PATH"
  eval "$($FNM_DIR/fnm env --shell bash)"

  echo "Installing latest LTS Node.js version using fnm..."
  fnm install --lts
  fnm use lts-latest
  fnm default lts-latest

  echo "Verifying Node.js and npm installation..."
  node -v
  npm -v

  echo "Installing global npm packages..."
  npm install -g live-server neovim @mermaid-js/mermaid-cli
  echo "Global npm packages installation attempted."
  echo "--- FNM/Node/NPM Setup Finished ---"
}

# --- Rust (via rustup) ---
install_rust() {
  echo "--- Installing Rust via rustup ---"
  if command -v rustup &> /dev/null; then
    echo "Rust (rustup) is already installed."
  else
    echo "Installing Rust toolchain..."
    # -y: non-interactive install with default options
    # --no-modify-path: Don't try to edit shell config files, dotfiles will handle it
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
  fi
  
  # Add cargo to the current script's PATH to use it immediately
  source "$HOME/.cargo/env"
  
  # Install common components like clippy (linter) and rustfmt (formatter)
  echo "Installing common Rust components (clippy, rustfmt)..."
  rustup component add clippy rustfmt
  echo "--- Rust Setup Finished ---"
}


# --- Main Execution ---
install_fnm_node_and_globals
install_rust

# --- Call Next Script ---
echo ""
echo "--- User Application Setup Complete ---"
echo "Proceeding to Dotfiles Configuration..."

next_script_dotfiles="${SCRIPT_REPO_ROOT}/endeavouros/configure-dotfiles.sh"
if [ -f "$next_script_dotfiles" ] && [ -x "$next_script_dotfiles" ]; then
  env SCRIPT_REPO_ROOT="$SCRIPT_REPO_ROOT" "$next_script_dotfiles"
else
  error_exit "$next_script_dotfiles not found or not executable. Cannot proceed."
fi

echo "install-user-apps.sh finished successfully."
exit 0
