#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Error in ${0##*/} at line $LINENO" >&2; exit 1' ERR

# Robust dotfiles checkout using a bare repo
DOTFILES_REPO="git@github.com:imli700/dotfiles.git"
GIT_DIR="$HOME/dotfiles"
WORK_TREE="$HOME"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

info() { echo "[INFO] $*"; }
error_exit() {
  echo "[ERROR] $*" >&2
  exit 1
}

info "Cloning dotfiles repo (bare) if not present"
if [ ! -d "$GIT_DIR" ]; then
  git clone --bare "$DOTFILES_REPO" "$GIT_DIR" || error_exit "Failed to clone dotfiles repo"
fi

# Helper alias for running git with our bare repo
git_dotfiles() {
  git --git-dir="$GIT_DIR" --work-tree="$WORK_TREE" "$@"
}

info "Detecting and backing up any pre-existing conflicting files..."

# Isolate the command that is expected to fail to avoid triggering pipefail
checkout_output=$(git_dotfiles checkout 2>&1 || true)

# Now, safely parse the captured output to find the list of conflicting files.
conflicts=$(echo "${checkout_output}" | grep -E "^\s" | awk '{print $1}')

if [ -n "$conflicts" ]; then
  info "The following files conflict with the dotfiles repo and will be moved:"
  echo "$conflicts"
  mkdir -p "$BACKUP_DIR"

  echo "$conflicts" | while IFS= read -r file; do
    if [ -e "$HOME/$file" ] || [ -L "$HOME/$file" ]; then # THIS LINE IS NOW CORRECT
      mkdir -p "$(dirname "$BACKUP_DIR/$file")"
      mv "$HOME/$file" "$BACKUP_DIR/$file"
    fi
  done
  info "Backup of conflicting files complete. They are stored in: $BACKUP_DIR"
fi

info "Forcing checkout of dotfiles..."
# Now, perform the checkout using the --force flag to overwrite any remaining issues.
if ! git_dotfiles checkout -f; then
  error_exit "Dotfiles checkout failed even after backing up conflicts. Manual intervention required."
fi

info "Dotfiles checkout successful."
git_dotfiles config status.showUntrackedFiles no

info "Dotfiles configuration complete!"
info "###################################################################################"
info "#                     AUTOMATED SETUP IS COMPLETE!                                #"
info "###################################################################################"
info ""
info "Please REBOOT now to apply all changes and launch your new environment."
info ""
info "###################################################################################"

exit 0
