#!/bin/bash

# --- Standard Error Handling ---
set -e
trap 'echo "An error occurred in $(basename "$0") at line $LINENO. Exiting..." >&2; exit 1' ERR

################################################################################
# USER APPLICATION INSTALLATION SCRIPT (PHASE 3)                               #
#------------------------------------------------------------------------------#
# PURPOSE:                                                                     #
# - Install user-specific applications (Anki, drivers, FNM/Node).              #
# - This script is run AS THE REGULAR USER.                                    #
# - Relies on MegaSync having synced necessary backup files.                   #
# - Call the next script (configure-dotfiles.sh).                              #
#                                                                              #
# PRE-REQUISITES:                                                              #
# - Run after install-system.sh.                                               #
# - MegaSync has synced user files.                                            #
# - SCRIPT_REPO_ROOT environment variable should be set by parent script,      #
#   pointing to the root of the 'fedora-setup' git repository (e.g. ~/programming/fedora-setup).#
################################################################################

# --- Configuration Variables ---
# $HOME is automatically correct.
# SCRIPT_REPO_ROOT is passed from install-system.sh
if [ -z "$SCRIPT_REPO_ROOT" ]; then
  echo "Error: SCRIPT_REPO_ROOT environment variable not set. This script must be called by install-system.sh." >&2
  exit 1
fi
# CURRENT_SCRIPT_DIR is the directory this script is in (e.g., ~/programming/fedora-setup/scripts)
CURRENT_SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Paths for user-specific data, likely synced via MegaSync
# MEGASYNC_BASE_DIR="$HOME/MEGA" # This is where MEGA typically stores its root.
# Based on your tree output, specific backup files are directly in $HOME/Documents/backups
USER_DOCS_BACKUPS_DIR="$HOME/Documents/backups"
USER_APPS_BACKUPS_DIR="$USER_DOCS_BACKUPS_DIR/applications-with-uninstall-and-readmes"

# Local directories
DST_DIR_TEMP="$HOME/Downloads" # Temporary download/extraction location
LOCAL_SHARE_DIR="$HOME/.local/share"
FNM_DIR="$HOME/.local/share/fnm"

# --- Helper Functions ---
error_exit() {
  echo "Error: $1" >&2
  exit 1
}

echo "--- Phase 3: User Application Setup Initiated (running as $(whoami)) ---"
echo "Repository root (SCRIPT_REPO_ROOT): $SCRIPT_REPO_ROOT"
echo "Current script directory (CURRENT_SCRIPT_DIR): $CURRENT_SCRIPT_DIR"
echo "Expecting user backup data from MegaSync in paths like: $USER_DOCS_BACKUPS_DIR"

mkdir -p "$DST_DIR_TEMP"
mkdir -p "$LOCAL_SHARE_DIR"

if [ ! -d "$USER_DOCS_BACKUPS_DIR" ]; then
  echo "Warning: User documents backup directory '$USER_DOCS_BACKUPS_DIR' (expected for backups like Anki) not found. Some setups might fail."
fi
if [ ! -d "$USER_APPS_BACKUPS_DIR" ]; then
  echo "Warning: User application backup directory '$USER_APPS_BACKUPS_DIR' not found. Some setups might fail."
fi

# --- Anki Setup ---
setup_anki() {
  echo "--- Setting up Anki ---"
  if [ ! -d "$USER_DOCS_BACKUPS_DIR" ] || [ ! -d "$USER_APPS_BACKUPS_DIR" ]; then
    echo "Skipping Anki setup: Backup directories not found (USER_DOCS_BACKUPS_DIR: '$USER_DOCS_BACKUPS_DIR' or USER_APPS_BACKUPS_DIR: '$USER_APPS_BACKUPS_DIR')."
    return
  fi

  local anki_data_archive="Anki2.7z"
  local anki_data_path_src="${USER_DOCS_BACKUPS_DIR}/${anki_data_archive}"
  # anki_data_path_dst is where we copy the archive temporarily for extraction
  local anki_data_path_dst_temp="${DST_DIR_TEMP}/${anki_data_archive}"
  local extracted_data_dir_name="Anki2" # This is the name of the directory *inside* the Anki2.7z archive
  local extracted_data_path_full_temp="${DST_DIR_TEMP}/${extracted_data_dir_name}"

  echo "Searching for Anki application archive in ${USER_APPS_BACKUPS_DIR}..."
  # Use -ipath for case-insensitive matching if needed, or adjust name pattern
  local anki_app_archive_path=$(find "${USER_APPS_BACKUPS_DIR}/" -maxdepth 1 -name 'anki*.7z' -print -quit)

  if [ -z "$anki_app_archive_path" ]; then
    echo "Warning: Could not find Anki application archive (anki*.7z) in ${USER_APPS_BACKUPS_DIR}. Skipping Anki app install."
  else
    local anki_app_archive_name=$(basename "$anki_app_archive_path")
    local anki_app_path_dst_temp="${DST_DIR_TEMP}/${anki_app_archive_name}"
    # Assuming archive "anki-VERSION.7z" extracts to a folder "anki-VERSION"
    local extracted_app_dir_name=$(basename "$anki_app_archive_name" .7z)
    local extracted_app_dir_path_full_temp="${DST_DIR_TEMP}/${extracted_app_dir_name}"

    if ! command -v 7zz &>/dev/null && ! command -v 7z &>/dev/null; then
      echo "Error: Neither 7zz nor 7z command not found (p7zip). It should have been installed. Skipping Anki." >&2
      return
    fi
    local seven_zip_cmd=$(command -v 7zz || command -v 7z)

    echo "Copying Anki application archive '$anki_app_archive_name' to $DST_DIR_TEMP..."
    cp "$anki_app_archive_path" "$anki_app_path_dst_temp"
    echo "Extracting Anki application ($anki_app_archive_name) to $DST_DIR_TEMP..."
    "$seven_zip_cmd" x -y -o"$DST_DIR_TEMP/" "$anki_app_path_dst_temp"
    if [ ! -d "$extracted_app_dir_path_full_temp" ]; then
      echo "Error: Expected Anki application directory '$extracted_app_dir_path_full_temp' not found after extraction. Skipping Anki app install." >&2
    else
      echo "Changing permissions and running install script for Anki application from $extracted_app_dir_path_full_temp..."
      chmod -R +x "$extracted_app_dir_path_full_temp"
      local anki_install_script="$extracted_app_dir_path_full_temp/install.sh"
      if [ -f "$anki_install_script" ]; then
        echo "Executing Anki install script: $anki_install_script (requires sudo)"
        # Anki's install.sh typically installs to /usr/local/share and /usr/local/bin
        (cd "$extracted_app_dir_path_full_temp" && sudo ./install.sh) || echo "Warning: Anki install.sh script encountered an error."
      else
        echo "Warning: install.sh not found in $extracted_app_dir_path_full_temp. Skipping Anki app install step. Anki might need manual installation from extracted files."
      fi
    fi
    # Cleanup temporary files
    rm -f "$anki_app_path_dst_temp"
    [ -d "$extracted_app_dir_path_full_temp" ] && rm -rf "$extracted_app_dir_path_full_temp"
  fi

  if [ ! -f "$anki_data_path_src" ]; then
    echo "Warning: Anki data archive '$anki_data_archive' not found at '$anki_data_path_src'. Skipping Anki data restore."
  else
    if ! command -v 7zz &>/dev/null && ! command -v 7z &>/dev/null; then
      echo "Error: Neither 7zz nor 7z command not found (p7zip). It should have been installed. Skipping Anki data restore." >&2
      return
    fi
    local seven_zip_cmd=$(command -v 7zz || command -v 7z)

    cp "$anki_data_path_src" "$anki_data_path_dst_temp"
    echo "Extracting Anki data ($anki_data_archive) to $DST_DIR_TEMP..."
    "$seven_zip_cmd" x -y -o"$DST_DIR_TEMP/" "$anki_data_path_dst_temp"

    if [ ! -d "$extracted_data_path_full_temp" ]; then
      echo "Error: Expected Anki data directory '$extracted_data_path_full_temp' not found after extraction. Skipping data restore." >&2
    else
      # Anki data for current versions is typically stored in $HOME/.local/share/Anki2
      # Or for older versions, $HOME/Anki2. The archive is named Anki2.7z, suggesting the latter.
      # The extracted folder is named "Anki2".
      # The script currently moves it to $LOCAL_SHARE_DIR/${extracted_data_dir_name} which is $HOME/.local/share/Anki2
      # This is correct for newer Anki versions. If it's an older Anki version expecting data in $HOME/Anki2, this might need adjustment.
      # Given the name of the archive `Anki2.7z` and extracted dir `Anki2`, it's possible it's for $HOME/Anki2 directly.
      # However, $HOME/.local/share/Anki2 is the modern standard.
      # For now, let's stick to $HOME/.local/share/Anki2.
      echo "Moving extracted Anki data from '$extracted_data_path_full_temp' to '$LOCAL_SHARE_DIR/$extracted_data_dir_name'..."
      # Ensure target directory for data exists or is clean
      if [ -d "$LOCAL_SHARE_DIR/$extracted_data_dir_name" ]; then
        echo "Removing existing Anki data directory: $LOCAL_SHARE_DIR/$extracted_data_dir_name"
        rm -rf "$LOCAL_SHARE_DIR/$extracted_data_dir_name"
      fi
      mkdir -p "$(dirname "$LOCAL_SHARE_DIR/$extracted_data_dir_name")" # Ensure parent .local/share exists
      mv "$extracted_data_path_full_temp" "$LOCAL_SHARE_DIR/"           # This moves DST_DIR_TEMP/Anki2 to LOCAL_SHARE_DIR/Anki2
      echo "Anki data moved to $LOCAL_SHARE_DIR/$extracted_data_dir_name."
    fi
    # Cleanup temporary files
    rm -f "$anki_data_path_dst_temp"
    # The extracted_data_path_full_temp itself is removed by the mv command if successful
    # but if mv fails or dir didn't exist, this cleans up.
    [ -d "$extracted_data_path_full_temp" ] && rm -rf "$extracted_data_path_full_temp"
  fi
  echo "--- Anki Setup Finished (check warnings above) ---"
}

install_vktablet_driver() {
  echo "--- Installing Drivers (vktablet) ---"
  if [ ! -d "$USER_APPS_BACKUPS_DIR" ]; then
    echo "Skipping vktablet driver: USER_APPS_BACKUPS_DIR ('$USER_APPS_BACKUPS_DIR') not found."
    return
  fi

  echo "Searching for vktablet RPM in ${USER_APPS_BACKUPS_DIR}..."
  local vktablet_rpm_path=$(find "${USER_APPS_BACKUPS_DIR}/" -maxdepth 1 -name 'vktablet*.rpm' -print -quit)

  if [ -z "$vktablet_rpm_path" ]; then
    echo "Warning: vktablet RPM not found in ${USER_APPS_BACKUPS_DIR}. Skipping installation."
    return
  fi

  echo "Found vktablet RPM: $vktablet_rpm_path"
  echo "Installing vktablet (requires sudo)..."
  # RPM installation is a system-wide change, so sudo is appropriate.
  sudo dnf install -y "$vktablet_rpm_path" || echo "Warning: Failed to install vktablet RPM. DNF output should be above. Continuing."
  echo "--- Driver Installation Finished ---"
}

install_fnm_node_and_globals() {
  echo "--- Installing fnm, Node.js, and Global NPM Packages ---"

  # FNM_DIR is $HOME/.local/share/fnm
  # fnm executable will be $FNM_DIR/fnm
  mkdir -p "$FNM_DIR" # Ensure the parent directory for fnm exists

  if command -v fnm &>/dev/null && [ -x "$FNM_DIR/fnm" ]; then
    echo "fnm appears to be already installed in $FNM_DIR and accessible in PATH."
    # Check if fnm is indeed from FNM_DIR
    local fnm_path=$(command -v fnm)
    if [[ "$fnm_path" != "$FNM_DIR/fnm"* ]]; then
      echo "Warning: 'fnm' command found at '$fnm_path', but expected at '$FNM_DIR/fnm'. This might cause issues if multiple fnm versions are present."
    fi
  else
    echo "Installing fnm (Fast Node Manager)..."
    if ! command -v curl &>/dev/null; then
      echo "Error: curl is not installed. Cannot install fnm." >&2
      return
    fi
    # Install fnm to FNM_DIR, skip modifying shell config files directly
    # The --install-dir will place fnm binary inside $FNM_DIR
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$FNM_DIR" --skip-shell
    if ! [ -x "$FNM_DIR/fnm" ]; then
      echo "Error: fnm installation appears to have failed (binary not found at $FNM_DIR/fnm)." >&2
      echo "Please check the output of the curl command above."
      return
    fi
    echo "fnm installed to $FNM_DIR."
    echo "IMPORTANT: For fnm to work in new terminal sessions, you must:"
    echo "           1. Add '$FNM_DIR' to your PATH in your shell configuration (e.g., ~/.bashrc, ~/.zshrc)."
    echo "              Example: export PATH=\"\$HOME/.local/share/fnm:\$PATH\""
    echo "           2. Add the fnm env loader to your shell configuration."
    echo "              Example: eval \"\$(\$HOME/.local/share/fnm/fnm env --use-on-cd)\""
    echo "           These changes will be effective after you source your shell config or open a new terminal."
  fi

  # Temporarily add fnm to PATH and setup its environment for the current script session
  if [ -x "$FNM_DIR/fnm" ]; then
    export PATH="$FNM_DIR:$PATH"
    # The following line might print to stdout, which could be confusing.
    # Capture output or ensure it's not problematic for script flow.
    eval "$($FNM_DIR/fnm env --shell bash --use-on-cd)" # Specify shell, use bash for consistent behavior in script
  else
    echo "Error: fnm binary not found at $FNM_DIR/fnm. Cannot proceed with Node.js installation." >&2
    return
  fi

  if ! command -v fnm &>/dev/null; then
    echo "Error: fnm command not found even after attempting to modify PATH and source env. Check installation." >&2
    return
  fi

  echo "Installing latest LTS Node.js version using fnm..."
  fnm install --lts
  fnm default lts-latest # Set default Node.js version for fnm

  echo "Verifying Node.js and npm installation..."
  # Use 'fnm exec' to ensure we are using the fnm-managed node/npm
  if ! fnm exec -- node -v || ! fnm exec -- npm -v; then
    echo "Error: Node.js or npm not found after fnm install. Check fnm setup and output above." >&2
    echo "Make sure fnm is correctly configured and a Node version is installed and set as default."
    return
  fi
  echo "Node version: $(fnm exec -- node -v)"
  echo "npm version: $(fnm exec -- npm -v)"

  echo "Installing global npm packages (using fnm exec)..."
  local npm_globals_failed=false
  fnm exec -- npm install -g live-server || {
    echo "Warning: Failed to install live-server globally." >&2
    npm_globals_failed=true
  }
  fnm exec -- npm install -g neovim || {
    echo "Warning: Failed to install neovim npm package globally." >&2
    npm_globals_failed=true
  }
  fnm exec -- npm install -g @mermaid-js/mermaid-cli || {
    echo "Warning: Failed to install @mermaid-js/mermaid-cli globally." >&2
    npm_globals_failed=true
  }

  if $npm_globals_failed; then
    echo "One or more global npm packages failed to install (see warnings above)."
  else
    echo "Global npm packages installed successfully (or attempted)."
  fi
  echo "--- FNM/Node/NPM Setup Finished ---"
}

# --- Main Execution for User Apps ---
setup_anki
install_vktablet_driver
install_fnm_node_and_globals

# --- Call Next Script ---
echo ""
echo "--- Phase 3: User Application Setup Complete ---"
echo "Proceeding to Phase 4: Dotfiles Configuration..."

# configure-dotfiles.sh is located in SCRIPT_REPO_ROOT/scripts/
next_script_dotfiles="${SCRIPT_REPO_ROOT}/scripts/configure-dotfiles.sh"
if [ -f "$next_script_dotfiles" ] && [ -x "$next_script_dotfiles" ]; then
  # Pass SCRIPT_REPO_ROOT in case configure-dotfiles.sh needs it (currently it doesn't seem to)
  env SCRIPT_REPO_ROOT="$SCRIPT_REPO_ROOT" "$next_script_dotfiles" # Run as current user
else
  error_exit "$next_script_dotfiles not found or not executable in ${SCRIPT_REPO_ROOT}/scripts/. Cannot proceed."
fi

echo "install-user-apps.sh finished successfully."
exit 0
