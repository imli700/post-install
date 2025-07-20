#!/bin/bash

# --- Standard Error Handling ---
set -e
trap 'echo "An error occurred in $(basename "$0") at line $LINENO. Exiting..." >&2; exit 1' ERR

################################################################################
# DOTFILES CONFIGURATION SCRIPT (PHASE 3)                                      #
#------------------------------------------------------------------------------#
# PURPOSE:                                                                     #
# - Clone/checkout user dotfiles using a bare Git repository.                  #
# - This is the final script in the automated chain.                           #
################################################################################

# --- Configuration Variables ---
DOTFILES_DIR="$HOME/dotfiles" # Bare repo location
DOTFILES_REPO="git@github.com:imli700/dotfiles.git"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

# --- Helper Functions ---
error_exit() {
  echo "Error: $1" >&2
  exit 1
}

# Alias for git bare repo operations
config_git() {
  /usr/bin/git --git-dir="$DOTFILES_DIR/" --work-tree="$HOME" "$@"
}

echo "--- Dotfiles Configuration Initiated (running as $(whoami)) ---"

# --- GitHub SSH Key Prompt ---
prompt_github_ssh_for_dotfiles() {
  echo "---------------------------------------------------------------------"
  echo "This script will now clone your dotfiles from: $DOTFILES_REPO"
  echo "It assumes you have already configured SSH access to GitHub to clone the post-install repo."
  echo "---------------------------------------------------------------------"
  read -p "Is your GitHub SSH access correctly configured? (y/N): " answer
  if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    error_exit "Aborting script. Please configure GitHub SSH access first."
  fi
}

# --- Dotfiles Logic ---
clone_dotfiles_repo() {
  if [ ! -d "$DOTFILES_DIR" ]; then
    echo "Cloning dotfiles from ${DOTFILES_REPO} into bare repository ${DOTFILES_DIR}..."
    git clone --bare "$DOTFILES_REPO" "$DOTFILES_DIR"
  else
    echo "Dotfiles bare repository already exists. Fetching updates..."
    config_git fetch origin || echo "Warning: Failed to fetch updates for dotfiles repo."
  fi
}

backup_and_checkout() {
    echo "Checking out dotfiles. This may overwrite existing configuration files."
    
    # Try a dry-run first to see conflicts
    conflicts=$(config_git checkout 2>&1 | grep -E "^\s" | awk '{print $1}')

    if [ -n "$conflicts" ]; then
        echo "The following files conflict with your dotfiles repo:"
        echo "$conflicts"
        echo "Backing up conflicting files to $BACKUP_DIR..."
        mkdir -p "$BACKUP_DIR"
        echo "$conflicts" | while IFS= read -r file; do
            if [ -e "$HOME/$file" ] || [ -L "$HOME/$file" ]; then
                mkdir -p "$(dirname "$BACKUP_DIR/$file")"
                mv "$HOME/$file" "$BACKUP_DIR/$file"
            fi
        done
        echo "Backup complete. Now forcing checkout."
    fi

    # Now checkout for real, forcing it.
    if ! config_git checkout -f; then
        error_exit "Dotfiles checkout failed even after backup. Manual resolution required."
    fi

    echo "Dotfiles checkout successful."
}


set_dotfiles_config_status() {
  echo "Setting dotfiles config status to hide untracked files..."
  config_git config --local status.showUntrackedFiles no
}

# --- Main Execution ---
prompt_github_ssh_for_dotfiles
clone_dotfiles_repo
backup_and_checkout
set_dotfiles_config_status

echo ""
echo "--- Dotfiles Configuration Complete ---"
echo "Original conflicting files (if any) are backed up in: $BACKUP_DIR"
echo ""
echo "###################################################################################"
echo "#                     AUTOMATED SETUP IS COMPLETE!                                #"
echo "###################################################################################"
echo ""
echo "Please REBOOT now to apply all changes (e.g., kernel arguments)."
echo ""
echo "After rebooting, you can launch your applications. To restore your personal documents,"
echo "launch MegaSync from the application launcher, log in, and let it sync your files."
echo ""
echo "###################################################################################"

exit 0
