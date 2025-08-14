#!/bin/bash

# --- Standard Error Handling ---
set -e
trap 'echo "An error occurred in $(basename "$0") at line $LINENO. Exiting..." >&2; exit 1' ERR

################################################################################
# ENDEAVOUROS SYSTEM INSTALLATION SCRIPT (PHASE 1 - MAIN)                      #
#------------------------------------------------------------------------------#
# PURPOSE:                                                                     #
# - This is the main entry point for the entire setup.                         #
# - It performs system updates and installs all required packages from         #
#   official repositories and the AUR.                                         #
# - It applies system-wide tweaks and configurations.                          #
# - It calls subsequent scripts to handle user-specific setup.                 #
################################################################################

# --- Configuration Variables ---
TARGET_HOSTNAME="codeMonkey"
SCRIPT_DIR_SYSTEM_INSTALL="$(dirname "$(readlink -f "$0")")"
ACTUAL_REPO_ROOT="$(dirname "$SCRIPT_DIR_SYSTEM_INSTALL")"

# --- Package List (Official Repos & AUR) ---
packages=(
  # --- System & Utilities ---
  acpi android-tools brightnessctl curl dictd duf fd fzf git hunspell-en_us
  libnotify perl-rename python-pip p7zip ripgrep tlp unrar unzip xclip
  xdg-user-dirs fwupd flatpak swaylock

  # --- Media, Documents & Fonts ---
  calibre libreoffice-fresh mpv mupdf qbittorrent vlc zathura zathura-pdf-mupdf
  xournalpp
  ttf-ms-fonts # AUR
  nerd-fonts
  vimiv
  yt-dlp

  # --- Development & Editors ---
  clang lua51 luarocks
  neovim # ADDED: The actual editor
  wezterm
  kitty

  # --- UI, Sway & Related Tools ---
  grim mako network-manager-applet pavucontrol polkit-kde-agent
  ranger rofi slurp swappy wf-recorder
  nwg-displays  # Maintained alternative to wdisplays
  wshowkeys-git # AUR
  sworkstyle

  # --- Key Applications (from AUR or repos) ---
  qutebrowser
  megasync-bin  # AUR
  anki-bin      # AUR
  wl-mirror-git # AUR

  # --- Hardware Acceleration (AMD) ---
  libva-mesa-driver mesa-vdpau libva-utils vulkan-radeon
)

# --- Helper Functions ---
error_exit() {
  echo "Error: $1" >&2
  exit 1
}

# --- Pre-run Checks ---
if [ "$(id -u)" -ne 0 ]; then
  error_exit "This script must be run as root (sudo)."
fi
SUDO_USER_NAME="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"
if [ -z "$SUDO_USER_NAME" ] || [ "$SUDO_USER_NAME" == "root" ]; then
  error_exit "Could not determine the original user. Critical for subsequent scripts."
fi
# Get the user's actual home directory
USER_HOME_DIR=$(getent passwd "$SUDO_USER_NAME" | cut -d: -f6)
if [ ! -d "$USER_HOME_DIR" ]; then
  error_exit "Home directory for user $SUDO_USER_NAME not found: $USER_HOME_DIR"
fi

echo "--- Main Installation Initiated (from ${SCRIPT_DIR_SYSTEM_INSTALL}) ---"
echo "Repository Root: ${ACTUAL_REPO_ROOT}"
echo "Running as root, for user: $SUDO_USER_NAME"

# --- Ensure yay is installed ---
if ! command -v yay &>/dev/null; then
  echo "AUR helper 'yay' not found. Installing..."
  sudo pacman -S --noconfirm --needed git base-devel
  sudo -u "$SUDO_USER_NAME" sh -c '
    git clone https://aur.archlinux.org/yay.git /tmp/yay && \
    cd /tmp/yay && \
    makepkg -si --noconfirm && \
    cd / && \
    rm -rf /tmp/yay
  '
else
  echo "'yay' is available."
fi

# --- System Update ---
echo "Performing system update (pacman -Syu)..."
# FIX: Remove the invalid Cisco repo from the config before updating
sudo sed -i '/\[cisco-openh264\]/,+2d' /etc/pacman.conf
sudo pacman -Syu --noconfirm || echo "Warning: System update failed. Continuing."

# --- Install All Packages with yay ---
echo "--- Installing all system and application packages via yay ---"
sudo -u "$SUDO_USER_NAME" yay -S --noconfirm --needed "${packages[@]}" || error_exit "Failed to install one or more packages with yay. Aborting."
echo "All specified packages installed successfully."

# --- Add Flathub Remote ---
echo "Adding Flathub remote for Flatpak..."
if command -v flatpak &>/dev/null; then
  sudo -u "$SUDO_USER_NAME" flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || echo "Warning: Failed to add Flathub remote."
fi

# --- Firmware Updates ---
echo "Checking for firmware updates with fwupdmgr..."
# The script may pause here if it needs input.
sudo fwupdmgr refresh --force || echo "Warning: fwupdmgr refresh failed."
sudo fwupdmgr get-updates || echo "Warning: fwupdmgr get-updates failed."
sudo fwupdmgr update -y || echo "Firmware update command finished."

# --- Set Hostname ---
echo "Setting hostname to '$TARGET_HOSTNAME'..."
if [ "$(hostnamectl --static)" != "$TARGET_HOSTNAME" ]; then
  sudo hostnamectl set-hostname "$TARGET_HOSTNAME" || echo "Warning: Failed to set hostname."
else
  echo "Hostname is already set to '$TARGET_HOSTNAME'."
fi

# --- Apply System Tweaks ---
echo "--- Applying System Tweaks ---"
# Disable CPU mitigations (HIGH SECURITY RISK)
GRUB_CONFIG="/etc/default/grub"
if ! grep -q "mitigations=off" "$GRUB_CONFIG"; then
  echo "WARNING: DISABLING CPU MITIGATIONS (mitigations=off). This is a security risk."
  read -p "Do you want to proceed? (yes/NO): " confirm_mitigations
  if [[ "$confirm_mitigations" =~ ^[Yy][Ee][Ss]$ ]]; then
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/&mitigations=off /' "$GRUB_CONFIG"
    sudo grub-mkconfig -o /boot/grub/grub.cfg || echo "Warning: Failed to update grub config."
    echo "Added 'mitigations=off' to kernel arguments. A REBOOT IS REQUIRED."
  else
    echo "Skipping CPU mitigation tweak."
  fi
else
  echo "Kernel arguments already include 'mitigations=off'."
fi

# Enable TLP for power management
echo "Enabling TLP service..."
sudo systemctl enable --now tlp.service || echo "Warning: Failed to enable/start tlp.service."

# --- Call Next Script (as user) ---
echo ""
echo "--- System Setup Complete ---"
echo "Proceeding to User Application Setup (will run as user $SUDO_USER_NAME)..."

next_script_user_apps="${SCRIPT_DIR_SYSTEM_INSTALL}/install-user-apps.sh"
if [ -f "$next_script_user_apps" ] && [ -x "$next_script_user_apps" ]; then
  sudo -E -u "$SUDO_USER_NAME" \
    env HOME="$USER_HOME_DIR" SCRIPT_REPO_ROOT="$ACTUAL_REPO_ROOT" \
    "$next_script_user_apps"
else
  error_exit "$next_script_user_apps not found or not executable. Cannot proceed."
fi

echo "install-system.sh finished successfully."
exit 0
