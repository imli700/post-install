#!/usr/bin/env bash

# install-system.sh

set -euo pipefail
trap 'echo "Error in ${0##*/} at line $LINENO" >&2; exit 1' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUDO_USER_NAME="${SUDO_USER:-$USER}"
USER_HOME_DIR=$(getent passwd "$SUDO_USER_NAME" | cut -d: -f6)
TARGET_HOSTNAME="codeMonkey"

info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*" >&2; }
error_exit() {
  echo "[ERROR] $*" >&2
  exit 1
}

if [ "$(id -u)" -ne 0 ]; then
  error_exit "This script must be run as root (sudo)."
fi

info "Running system install for CachyOS..."

# --- Bootstrap yay if necessary ---
if ! command -v yay >/dev/null 2>&1; then
  warn "'yay' not found. Bootstrapping..."
  pacman -S --noconfirm --needed git base-devel
  sudo -E -u "$SUDO_USER_NAME" bash -c '
    git clone https://aur.archlinux.org/yay.git /tmp/yay && \
    cd /tmp/yay && \
    makepkg -si --noconfirm && \
    cd / && \
    rm -rf /tmp/yay
  '
  if ! command -v yay >/dev/null 2>&1; then
    error_exit "Bootstrap failed: yay still not available."
  fi
  info "yay bootstrapped successfully."
fi

# --- System Update ---
info "Updating system (yay -Syu)..."
sudo -E -u "$SUDO_USER_NAME" yay -Syu --noconfirm --editmenu=false --diffmenu=false || warn "System update failed. Continuing."

# --- Conflict Resolution ---
info "Removing conflicting power-profiles-daemon to install TLP..."
# Use pacman directly for removal. The || true prevents script exit if it's not installed.
pacman -Rns --noconfirm power-profiles-daemon || true

# --- Package List (Corrected and made specific) ---
packages=(
  # --- System & Utilities ---
  acpi android-tools brightnessctl curl dictd duf fd fzf git hunspell-en_us
  libnotify perl-rename python-pip 7zip ripgrep tlp unrar unzip xclip
  xdg-user-dirs fwupd flatpak swaylock rate-mirrors

  # --- Media, Documents & Fonts ---
  calibre libreoffice-fresh mpv mupdf qbittorrent vlc zathura zathura-pdf-mupdf
  xournalpp
  ttf-ms-fonts                              # AUR
  ttf-jetbrains-mono-nerd ttf-firacode-nerd # Specific Nerd Fonts
  vimiv
  yt-dlp

  # --- Development & Editors ---
  clang lua51 luarocks rustup # Add rustup to provide cargo
  neovim
  wezterm
  kitty
  lazygit

  # --- UI, Sway & Related Tools ---
  grim mako network-manager-applet pavucontrol polkit-kde-agent
  ranger rofi slurp swappy wf-recorder
  nwg-displays
  wshowkeys-git # AUR
  sworkstyle
  texlive-core
  texlive-latexextra
  nerd-fonts

  # --- Key Applications ---
  qutebrowser
  megasync-bin  # AUR
  anki-bin      # AUR
  wl-mirror-git # AUR

  # --- Hardware Acceleration (AMD) ---
  libva-mesa-driver mesa-vdpau libva-utils vulkan-radeon
)

info "Installing all system and application packages via yay..."
# Added --noeditmenu and --nodiffmenu to ensure non-interaction
sudo -E -u "$SUDO_USER_NAME" yay -S --noconfirm --needed --editmenu=false --diffmenu=false "${packages[@]}" || error_exit "Failed to install one or more packages."
info "Package installation complete."

# --- Add Flathub Remote ---
info "Adding Flathub remote for Flatpak..."
if command -v flatpak &>/dev/null; then
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || warn "Failed to add Flathub remote."
fi

# --- Firmware Updates ---
info "Checking for firmware updates with fwupdmgr..."
fwupdmgr refresh --force || warn "fwupdmgr refresh failed."
fwupdmgr get-updates || warn "fwupdmgr get-updates failed."
fwupdmgr update -y || info "Firmware update command finished."

# --- Set Hostname ---
info "Setting hostname to '$TARGET_HOSTNAME'..."
if [ "$(hostnamectl --static)" != "$TARGET_HOSTNAME" ]; then
  hostnamectl set-hostname "$TARGET_HOSTNAME" || warn "Failed to set hostname."
else
  info "Hostname is already set."
fi

# --- Enable TLP ---
info "Enabling TLP service for power management..."
systemctl enable --now tlp.service || warn "Failed to enable/start tlp.service."

# --- Call Next Script (as user) ---
info "Proceeding to User Application Setup (running as $SUDO_USER_NAME)..."
next_script_user_apps="${SCRIPT_DIR}/install-user-apps.sh"
if [ -f "$next_script_user_apps" ] && [ -x "$next_script_user_apps" ]; then
  sudo -E -u "$SUDO_USER_NAME" \
    env HOME="$USER_HOME_DIR" SCRIPT_REPO_ROOT="$SCRIPT_DIR" \
    "$next_script_user_apps"
else
  error_exit "$next_script_user_apps not found or not executable."
fi

info "install-system.sh finished successfully."
exit 0
