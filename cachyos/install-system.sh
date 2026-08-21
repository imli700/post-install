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
  # ==========================================
  # SYSTEM, HARDWARE & DRIVERS
  # ==========================================
  # AMD Hardware Acceleration
  libva-mesa-driver
  mesa-vdpau
  libva-utils
  vulkan-radeon
  # System Tools & Power Management
  acpi          # Battery/power status
  tlp           # Advanced power management
  fwupd         # Firmware update daemon
  brightnessctl # Backlight control
  rate-mirrors  # Arch mirror ranking
  flatpak       # Sandboxed application packaging
  xdg-user-dirs # Manages standard user directories (~/Downloads, etc.)
  # Networking
  network-manager-applet # GUI applet for NetworkManager

  # ==========================================
  # WAYLAND / SWAY DESKTOP ENVIRONMENT
  # ==========================================
  # Core UI & Window Management
  sworkstyle       # Sway workspace auto-renaming
  nwg-displays     # Display management/configuration
  rofi             # Application launcher
  swaylock         # Screen locker
  polkit-gnome     # Authentication agent (Note: You usually only need one...)
  polkit-kde-agent # ...you can probably remove either this or the GNOME one.
  # Clipboard & Notifications
  wl-clipboard # Wayland clipboard utilities
  clipse       # Wayland clipboard manager
  xclip        # X11 clipboard fallback (useful for Xwayland)
  mako         # Wayland notification daemon
  libnotify    # Notification library (sends notifications to mako)
  # Screen Capture & Recording
  grim        # Wayland screenshot tool
  slurp       # Select a region in Wayland (pairs with grim)
  swappy      # Wayland screenshot editing tool
  wf-recorder # Wayland screen recorder
  # Specialized Wayland Tools (AUR)
  wl-mirror-git # AUR: Output mirror for Wayland
  wshowkeys-git # AUR: Displays keypresses on screen

  # ==========================================
  # TERMINAL, DEVELOPMENT & CLI TOOLS
  # ==========================================
  # Terminal Emulators
  kitty
  wezterm
  # Editors
  neovim
  gvim
  # Development & Languages
  git
  lazygit # Terminal UI for git
  clang   # C/C++ compiler
  rustup  # Provides cargo and rustc
  lua51
  luarocks        # Lua package manager
  fnm             # Fast Node Manager
  tree-sitter-cli # Parsing tool (great for Neovim)
  # CLI Utilities & Search
  curl
  fd             # Better 'find'
  fzf            # Fuzzy finder
  ripgrep        # Better 'grep'
  duf            # Better 'df' (disk usage)
  peco           # Simplistic interactive filtering tool
  perl-rename    # Advanced file renaming
  dictd          # Dictionary client/server
  hunspell-en_us # Spell checking
  magick         # ImageMagick CLI image manipulation
  python-pip     # Python package manager
  # File Managers & Archives
  ranger # CLI file manager
  7zip
  unrar
  unzip

  # ==========================================
  # MEDIA, AUDIO & VIDEO
  # ==========================================
  # Media Players & Viewers
  mpv   # CLI video player
  vlc   # GUI video player
  vimiv # Image viewer with vim-like keybindings
  playerctl
  # Audio
  pavucontrol # PulseAudio/PipeWire volume control GUI
  # GStreamer (Multimedia Framework Plugins)
  gst-plugins-base
  gst-plugins-good
  gst-plugins-bad
  gst-plugins-ugly
  gst-libav
  # Media Downloaders
  yt-dlp # YouTube and video downloader

  # ==========================================
  # DOCUMENTS, OFFICE & FONTS
  # ==========================================
  # Office & PDF
  libreoffice-fresh
  mupdf     # Lightweight PDF viewer
  xournalpp # PDF annotation and note-taking
  # Zathura (Document Viewer & Backends)
  zathura
  zathura-pdf-poppler
  zathura-ps
  zathura-djvu
  zathura-cb # Comic book support
  # E-Books & Typesetting
  calibre      # E-book manager
  texlive-core # LaTeX
  texlive-latexextra
  # Fonts
  nerd-fonts   # Developer fonts with icons
  ttf-ms-fonts # Microsoft core fonts (Arial, Times New Roman, etc.)

  # ==========================================
  # INTERNET & KEY APPLICATIONS
  # ==========================================
  qutebrowser       # Keyboard-focused web browser
  qbittorrent       # Torrent client
  megasync-bin      # AUR: MEGA cloud storage sync
  anki-bin          # AUR: Flashcard learning software
  bitwarden-cli     # Password manager
  rbw               # Password manager
  jq                # To use with rbw to use in qutebrowser
  keyutils          # Provides keyctl, used to cache your session key securely in the kernel keyring
  python-tldextract # Python library the userscript uses to parse domain names

  # ==========================================
  # GAMING & PERIPHERALS
  # ==========================================
  input-remapper # Core virtual gamepad/keyboard mapping tool
  libratbag      # Daemon for configuring gaming mice
  piper          # GUI for libratbag (Mouse DPI/RGB config)
  xorg-xhost     # Utility to allow root GUI apps on Wayland (useful for debugging/Cemu)
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
