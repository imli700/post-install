#!/bin/bash

# --- Standard Error Handling ---
set -e
trap 'echo "An error occurred in $(basename "$0") at line $LINENO. Exiting..." >&2; exit 1' ERR

################################################################################
# FEDORA SYSTEM INSTALLATION SCRIPT (PHASE 2)                                  #
#------------------------------------------------------------------------------#
# PURPOSE:                                                                     #
# - Install system repositories (RPMFusion, Terra).                            #
# - Perform system updates.                                                    #
# - Install core groups, multimedia codecs, hardware acceleration.             #
# - Install a list of specified DNF packages.                                  #
# - Perform firmware updates.                                                  #
# - Set system hostname.                                                       #
# - Apply system-wide tweaks.                                                  #
# - Call the next script (install-user-apps.sh) as original user.              #
#                                                                              #
# PRE-REQUISITES:                                                              #
# - Run after bootstrap.sh.                                                    #
# - User has manually logged into MegaSync and allowed it to FULLY SYNC.       #
# - This script is run from the '~/fedora-setup/scripts/' directory.           #
################################################################################

# --- Configuration Variables ---
TARGET_HOSTNAME="codeMonkey"
FEDORA_VERSION=$(rpm -E %fedora)
# SCRIPT_DIR_SYSTEM_INSTALL is the directory this script is in (e.g., ~/fedora-setup/scripts)
SCRIPT_DIR_SYSTEM_INSTALL="$(dirname "$(readlink -f "$0")")"
# ACTUAL_REPO_ROOT is the parent directory (e.g., ~/fedora-setup)
ACTUAL_REPO_ROOT="$(dirname "$SCRIPT_DIR_SYSTEM_INSTALL")"

packages=(
  acpi android-tools brightnessctl calibre clang curl dictd dnf-plugins-core duf
  fd-find flatpak fuse-libs fzf git grim hunspell-en-us libnotify libva libva-utils libreoffice
  lua5.1-devel luarocks lxqt-policykit mako mozilla-openh264 mpv mscore-fonts
  mupdf neovim network-manager-applet pavucontrol prename python3-pip
  p7zip p7zip-plugins qbittorrent qutebrowser ranger ripgrep rofi-wayland slurp swappy
  tlp tmux unrar unzip vimiv vlc wdisplays wget wf-recorder wshowkeys xdg-user-dirs xournalpp
  zathura zathura-plugins-all xclip
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

echo "--- Phase 2: System Installation Initiated (from ${SCRIPT_DIR_SYSTEM_INSTALL}) ---"
echo "Repository Root: ${ACTUAL_REPO_ROOT}"
echo "Running as root, for user: $SUDO_USER_NAME"
echo "Fedora Version: ${FEDORA_VERSION}"
echo "IMPORTANT: Ensure MegaSync has fully synced before proceeding if you skipped steps!"

# --- Install Repositories ---
echo "Installing RPMFusion repositories for Fedora ${FEDORA_VERSION}..."
echo "Installing RPMFusion free repository..."
sudo dnf install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm" ||
  echo "Warning: Failed to install RPMFusion free repository. DNF output should be above. Continuing."
echo "Installing RPMFusion non-free repository..."
sudo dnf install -y "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm" ||
  echo "Warning: Failed to install RPMFusion non-free repository. DNF output should be above. Continuing."

echo "Installing Terra repository..."
sudo dnf install -y --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release ||
  echo "Warning: Failed to install Terra repository. DNF output should be above. Continuing."
echo "Repositories installation process finished."

# --- Initial System Update ---
echo "Performing system update (after adding new repos)..."
sudo dnf update -y || echo "Warning: System update (dnf update -y) failed. DNF output should be above. Continuing."
echo "System update process finished."

# --- Install Core Groups and Flatpak ---
echo "Updating 'core' group..."
sudo dnf group upgrade -y core || echo "Warning: 'core' group upgrade had issues. Continuing."

echo "Installing Flatpak and adding Flathub..."
if ! command -v flatpak &>/dev/null; then
  sudo dnf install -y flatpak || echo "Warning: Failed to install flatpak. Continuing."
fi
if command -v flatpak &>/dev/null; then
  if ! flatpak remote-list | grep -q '^flathub\s'; then
    sudo -u "$SUDO_USER_NAME" flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || echo "Warning: Failed to add Flathub remote for user $SUDO_USER_NAME. Continuing."
    echo "Flathub added for user $SUDO_USER_NAME (or attempt made)."
  else
    echo "Flathub remote already exists for user $SUDO_USER_NAME (or system-wide)."
  fi
else
  echo "Flatpak not installed, skipping Flathub setup."
fi

# --- Setup Multimedia Codecs ---
echo "Setting up multimedia codecs..."
echo "Swapping ffmpeg-free for ffmpeg..."
sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing || echo "Warning: Failed to swap ffmpeg-free for ffmpeg. Continuing."
echo "Installing/updating 'multimedia' group..."
sudo dnf group upgrade -y multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin || echo "Warning: Failed to upgrade 'multimedia' group. Continuing."
echo "Installing/updating 'sound-and-video' group..."
sudo dnf group install -y sound-and-video || echo "Warning: Failed to install 'sound-and-video' group. Continuing."
echo "Multimedia codecs setup attempted."

# --- Setup Hardware Video Acceleration ---
echo "Setting up hardware video acceleration (Core VA-API and AMD/Intel)..."
echo "Installing VA-API libraries..."
sudo dnf install -y libva libva-utils || echo "Warning: Failed to install VA-API libraries. Continuing."
echo "Swapping Mesa VA/VDPAU drivers for freeworld versions..."
sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld --allowerasing || echo "Warning: Failed to swap mesa-va-drivers. Continuing."
sudo dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld --allowerasing || echo "Warning: Failed to swap mesa-vdpau-drivers. Continuing."
echo "Hardware video acceleration setup attempted."

# --- Enable Cisco OpenH264 Repository ---
echo "Enabling Fedora Cisco OpenH264 repository..."
if ! rpm -q dnf-plugins-core &>/dev/null; then
  echo "Installing dnf-plugins-core..."
  sudo dnf install -y dnf-plugins-core || echo "Warning: Failed to install dnf-plugins-core. Continuing."
fi
if rpm -q dnf-plugins-core &>/dev/null; then
  sudo dnf config-manager --set-enabled fedora-cisco-openh264 || echo "Warning: Failed to enable fedora-cisco-openh264 repo. Continuing."
  echo "Fedora Cisco OpenH264 repository enabled (or attempt made)."
  sudo dnf install -y gstreamer1-plugin-openh264 mozilla-openh264 openh264 || echo "Warning: Failed to install OpenH264 packages. Continuing."
else
  echo "dnf-plugins-core not available, skipping Cisco OpenH264 repo enabling."
fi

# --- Install DNF Packages ---
echo "--- Installing DNF Packages ---"
failed_packages=()
for pkg in "${packages[@]}"; do
  echo "Attempting to install $pkg..."
  if ! sudo dnf install -y "$pkg"; then
    echo "Warning: Failed to install $pkg. DNF error message should be above. Adding to failed list."
    failed_packages+=("$pkg")
  else
    echo "$pkg installation check complete (installed or already present)."
  fi
done

if [ ${#failed_packages[@]} -ne 0 ]; then
  echo ""
  echo "#####################################################"
  echo "# WARNING: DNF Package Installation Issues          #"
  echo "#####################################################"
  echo "The following packages failed to install or had issues:"
  printf " - %s\n" "${failed_packages[@]}"
  echo "Please check DNF logs above. Script will continue."
  echo "#####################################################"
  echo ""
else
  echo "All specified DNF packages installed successfully or were already present."
fi
echo "--- DNF Package Installation Phase Complete ---"

# --- Firmware Updates ---
echo "Checking for firmware updates..."
if command -v fwupdmgr &>/dev/null; then
  sudo fwupdmgr refresh --force || echo "Warning: fwupdmgr refresh failed. Continuing."
  sudo fwupdmgr get-updates || echo "Warning: fwupdmgr get-updates failed. Continuing."
  echo "Attempting firmware updates if available (will not halt script on error)..."
  sudo fwupdmgr update -y || echo "Firmware update command finished (may or may not have had updates/errors). Continuing."
  echo "Firmware update process finished (check output above for details)."
else
  echo "fwupdmgr command not found. Skipping firmware update."
fi

# --- Set Hostname ---
echo "--- Setting Hostname ---"
current_hostname=$(hostnamectl --static)
if [ "$current_hostname" == "$TARGET_HOSTNAME" ]; then
  echo "Hostname is already set to '$TARGET_HOSTNAME'."
else
  echo "Setting hostname to '$TARGET_HOSTNAME'..."
  if ! sudo hostnamectl set-hostname "$TARGET_HOSTNAME"; then
    echo "Warning: Failed to set hostname. Continuing."
  else
    echo "Hostname set successfully to $TARGET_HOSTNAME."
  fi
fi
echo "--- Hostname Setup Finished ---"

# --- Apply System Tweaks ---
echo "--- Applying System Tweaks ---"
# Disable CPU mitigations (HIGH SECURITY RISK)
echo "Checking kernel arguments for mitigations=off..."
if ! sudo grubby --info DEFAULT | grep -q 'args=.*mitigations=off'; then
  echo "-------------------------------------------------------------------------------------------------"
  echo "WARNING: DISABLING CPU MITIGATIONS (mitigations=off)"
  echo "This improves performance but SIGNIFICANTLY REDUCES SECURITY against Spectre/Meltdown vulnerabilities."
  echo "Understand the risks before proceeding. This is generally NOT RECOMMENDED for most users."
  echo "-------------------------------------------------------------------------------------------------"
  read -p "Do you want to proceed with disabling CPU mitigations? (yes/NO): " confirm_mitigations
  if [[ "$confirm_mitigations" =~ ^[Yy][Ee][Ss]$ ]]; then # require 'yes'
    if ! sudo grubby --update-kernel=ALL --args="mitigations=off"; then
      echo "Warning: Failed to update kernel args for mitigations. Continuing."
    else
      echo "Added 'mitigations=off' to kernel arguments. A REBOOT IS REQUIRED for this to take effect."
    fi
  else
    echo "Skipping CPU mitigation tweak."
  fi
else
  echo "Kernel arguments already include 'mitigations=off'."
fi

# Disable NetworkManager-wait-online.service
echo "Disabling NetworkManager-wait-online.service..."
if sudo systemctl is-enabled NetworkManager-wait-online.service &>/dev/null; then
  sudo systemctl disable NetworkManager-wait-online.service || echo "Warning: Failed to disable NetworkManager-wait-online.service. Continuing."
  echo "NetworkManager-wait-online.service disabled."
else
  echo "NetworkManager-wait-online.service is already disabled."
fi

# Disable Gnome Software autostart
gnome_sw_autostart="/etc/xdg/autostart/org.gnome.Software.desktop"
if [ -f "$gnome_sw_autostart" ]; then
  echo "Disabling Gnome Software autostart..."
  sudo rm -f "$gnome_sw_autostart" || echo "Warning: Failed to remove Gnome Software autostart file. Continuing."
else
  echo "Gnome Software autostart file not found (already removed or different path)."
fi
echo "--- System Tweaks Application Finished ---"

# --- Call Next Script (as user) ---
echo ""
echo "--- Phase 2: System Installation Complete ---"
echo "Proceeding to Phase 3: User Application Setup (will run as user $SUDO_USER_NAME)..."

# next_script_user_apps is in the same directory as this script (SCRIPT_DIR_SYSTEM_INSTALL)
next_script_user_apps="${SCRIPT_DIR_SYSTEM_INSTALL}/install-user-apps.sh"
if [ -f "$next_script_user_apps" ] && [ -x "$next_script_user_apps" ]; then
  # Preserve environment, run as the original user
  # Pass ACTUAL_REPO_ROOT so child scripts know the main 'fedora-setup' repo root path
  sudo -E -u "$SUDO_USER_NAME" \
    env SCRIPT_REPO_ROOT="$ACTUAL_REPO_ROOT" \
    "$next_script_user_apps"
else
  error_exit "$next_script_user_apps not found or not executable in ${SCRIPT_DIR_SYSTEM_INSTALL}. Cannot proceed."
fi

echo "install-system.sh finished successfully."
exit 0
