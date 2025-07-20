# EndeavourOS Sway Setup Automation

This repository contains a set of scripts to perform a nearly-automated, clean installation of a personalized EndeavourOS environment running the Sway window manager.

## Philosophy and Improvements

This setup has been refined from a previous Fedora-based process with several key improvements in mind:

* **Simplicity:** The entire automated process is initiated by running a single master script. There is no need for manual intervention or bootstrapping separate applications to proceed.
* **Idempotency:** The scripts are designed to be re-runnable. If a step fails, you can often fix the issue and run the script again without breaking things that have already succeeded.
* **Separation of Concerns:**
  * **System Setup is Automated:** The scripts handle the complete setup of the operating system, including packages, drivers, tools, and dotfile configuration.
  * **Data Restoration is Manual:** Personal data (from MegaSync) is restored *after* the system setup is complete, ensuring the installation process does not depend on external files or cloud access.
* **Reliability:** The scripts now use modern, maintained packages and include troubleshooting steps for common issues like broken AUR packages and slow package mirrors.

***

## CRITICAL PRE-INSTALLATION CHECKS

**BEFORE YOU BEGIN, ENSURE THE FOLLOWING:**

1. **ALL YOUR GIT REPOSITORIES ARE PUSHED TO THEIR REMOTES:**
    * This "master setup" repository (`post-install`).
    * Your dotfiles bare repository (`git@github.com:imli700/dotfiles.git`).
    * Any other critical repositories you maintain.
    * **FAILURE TO DO THIS MAY RESULT IN DATA LOSS WHEN YOUR DOTFILES ARE CHECKED OUT!**

2. **You have a bootable EndeavourOS USB drive.**

***

## The Setup Process

### Step 1: Fresh EndeavourOS Installation

Start with a fresh installation of EndeavourOS. Follow these steps precisely in the graphical installer.

1. Boot your computer from the EndeavourOS USB drive.
2. Once the live desktop loads, the **"Welcome"** application will appear.
3. Click the **"Fetch your install customization file"** button.
4. When prompted for a URL, paste the following link for the Sway Community Edition setup:

    ```
    https://raw.githubusercontent.com/EndeavourOS-Community-Editions/sway/main/setup_sway_isomode.bash
    ```

5. Click **OK**.
6. In the Welcome app, click **"Start the Installer"** and choose the **Online** installation method.
7. Proceed through the initial screens (language, location, keyboard).
8. **Desktop Selection (Critical Step):** On the "Desktop to Install" screen, you **MUST** select the **"No Desktop"** option. The script you fetched will handle the Sway installation.
9. **Partitioning:** Choose **"Erase disk"** for the simplest setup, which will automatically partition your drive.
10. **User Creation:**
    * Enter your name and desired username.
    * Set the hostname for the computer to `codeMonkey`.
    * Choose a strong password.
11. **Review and Install:** Review the summary and click **Install**.
12. Once finished, **reboot** the system and remove the USB drive.

### Step 2: Post-Installation & First Login

After rebooting, you will be in your new EndeavourOS Sway environment.

1. Open a terminal. The default keybinding is `Alt + Enter`.

2. **Install Git:**

    ```bash
    sudo pacman -Syu --noconfirm git
    ```

### Step 3: Git & SSH Configuration

You must configure Git and set up SSH to communicate with GitHub.

1. **Configure Git Identity:**

    ```bash
    git config --global user.name "Your Name"
    git config --global user.email "yourname@example.com"
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    ```

2. **Generate a New SSH Key:**

    ```bash
    ssh-keygen -t ed25519 -C "your_email@example.com"
    ```

    Press **Enter** to accept the default file location and an optional passphrase.

3. **Start the SSH Agent and Add Your Key:**

    ```bash
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_ed25519
    ```

4. **Add the SSH Key to GitHub:**
    * Display your public key in the terminal:

        ```bash
        cat ~/.ssh/id_ed25519.pub
        ```

    * Highlight and copy the entire output.
    * Log into your GitHub account, go to **Settings > SSH and GPG keys**, and click **"New SSH key"**.
    * Give it a title (e.g., "EndeavourOS Laptop") and paste the key into the "Key" field. Click **"Add SSH key"**.

5. **Test the SSH Connection:**

    ```bash
    ssh -T git@github.com
    ```

    You should see a message confirming successful authentication.

### Step 4: Clone This Repository

Now you can securely clone your setup repository.

1. **Create a projects directory:**

    ```bash
    mkdir -p ~/programming
    ```

2. **Clone the `post-install` repository:**

    ```bash
    git clone git@github.com:imli700/post-install.git ~/programming/post-install
    ```

3. **Navigate to the scripts directory:**

    ```bash
    cd ~/programming/post-install/endeavouros
    ```

### Step 5: Execute the Master Script

This is the final automated step. The single command below will run the entire setup process.

1. **Make Scripts Executable:**

    ```bash
    chmod +x *.sh
    ```

2. **Run the Master Script with Logging:** Using `tee` is highly recommended. It will show the output in your terminal *and* save a complete copy to a log file. This is invaluable for debugging if anything goes wrong.

    ```bash
    sudo ./install-system.sh 2>&1 | tee install.log
    ```

The script will now run, automatically installing all packages, setting up user-level tools like `fnm` and `rustup`, and finally configuring your dotfiles. It will prompt you for your password and for confirmation on any steps that require user input (like the CPU mitigations tweak).

### Step 6: Final Reboot

After the script completes successfully, a final reboot is required to ensure all changes (like kernel arguments and system services) are applied correctly.

```bash
sudo reboot
```

Your system is now fully configured!

***

## Post-Setup: Manual Data Restoration

Your system is set up, but your personal documents and files are not yet present. This is done manually to keep the setup process clean.

1. Launch `qutebrowser` from the application launcher (`rofi`).
2. Navigate to your Bitwarden vault and log in to retrieve your MegaSync credentials.
3. Launch `megasync` from the application launcher.
4. Log in with your credentials and allow it to download and sync all of your files.

***

## Troubleshooting

### Network Errors / Slow Downloads (Updating Package Mirrors)

If `pacman` or `yay` fail with connection errors, your package mirrors may be out of date or slow. The `eos-rate-mirrors` tool may not always work as expected. A more robust manual method is to use `rate-mirrors`.

1. **Install `rate-mirrors`:**

    ```bash
    yay -S rate-mirrors
    ```

2. **Update Arch Linux Mirrors:** This command finds the fastest Arch mirrors and writes them to the correct configuration file.

    ```bash
    rate-mirrors --protocol https arch | sudo tee /etc/pacman.d/mirrorlist
    ```

3. **Update EndeavourOS Mirrors:** This does the same for the EndeavourOS-specific mirrors.

    ```bash
    rate-mirrors --protocol https endeavouros | sudo tee /etc/pacman.d/endeavouros-mirrorlist
    ```

4. **Force Refresh Databases:** After updating the mirrorlists, force `pacman` to synchronize with the new servers. Using `Syyu` (with two `y`'s) is appropriate here because the server lists have changed.

    ```bash
    sudo pacman -Syyu
    ```

### AUR Package Build Failures

Sometimes, a package from the Arch User Repository (AUR) will fail to build because it is unmaintained or incompatible with modern libraries (as we saw with `lxpolkit` and `wdisplays`). If this happens, read the error messages in the log file, check the comments on the package's AUR page, and look for a more modern, maintained alternative.

### Dotfile Conflicts

The `configure-dotfiles.sh` script automatically backs up any existing configuration files that would conflict with your dotfiles repository. These backups are stored in a timestamped directory in your home folder (e.g., `~/.config-backup-20250720-123000`). If something goes wrong, your original files are safe there.
