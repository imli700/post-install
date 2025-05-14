# Fedora Setup Automation

This repository contains scripts to automate the setup of a new Fedora installation, tailored for use with qutebrowser and KeePassXC (AppImage). All scripts required for the setup are located within this repository.

## CRITICAL PRE-INSTALLATION CHECKS

**BEFORE RUNNING ANY SCRIPTS, ENSURE THE FOLLOWING:**

1. **ALL YOUR GIT REPOSITORIES ARE PUSHED TO THEIR REMOTES:**
    * This "master setup" repository (`~/programming/fedora-setup` after cloning).
    * Your dotfiles bare repository (e.g., `git@github.com:yourusername/dotfiles.git` - check `scripts/configure-dotfiles.sh` for the exact URL used).
    * Your Neovim configuration repository (if it's separate from your main dotfiles).
    * Any other critical repositories you maintain.
    * **FAILURE TO DO THIS MAY RESULT IN DATA LOSS WHEN THE SCRIPTS MANAGE DOTFILES OR IF YOU REINSTALL!**

2. **ASSETS DIRECTORY (`./assets/`):**
    * The KeePassXC AppImage **must** be present in the `assets/` directory of this repository and named `KeePassXC.AppImage`. Download the latest version and place it there.
    * Your KeePassXC database file (`MyPasswords.kdbx`) **must** be present in the `assets/` directory.
    * **Commit these files (`KeePassXC.AppImage`, `MyPasswords.kdbx`) to this repository.**

3. **MegaSync Version (`bootstrap.sh`):**
    * Open `bootstrap.sh` and verify/update the `MEGASYNC_FEDORA_VERSION` variable to match the target Fedora release (e.g., "42", "43").

## Setup Steps

1. **Fresh Fedora Installation:** Start with a new Fedora installation.

2. **Initial Git Setup (Manual):**
    * Open a terminal and install Git:

        ```bash
        sudo dnf install -y git
        ```

    * **Configure Git (Adapted from The Odin Project - Step 2.2):**
        For Git to work properly, we need to let it know who we are so that it can link a local Git user (you) to GitHub.
        The commands below will configure Git. Be sure to enter your own information inside the quotes (but include the quotation marks!). If you chose to keep your email private on GitHub, use your special private GitHub email.

        ```bash
        git config --global user.name "Your Name"
        git config --global user.email yourname@example.com
        ```

        For example, if you set your email as private on GitHub, the second command will look something like this:

        ```bash
        # git config --global user.email 123456789+imli700@users.noreply.github.com # Remember to use your own private GitHub email here.
        ```

        GitHub recently changed the default branch on new repositories from `master` to `main`. Change the default branch for Git using this command:

        ```bash
        git config --global init.defaultBranch main
        ```

        You’ll also likely want to set your default branch reconciliation behavior to merging:

        ```bash
        git config --global pull.rebase false
        ```

        To verify that things are working properly, enter these commands and verify whether the output matches your name and email address.

        ```bash
        git config --get user.name
        git config --get user.email
        ```

3. **Create and Link GitHub SSH Key (Manual - Adapted from The Odin Project - Steps 2.3 & 2.4):**
    An SSH key is a cryptographically secure identifier used by GitHub to allow you to upload to your repository without having to type in your username and password every time.

    * **Check for Existing SSH Key (Odin Project - Step 2.3):**
        First, we need to see if you have an Ed25519 algorithm SSH key already installed. Type this into the terminal:

        ```bash
        ls ~/.ssh/id_ed25519.pub
        ```

        If a message appears in the console containing the text “No such file or directory”, then you do not yet have an Ed25519 SSH key, and you will need to create one. If no such message has appeared, you can proceed to linking your key with GitHub.

    * **Create a New SSH Key (if needed):**
        Run the following command inside your terminal.

        ```bash
        ssh-keygen -t ed25519 -C "your_email@example.com"
        ```

        When it prompts you for a location to save the generated key, just press Enter.
        Next, it will ask you for a passphrase. This passphrase encrypts the private SSH key. Enter one if you wish (recommended), or press Enter to skip (not recommended).

    * **Start the ssh-agent and Add Your Key:**
        Ensure the ssh-agent is running:

        ```bash
        eval "$(ssh-agent -s)"
        ```

        Add your SSH private key to the ssh-agent (if you used a different key name, adjust accordingly):

        ```bash
        ssh-add ~/.ssh/id_ed25519
        ```

    * **Link Your SSH Key with GitHub (Odin Project - Step 2.4):**
        You need to tell GitHub what your SSH key is.
        Log into GitHub and click on your profile picture in the top right corner. Then, click on **Settings** in the drop-down menu.
        Next, on the left-hand side, click **SSH and GPG keys**. Then, click the green button in the top right corner that says **New SSH key**.
        Name your key something descriptive (e.g., "Fedora Laptop"). Leave this browser window open.

        Now, copy your public SSH key. To do this, use `cat` to display the key:

        ```bash
        cat ~/.ssh/id_ed25519.pub
        ```

        Highlight and copy the entire output. It will likely begin with `ssh-ed25519` and end with your email.
        *(Alternatively, to copy directly to clipboard if `xclip` is installed:)*

        ```bash
        # sudo dnf install -y xclip # Install xclip if you don't have it
        # xclip -selection clipboard < ~/.ssh/id_ed25519.pub
        # echo "Public key copied to clipboard."
        ```

        Go back to GitHub in your browser, paste the copied key into the "Key" field. Keep the "Key type" as "Authentication Key" and then, click **Add SSH key**.

    * **Test SSH Connection:**
        Test your SSH connection to GitHub:

        ```bash
        ssh -T git@github.com
        ```

        You should see a message like: "Hi yourusername! You've successfully authenticated..."

4. **Clone This Repository (`fedora-setup`):**
    Use the SSH URL for your `fedora-setup` repository.

    ```bash
    # Example: git clone git@github.com:imli700/fedora-setup.git ~/programming/fedora-setup
    git clone git@github.com:<your_username>/<fedora-setup_repo_name>.git ~/programming/fedora-setup
    ```

    (Replace `<your_username>/<fedora-setup_repo_name>` with your actual GitHub username and repository name for `fedora-setup`)

5. **Navigate to the Repository:**

    ```bash
    cd ~/programming/fedora-setup
    ```

6. **Run Bootstrap Script:**

    ```bash
    sudo ./bootstrap.sh
    ```

7. **Follow Manual Prompts from `bootstrap.sh`:**
    * This will involve opening KeePassXC (now available), retrieving your MegaSync credentials, and configuring the MegaSync client.
    * **Allow MegaSync to fully synchronize ALL your files.** This is crucial as subsequent scripts might depend on files synced by Mega (e.g., Anki backups, other application data). The scripts expect certain backed-up files to be present in `~/Documents/backups/` (which should be synced by Mega).

8. **Run System Installation Script (from `~/programming/fedora-setup`):**
    * **Ensure MegaSync has finished syncing.**
    * Still in the `~/programming/fedora-setup` directory, run:

        ```bash
        sudo ./scripts/install-system.sh
        ```

    * This script will, in turn, execute `scripts/install-user-apps.sh` and `scripts/configure-dotfiles.sh` (also from the `~/programming/fedora-setup/scripts/` directory) as your regular user.

9. **Reboot:** After all scripts complete, reboot your system.
