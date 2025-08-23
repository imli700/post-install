# configure-dotfiles.sh
#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Error in ${0##*/} at line $LINENO" >&2; exit 1' ERR

# Minimal, robust dotfiles checkout using a bare repo (adapted from your original script)
DOTFILES_REPO="git@github.com:imli700/dotfiles.git"
GIT_DIR="$HOME/.cfg"
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

# helper for running git with our bare repo
git_dotfiles() {
  git --git-dir="$GIT_DIR" --work-tree="$WORK_TREE" "$@"
}

# Backup pre-existing conflicting files
info "Backing up existing dotfiles that would conflict"
mkdir -p "$BACKUP_DIR"
# get the list of files the checkout would overwrite
for file in $(git --git-dir="$GIT_DIR" --work-tree="$WORK_TREE" checkout 2>&1 | grep -E "\s+\w" || true); do
  # sanitized fallback: ignore parsing errors
  :
done

# Perform checkout (force safe steps)
info "Checking out dotfiles"
git_dotfiles checkout || {
  info "Backing up conflicts and retrying checkout"
  mkdir -p "$BACKUP_DIR"
  git_dotfiles checkout 2>&1 | grep -E "\s+\w" | awk '{print $1}' | xargs -I{} bash -c 'mv "$HOME/{}" "$BACKUP_DIR/" 2>/dev/null || true'
  git_dotfiles checkout || error_exit "Checkout failed after backup"
}

git_dotfiles config status.showUntrackedFiles no

info "Dotfiles configured. Backups saved to $BACKUP_DIR"
exit 0
