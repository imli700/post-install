#!/usr/bin/env bash

# configure-dotfiles.sh

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

# Ask git directly which files the repo actually tracks, rather than parsing the
# human-readable error text from a failed checkout. That text is not a stable
# interface -- its wording/formatting can change between git versions or locales,
# which would silently break the conflict detection above. Listing the tracked
# files ourselves and checking each against $HOME is deterministic.
mapfile -t tracked_files < <(git_dotfiles ls-tree -r --name-only HEAD)

conflicts=()
for file in "${tracked_files[@]}"; do
  if [ -e "$HOME/$file" ] || [ -L "$HOME/$file" ]; then
    conflicts+=("$file")
  fi
done

if [ "${#conflicts[@]}" -gt 0 ]; then
  info "The following ${#conflicts[@]} file(s) conflict with the dotfiles repo and will be moved:"
  printf '  %s\n' "${conflicts[@]}"
  mkdir -p "$BACKUP_DIR"

  for file in "${conflicts[@]}"; do
    mkdir -p "$(dirname "$BACKUP_DIR/$file")"
    mv "$HOME/$file" "$BACKUP_DIR/$file"
  done
  info "Backup of conflicting files complete. They are stored in: $BACKUP_DIR"
else
  info "No conflicting files detected."
fi

info "Checking out dotfiles..."
# -f is kept as a safety net for anything the pre-check above didn't catch
# (e.g. a directory that needs to become a symlink, or vice versa).
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
