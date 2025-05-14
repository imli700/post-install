#!/bin/bash

# --- Standard Error Handling ---
set -e
trap 'echo "An error occurred in $(basename "$0") at line $LINENO. Exiting..." >&2; exit 1' ERR

################################################################################
# DOTFILES CONFIGURATION SCRIPT (PHASE 4)                                      #
#------------------------------------------------------------------------------#
# PURPOSE:                                                                     #
# - Prompt for GitHub SSH key setup (for the dotfiles repo itself).            #
# - Clone/checkout user dotfiles using a bare Git repository.                  #
# - This script is run AS THE REGULAR USER.                                    #
#                                                                              #
# PRE-REQUISITES:                                                              #
# - Run after install-user-apps.sh.                                            #
# - SCRIPT_REPO_ROOT environment variable might be set by parent, not used here.#
################################################################################

# --- Configuration Variables ---
DOTFILES_DIR="$HOME/dotfiles" # Bare repo location
# !!! IMPORTANT: UPDATE THIS TO YOUR ACTUAL DOTFILES REPOSITORY SSH URL !!!
DOTFILES_REPO="git@github.com:imli700/dotfiles.git"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

# --- Helper Functions ---
error_exit() {
  echo "Error: $1" >&2
  exit 1
}

config_git() {
  if ! command -v git &>/dev/null; then
    error_exit "Git command not found. It should have been installed."
  fi
  /usr/bin/git --git-dir="$DOTFILES_DIR/" --work-tree="$HOME" "$@"
}

echo "--- Phase 4: Dotfiles Configuration Initiated (running as $(whoami)) ---"

# --- GitHub SSH Key Prompt (for the DOTFILES_REPO) ---
prompt_github_ssh_for_dotfiles() {
  echo "---------------------------------------------------------------------"
  echo " GitHub SSH Key Check for Dotfiles Repository"
  echo " Your configured Dotfiles Repo URL: $DOTFILES_REPO"
  echo "---------------------------------------------------------------------"
  echo " This step ensures you can clone your dotfiles repository via SSH."
  echo " You should have already set up SSH keys for GitHub when cloning the"
  echo " 'fedora-setup' repository (as per README.md instructions)."
  echo ""
  if [ -f "$HOME/.ssh/id_rsa" ] || [ -f "$HOME/.ssh/id_ed25519" ] || [ -f "$HOME/.ssh/id_ecdsa" ]; then
    echo "SSH key(s) found in $HOME/.ssh/."
    read -p "Is your GitHub SSH access correctly configured for the dotfiles repo? (y/N): " answer
  else
    echo "No common SSH keys (id_rsa, id_ed25519, id_ecdsa) found in $HOME/.ssh/"
    echo "This is unexpected if you followed the README.md to clone 'fedora-setup'."
    echo "Please ensure SSH keys are generated and the public key is added to GitHub."
    echo "See: https://docs.github.com/en/authentication/connecting-to-github-with-ssh"
    read -p "Have you set up SSH access to GitHub for this new OS installation? (y/N): " answer
  fi

  if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    error_exit "Aborting script. Please configure GitHub SSH access for $DOTFILES_REPO first."
  fi
  echo "Proceeding with dotfiles setup..."
}

# --- Dotfiles Logic ---
clone_dotfiles_repo() {
  if [ ! -d "$DOTFILES_DIR" ]; then
    echo "Cloning dotfiles from ${DOTFILES_REPO} into bare repository ${DOTFILES_DIR}..."
    git clone --bare "$DOTFILES_REPO" "$DOTFILES_DIR" # Uses SSH
  else
    echo "Dotfiles bare repository ${DOTFILES_DIR} already exists. Skipping clone."
    echo "Attempting to fetch updates for existing dotfiles repo..."
    if ! config_git fetch origin; then
      echo "Warning: Failed to fetch updates for existing dotfiles repo. Possible SSH issue or repo offline."
    else
      echo "Fetch successful."
    fi
  fi
}

backup_conflicting_dotfiles() {
  echo "Checking for pre-existing files in $HOME that might conflict with dotfiles..."
  mkdir -p "$BACKUP_DIR"

  conflicting_output=$(config_git checkout 2>&1) || true # Allow checkout to "fail" if no branch is checked out yet or list conflicts

  # Parse output for files that would be overwritten.
  # This looks for lines starting with tab/spaces then the filename.
  conflicting_files=$(echo "$conflicting_output" | grep -E "^\s*(error:|warning:|fatal:|\s+)" | grep -v " overwritten by checkout" | grep -v "would be overwritten by merge" | grep -E "^\s+[^\s]+" | awk '{print $1}' | sort -u)

  if [ -n "$conflicting_files" ]; then
    echo "The following files in $HOME might conflict or are untracked by the dotfiles repo:"
    echo "$conflicting_files"
    echo "Backing up these potentially conflicting files to $BACKUP_DIR..."
    echo "$conflicting_files" | while IFS= read -r file_path; do
      # file_path is relative to $HOME (work-tree)
      local_path="$HOME/$file_path"
      if [ -e "$local_path" ] || [ -L "$local_path" ]; then
        echo "Backing up $local_path"
        mkdir -p "$(dirname "${BACKUP_DIR}/${file_path}")" # Create parent dirs in backup
        mv "$local_path" "${BACKUP_DIR}/${file_path}"
      else
        echo "Info: Git listed $local_path, but it doesn't exist or isn't a regular file/symlink. Skipping backup for this item."
      fi
    done
  else
    echo "No obvious conflicting files found by initial checkout simulation, or git produced no relevant output."
  fi
}

checkout_dotfiles_config() {
  echo "Checking out dotfiles (forcing overwrite after backup attempt)..."
  # This assumes the default branch of your dotfiles repo is 'main' or 'master'
  # If not, you might need to specify: config_git checkout -f main
  if ! config_git checkout -f; then
    echo "--------------------------------------------------------------------------------------------"
    echo "ERROR: 'config checkout -f' FAILED."
    echo "This can happen if: "
    echo " - The default branch (e.g., main/master) in your bare repo is not found or is empty."
    echo " - Permissions issues in $HOME or $DOTFILES_DIR."
    echo " - SSH key issues preventing fetch of remote branches if needed for checkout."
    echo "Your original files (if any conflicted) should be in $BACKUP_DIR."
    echo "--------------------------------------------------------------------------------------------"
    error_exit "Dotfiles checkout failed. Manual resolution required."
  fi
  echo "Dotfiles checkout successful."
}

set_dotfiles_config_status() {
  echo "Setting dotfiles config status to hide untracked files in $HOME..."
  config_git config --local status.showUntrackedFiles no || echo "Warning: Failed to set status.showUntrackedFiles for dotfiles repo."
}

# --- Main Execution for Dotfiles ---
prompt_github_ssh_for_dotfiles # Ensure SSH is ready for the dotfiles repo specifically
clone_dotfiles_repo
backup_conflicting_dotfiles
checkout_dotfiles_config
set_dotfiles_config_status

echo ""
echo "--- Phase 4: Dotfiles Configuration Complete ---"
echo "Your dotfiles should now be checked out into $HOME."
echo "Original conflicting files (if any) are backed up in: $BACKUP_DIR"
echo ""
echo "###################################################################################"
echo "#                      SETUP IS COMPLETE! Please REBOOT!                          #"
echo "###################################################################################"
echo "After reboot, ensure your PATH includes $HOME/.local/bin and $FNM_DIR if needed,"
echo "and that your shell sources the new dotfiles (e.g., .bashrc, .zshrc)."
echo "Review any warnings printed during the script execution."

exit 0
