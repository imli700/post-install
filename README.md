# Fedora Setup Automation

This repository contains scripts to automate the setup of a new Fedora installation, tailored for use with qutebrowser and KeePassXC (AppImage).

## CRITICAL PRE-INSTALLATION CHECKS!

**BEFORE RUNNING ANY SCRIPTS, ENSURE THE FOLLOWING:**

1.  **ALL YOUR GIT REPOSITORIES ARE PUSHED TO THEIR REMOTES:**
    *   This "master setup" repository (`~/fedora-setup` after cloning).
    *   Your dotfiles bare repository (e.g., `git@github.com:yourusername/dotfiles.git` - check `configure-dotfiles.sh` for the exact URL used).
    *   Your Neovim configuration repository (if it's separate from your main dotfiles).
    *   Any other critical repositories you maintain.
    *   **FAILURE TO DO THIS MAY RESULT IN DATA LOSS WHEN THE SCRIPTS MANAGE DOTFILES OR IF YOU REINSTALL!**

2.  **ASSETS DIRECTORY (`./assets/`):**
    *   The KeePassXC AppImage **must** be present in the `assets/` directory of this repository and named `KeePassXC.AppImage`. Download the latest version and place it there.
    *   Your KeePassXC database file **must** be present in the `assets/` directory and named `MyPasswords.kdbx`.
    *   **Commit these files to this repository.**

3.  **MegaSync Version (`bootstrap.sh`):**
    *   Open `bootstrap.sh` and verify/update the `MEGASYNC_FEDORA_VERSION` variable to match the target Fedora release (e.g., "42", "43").

## Setup Steps:

1.  **Fresh Fedora Installation:** Start with a new Fedora installation.
2.  **Install Git (Manual):** Open a terminal and run:
    ```bash
    sudo dnf install -y git
    ```
3.  **Clone This Repository:**
    ```bash
    git clone <your_git_repo_url_for_this_setup_repo> ~/fedora-setup
    ```
    (Replace `<your_git_repo_url_for_this_setup_repo>` with the actual URL)
4.  **Navigate to the Repository:**
    ```bash
    cd ~/fedora-setup
    ```
5.  **Run Bootstrap Script:**
    ```bash
    sudo ./bootstrap.sh
    ```
6.  **Follow Manual Prompts from `bootstrap.sh`:**
    *   This will involve opening KeePassXC, retrieving your MegaSync credentials, and configuring the MegaSync client.
    *   Allow MegaSync to fully synchronize your files. Your main setup scripts (like `install-system.sh`) will be downloaded to your MegaSync cloud directory.
7.  **Run System Installation Script:**
    *   Navigate to the directory within your MegaSync folder where the scripts have been synced (e.g., `~/MEGA/Linux_Setup/` - adjust path if different).
    *   Run:
        ```bash
        sudo ./install-system.sh
        ```
    *   This script will, in turn, execute `install-user-apps.sh` and `configure-dotfiles.sh` as your regular user.

8.  **Reboot:** After all scripts complete, reboot your system.
