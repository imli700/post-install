# install-user-apps.sh
#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Error in ${0##*/} at line $LINENO" >&2; exit 1' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="/home/$USER_NAME"

info() { echo "[INFO] $*"; }
error_exit() {
  echo "[ERROR] $*" >&2
  exit 1
}

info "Running user-apps installer as $USER_NAME (yay-first policy)"

# Ensure yay exists (should have been bootstrapped earlier)
if ! command -v yay >/dev/null 2>&1; then
  error_exit "yay is not installed; aborting. Please run the system installer first to bootstrap yay."
fi

# Example user-level packages
USER_PACKAGES=(
  fnm rustup # keep what you had
  # add more user-level packages here
)

# Install packages using yay as the unprivileged user (yay will sudo for system packages)
if [ ${#USER_PACKAGES[@]} -gt 0 ]; then
  info "Installing user packages via yay (user: $USER_NAME)"
  yay -S --noconfirm --needed "${USER_PACKAGES[@]}" || error_exit "Failed to install user packages via yay"
fi

# call the dotfiles script (run as the user)
NEXT_SCRIPT="$SCRIPT_DIR/configure-dotfiles.sh"
if [ -f "$NEXT_SCRIPT" ] && [ -x "$NEXT_SCRIPT" ]; then
  info "Running dotfiles configuration"
  "$NEXT_SCRIPT"
else
  warn "$NEXT_SCRIPT not found or not executable."
fi

info "install-user-apps.sh finished."
exit 0
