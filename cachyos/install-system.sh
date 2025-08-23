# install-system.sh
#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Error in ${0##*/} at line $LINENO" >&2; exit 1' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUDO_USER_NAME="${SUDO_USER:-$USER}"
USER_HOME_DIR="/home/$SUDO_USER_NAME"

# Detect CachyOS
IS_CACHY=false
if [ -r /etc/os-release ]; then
  . /etc/os-release
  if echo "$NAME" | grep -iq "cachy" || echo "$ID" | grep -iq "cachy"; then
    IS_CACHY=true
  fi
fi

info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*" >&2; }
error_exit() {
  echo "[ERROR] $*" >&2
  exit 1
}

info "Running system install adapted for CachyOS (yay-first policy). Detected CachyOS: $IS_CACHY"

# --- Bootstrap yay if necessary ---
if ! command -v yay >/dev/null 2>&1; then
  warn "'yay' not found. Bootstrapping yay using pacman (this uses pacman only for bootstrap)."
  sudo pacman -S --noconfirm --needed git base-devel || error_exit "Failed to install git/base-devel with pacman"
  sudo -u "$SUDO_USER_NAME" bash -c '
  tmpdir=$(mktemp -d)
  git clone https://aur.archlinux.org/yay.git "$tmpdir/yay" || exit 1
  cd "$tmpdir/yay" || exit 1
  makepkg -si --noconfirm || exit 1
  rm -rf "$tmpdir"
  '
  if ! command -v yay >/dev/null 2>&1; then
    error_exit "Bootstrap failed: yay still not available. Aborting."
  fi
  info "yay bootstrapped successfully. From now on the script will prefer yay for package operations."
fi

# --- Update system (use yay to update Arch + AUR) ---
info "Updating system (yay -Syu)..."
# Use yay as normal user so AUR builds can run; yay will use sudo internally for system packages
sudo -u "$SUDO_USER_NAME" bash -c 'yay -Syu --noconfirm || { echo "Warning: system update failed" >&2; exit 0; }'

# Example package groups - replace with your pacakge lists
SYSTEM_PACKAGES=(
  linux-lts linux-lts-headers # example
  networkmanager rsync unzip curl wget
  # add the packages you want
)

info "Installing system packages via yay (will prefer CachyOS repos when available)"
if [ ${#SYSTEM_PACKAGES[@]} -gt 0 ]; then
  sudo -u "$SUDO_USER_NAME" bash -c "yay -S --noconfirm --needed ${SYSTEM_PACKAGES[*]}" || error_exit "Failed to install system packages via yay"
fi

# Keep the original behaviour: run user-app installer as the declared user
NEXT_USER_SCRIPT="$SCRIPT_DIR/install-user-apps.sh"
if [ -f "$NEXT_USER_SCRIPT" ] && [ -x "$NEXT_USER_SCRIPT" ]; then
  info "Launching user-apps script as $SUDO_USER_NAME"
  sudo -E -u "$SUDO_USER_NAME" HOME="$USER_HOME_DIR" "$NEXT_USER_SCRIPT"
else
  warn "$NEXT_USER_SCRIPT not found or not executable. Skipping."
fi

info "install-system.sh finished."
exit 0
