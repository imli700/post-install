#!/bin/bash

# --- Standard Error Handling ---
set -e
# Trap errors and display a message
trap 'echo "An error occurred in $(basename "$0") at line $LINENO. Exiting..." >&2; exit 1' ERR

################################################################################
# FEDORA BOOTSTRAP SCRIPT (PHASE 1)                                            #
#------------------------------------------------------------------------------#
# PURPOSE:                                                                     #
# - Install essential tools for password access (qutebrowser for Bitwarden).   #
# - Install MegaSync client.                                                   #
# - Guide user to manually set up MegaSync using credentials from Bitwarden.   #
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
# 3. MEGASYNC FEDORA VERSION:                                                  #
#    - Is `MEGASYNC_FEDORA_VERSION` below set correctly for target Fedora?     #
################################################################################

# --- Configuration Variables ---
MEGASYNC_FEDORA_VERSION="42" # Example: SET THIS TO 42, 43, etc.

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")" # This will be the directory where fedora-setup is cloned, e.g. ~/programming/fedora-setup

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

echo "--- Phase 1: Bootstrap Initiated (from ${SCRIPT_DIR}) ---"
echo "Running as root, for user: $SUDO_USER_NAME (Home: $USER_HOME_DIR)"

# --- Install Core Dependencies ---
echo "Installing core dependencies (qutebrowser, wget)..."
sudo dnf install -y qutebrowser wget || error_exit "Failed to install core dependencies."
echo "Core dependencies installed."

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
echo "1. Launch your web browser (qutebrowser was just installed)."
echo "   Command: qutebrowser"
echo ""
echo "2. Navigate to your Bitwarden vault and log in."
echo "   URL: https://vault.bitwarden.com"
echo ""
echo "3. Retrieve your MegaSync credentials from Bitwarden."
echo ""
echo "4. Launch the MegaSync client (from your desktop environment's application menu)."
echo "   Log in and configure it. **ALLOW IT TO SYNCHRONIZE ALL YOUR FILES.**"
echo "   This is crucial as subsequent scripts may rely on files in your Mega cloud storage"
echo "   (e.g., Anki backups, application data for 'install-user-apps.sh')."
echo ""
echo "5. Once MegaSync is FULLY SYNCED, open a terminal and ensure you are still in (or navigate back to)"
echo "   the '${SCRIPT_DIR}' directory (where this fedora-setup repository is cloned):"
echo "   Command: cd ${SCRIPT_DIR}"
echo ""
echo "6. Run the next phase of the installation from the '${SCRIPT_DIR}' directory:"
echo "   (Ensuring you are in '${SCRIPT_DIR}')"
echo "   Command: sudo ./scripts/install-system.sh"
echo "----------------------------------------------------------------------------------"

exit 0
