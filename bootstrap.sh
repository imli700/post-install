#!/bin/bash

# --- Standard Error Handling ---
set -e
# Trap errors and display a message
trap 'echo "An error occurred in $(basename "$0") at line $LINENO. Exiting..." >&2; exit 1' ERR

################################################################################
# FEDORA BOOTSTRAP SCRIPT (PHASE 1)                                            #
#------------------------------------------------------------------------------#
# PURPOSE:                                                                     #
# - Install essential tools for KeePassXC and qutebrowser.                     #
# - Copy KeePassXC AppImage from local repo to $HOME/.local/bin.               #
# - KeePassXC database remains in the local repo's assets/ directory.          #
# - Install MegaSync client.                                                   #
# - Guide user to manually set up KeePassXC & MegaSync.                        #
# - User will then manually run install-system.sh from this repo's scripts dir.#
################################################################################

################################################################################
# !!! CRITICAL PRE-FLIGHT CHECKS - VERIFY BEFORE RUNNING !!!                   #
#------------------------------------------------------------------------------#
# 1. GITHUB SSH ACCESS SET UP? (Needed to clone this `fedora-setup` repo)      #
#    - Have you generated SSH keys and added the public key to GitHub?         #
#    - See README.md for detailed steps if you haven't.                        #
#                                                                              #
# 2. GIT REPOSITORIES PUSHED? (For *other* repos like dotfiles, Neovim config)  #
#    - Your dotfiles bare repository (e.g., git@github.com:user/dotfiles.git)? #
#    - Your Neovim configuration repository (if separate)?                     #
#    - ALL OTHER CRITICAL REPOSITORIES?                                        #
#    FAILURE TO PUSH CHANGES MAY RESULT IN DATA LOSS!                          #
#                                                                              #
# 3. ASSETS DIRECTORY (`./assets/` within this repo):                          #
#    - Is `KeePassXC.AppImage` present and the desired version?                #
#    - Is `MyPasswords.kdbx` present, up-to-date, and committed?               #
#                                                                              #
# 4. MEGASYNC FEDORA VERSION:                                                  #
#    - Is `MEGASYNC_FEDORA_VERSION` below set correctly for target Fedora?     #
################################################################################

# --- Configuration Variables ---
MEGASYNC_FEDORA_VERSION="42" # Example: SET THIS TO 42, 43, etc.

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")" # This will be the directory where fedora-setup is cloned, e.g. ~/programming/fedora-setup
LOCAL_ASSETS_DIR="${SCRIPT_DIR}/assets"
KEEPASSXC_APPIMAGE_NAME="KeePassXC.AppImage"
KEEPASSXC_DB_NAME="MyPasswords.kdbx" # Expected name in assets/

KEEPASSXC_APPIMAGE_DEST_DIR_REL="\$HOME/.local/bin"
KEEPASSXC_APPIMAGE_DEST_NAME="KeePassXC.AppImage"
# KEEPASSXC_DB_DEST_DIR_REL is no longer used for copying DB

MEGASYNC_RPM="megasync-Fedora_${MEGASYNC_FEDORA_VERSION}.x86_64.rpm"
MEGASYNC_URL="https://mega.nz/linux/repo/Fedora_${MEGASYNC_FEDORA_VERSION}/x86_64/${MEGASYNC_RPM}"
DOWNLOAD_DIR_TEMP="/tmp"
MEGASYNC_DOWNLOAD_PATH="${DOWNLOAD_DIR_TEMP}/${MEGASYNC_RPM}"

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
  error_exit "Could not determine the original user. Please run with 'sudo -E' or ensure SUDO_USER is set."
fi
USER_HOME_DIR=$(getent passwd "$SUDO_USER_NAME" | cut -d: -f6)
if [ ! -d "$USER_HOME_DIR" ]; then
  error_exit "Home directory for user $SUDO_USER_NAME not found: $USER_HOME_DIR"
fi

KEEPASSXC_APPIMAGE_DEST_DIR_ABS="${USER_HOME_DIR}/.local/bin"
# KEEPASSXC_DB_DEST_DIR_ABS is no longer used for copying DB

echo "--- Phase 1: Bootstrap Initiated (from ${SCRIPT_DIR}) ---"
echo "Running as root, for user: $SUDO_USER_NAME (Home: $USER_HOME_DIR)"

# --- Install Core Dependencies ---
echo "Installing core dependencies (fuse-libs, qutebrowser, wget)..."
sudo dnf install -y fuse-libs qutebrowser wget || error_exit "Failed to install core dependencies."
echo "Core dependencies installed."

# --- Setup KeePassXC ---
echo "Setting up KeePassXC..."
KEEPASSXC_APPIMAGE_SOURCE="${LOCAL_ASSETS_DIR}/${KEEPASSXC_APPIMAGE_NAME}"
KEEPASSXC_DB_SOURCE="${LOCAL_ASSETS_DIR}/${KEEPASSXC_DB_NAME}" # Path to DB in assets

if [ ! -f "$KEEPASSXC_APPIMAGE_SOURCE" ]; then
  error_exit "KeePassXC AppImage not found at $KEEPASSXC_APPIMAGE_SOURCE. Check ${LOCAL_ASSETS_DIR}."
fi
if [ ! -f "$KEEPASSXC_DB_SOURCE" ]; then # Check if database exists in assets
  error_exit "KeePassXC database not found at $KEEPASSXC_DB_SOURCE. Check ${LOCAL_ASSETS_DIR}."
fi

echo "Creating destination directory for AppImage (if it doesn't exist)..."
sudo -u "$SUDO_USER_NAME" mkdir -p "$KEEPASSXC_APPIMAGE_DEST_DIR_ABS"
# No longer creating KEEPASSXC_DB_DEST_DIR_ABS for the database

echo "Copying KeePassXC AppImage to $KEEPASSXC_APPIMAGE_DEST_DIR_ABS/${KEEPASSXC_APPIMAGE_DEST_NAME}..."
cp "$KEEPASSXC_APPIMAGE_SOURCE" "$KEEPASSXC_APPIMAGE_DEST_DIR_ABS/${KEEPASSXC_APPIMAGE_DEST_NAME}"
chmod +x "$KEEPASSXC_APPIMAGE_DEST_DIR_ABS/${KEEPASSXC_APPIMAGE_DEST_NAME}"
chown "$SUDO_USER_NAME:$SUDO_USER_NAME" "$KEEPASSXC_APPIMAGE_DEST_DIR_ABS/${KEEPASSXC_APPIMAGE_DEST_NAME}"

# --- Database is NOT copied ---
echo "KeePassXC database ($KEEPASSXC_DB_NAME) will be used from: $KEEPASSXC_DB_SOURCE"
echo "KeePassXC AppImage setup complete. Database remains in repository assets."

# --- MegaSync Installation ---
echo "Installing MegaSync for Fedora ${MEGASYNC_FEDORA_VERSION}..."
echo "(Using manually configured URL: ${MEGASYNC_URL})"

echo "Downloading MegaSync RPM from ${MEGASYNC_URL} to ${MEGASYNC_DOWNLOAD_PATH}..."
wget -q -O "${MEGASYNC_DOWNLOAD_PATH}" "${MEGASYNC_URL}"
if [ $? -ne 0 ]; then
  rm -f "${MEGASYNC_DOWNLOAD_PATH}" # Attempt cleanup
  error_exit "Failed to download MegaSync RPM. Please check the URL/version configured."
fi
echo "Download complete."

echo "Installing downloaded MegaSync RPM: ${MEGASYNC_DOWNLOAD_PATH}..."
sudo dnf install -y --allowerasing "${MEGASYNC_DOWNLOAD_PATH}"
if [ $? -ne 0 ]; then
  rm -f "${MEGASYNC_DOWNLOAD_PATH}" # Attempt cleanup
  error_exit "Failed to install MegaSync from downloaded RPM."
fi
rm -f "${MEGASYNC_DOWNLOAD_PATH}" # Clean up downloaded RPM
echo "MegaSync client installed successfully."

# --- Final Instructions ---
echo ""
echo "----------------------------------------------------------------------------------"
echo "--- Bootstrap (Phase 1) Complete! ---"
echo "----------------------------------------------------------------------------------"
echo "NEXT STEPS (MANUAL ACTIONS REQUIRED BY YOU, $SUDO_USER_NAME):"
echo ""
echo "1. Ensure '$KEEPASSXC_APPIMAGE_DEST_DIR_REL' is in your PATH."
echo "   If not, open a NEW terminal or add it temporarily: export PATH=\"$KEEPASSXC_APPIMAGE_DEST_DIR_ABS:\$PATH\""
echo "   For permanent addition, edit your shell's config file (e.g., ~/.bashrc, ~/.zshrc)."
echo ""
echo "2. Launch KeePassXC:"
echo "   Command: ${KEEPASSXC_APPIMAGE_DEST_NAME}"
echo ""
echo "3. Open your database:"
echo "   The database file is located within your cloned 'fedora-setup' repository."
echo "   Path: ${KEEPASSXC_DB_SOURCE}"
echo "   (Which is: ${SCRIPT_DIR}/assets/${KEEPASSXC_DB_NAME})"
echo ""
echo "4. Retrieve your MegaSync credentials from KeePassXC."
echo ""
echo "5. Launch the MegaSync client (from your desktop environment's application menu)."
echo "   Log in and configure it. **ALLOW IT TO SYNCHRONIZE ALL YOUR FILES.**"
echo "   This is crucial as subsequent scripts may rely on files in your Mega cloud storage"
echo "   (e.g., Anki backups, application data for 'install-user-apps.sh')."
echo ""
echo "6. Once MegaSync is FULLY SYNCED, open a terminal and ensure you are still in (or navigate back to)"
echo "   the '${SCRIPT_DIR}' directory (where this fedora-setup repository is cloned):"
echo "   Command: cd ${SCRIPT_DIR}"
echo ""
echo "7. Run the next phase of the installation from the '${SCRIPT_DIR}' directory:"
echo "   (Ensuring you are in '${SCRIPT_DIR}')"
echo "   Command: sudo ./scripts/install-system.sh"
echo "----------------------------------------------------------------------------------"

exit 0
