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
YAY_NONINTERACTIVE_FLAGS=(--nocleanmenu --nodiffmenu --noeditmenu --noupgrademenu)

info "Updating system (yay -Syu)..."
sudo -E -u "$SUDO_USER_NAME" yay -Syu --noconfirm "${YAY_NONINTERACTIVE_FLAGS[@]}" || warn "System update failed. Continuing."

# --- Conflict Resolution ---
info "Removing conflicting power-profiles-daemon to install TLP..."
pacman -Rns --noconfirm power-profiles-daemon || true

# --- Package List ---
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
  # Secret Service / Keyring (Required for Readest & password storage)
  gnome-keyring
  libsecret

  # ==========================================
  # WAYLAND / SWAY DESKTOP ENVIRONMENT
  # ==========================================
  # Core UI & Window Management
  sworkstyle   # Sway workspace auto-renaming
  nwg-displays # Display management/configuration
  rofi         # Application launcher
  swaylock     # Screen locker
  polkit-gnome # Authentication agent
  polkit-kde-agent
  # Desktop Portals (Fixes UI freezes, file pickers, theme query)
  xdg-desktop-portal
  xdg-desktop-portal-gtk
  xdg-desktop-portal-wlr
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
  jq             # Needed for notification "collection" feature
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
  yt-dlp  # YouTube and video downloader
  readest # Book reader that syncs progress

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
  # Fonts (Noto fonts required for CEF/Chromium font enumeration fallback)
  nerd-fonts
  ttf-ms-fonts
  noto-fonts
  noto-fonts-cjk
  noto-fonts-emoji

  # ==========================================
  # INTERNET & KEY APPLICATIONS
  # ==========================================
  qutebrowser       # Keyboard-focused web browser
  qbittorrent       # Torrent client
  megasync-bin      # AUR: MEGA cloud storage sync
  anki-bin          # AUR: Flashcard learning software
  bitwarden-cli     # Password manager
  rbw               # Password manager
  keyutils          # Provides keyctl
  python-tldextract # Domain name parser for userscripts

  # ==========================================
  # GAMING & PERIPHERALS
  # ==========================================
  input-remapper # Core virtual gamepad/keyboard mapping tool
  libratbag      # Daemon for configuring gaming mice
  piper          # GUI for libratbag (Mouse DPI/RGB config)
  xorg-xhost     # Utility to allow root GUI apps on Wayland
)

info "Installing all system and application packages via yay..."

failed_packages=()

if sudo -E -u "$SUDO_USER_NAME" yay -S --noconfirm --needed "${YAY_NONINTERACTIVE_FLAGS[@]}" "${packages[@]}"; then
  :
else
  warn "Batch install failed or was only partially successful."
  warn "Retrying package-by-package so a single bad/AUR-broken package doesn't block everything else..."

  for pkg in "${packages[@]}"; do
    info "Installing: $pkg"
    if ! sudo -E -u "$SUDO_USER_NAME" yay -S --noconfirm --needed "${YAY_NONINTERACTIVE_FLAGS[@]}" "$pkg"; then
      warn "Failed to install package: $pkg (continuing with the rest)"
      failed_packages+=("$pkg")
    fi
  done
fi

if [ "${#failed_packages[@]}" -gt 0 ]; then
  warn "-----------------------------------------------------------------"
  warn "The following ${#failed_packages[@]} package(s) failed to install and were skipped:"
  for pkg in "${failed_packages[@]}"; do
    warn "  - $pkg"
  done
  warn "Check the log above for the specific errors, then install these manually with:"
  warn "  yay -S <package>"
  warn "-----------------------------------------------------------------"
else
  info "Package installation complete."
fi

# --- Update Font Cache ---
info "Updating system font cache (fc-cache)..."
fc-cache -f || warn "fc-cache failed to refresh."

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

# --- Configure System Locale ---
info "Configuring system locale (en_IN.UTF-8, en_US.UTF-8)..."
if [ -f /etc/locale.gen ]; then
  sed -i -E 's/^#\s*(en_IN\.UTF-8 UTF-8)/\1/' /etc/locale.gen
  sed -i -E 's/^#\s*(en_US\.UTF-8 UTF-8)/\1/' /etc/locale.gen
  locale-gen || warn "locale-gen encountered errors."
fi

if [ ! -f /etc/locale.conf ] || ! grep -q "LANG=" /etc/locale.conf; then
  echo "LANG=en_IN.UTF-8" >/etc/locale.conf
  echo "LC_ALL=en_IN.UTF-8" >>/etc/locale.conf
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
