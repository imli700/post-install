# /etc/nixos/configuration.nix
{ config, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan from the installer.
    # IMPORTANT: Make sure this file exists from your initial installation!
    ./hardware-configuration.nix
  ];

  # By gemini
  hardware.enableRedistributableFirmware = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # --- Bootloader (systemd-boot is recommended for UEFI) ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # --- Performance / Security Tweak ---
  # WARNING: Disables CPU mitigations for performance at the cost of security.
  # This makes your system vulnerable to Spectre/Meltdown attacks.
  boot.kernelParams = [ "mitigations=off" ];

  # --- Networking ---
  networking.hostName = "codeMonkey";
  # NetworkManager is a user-friendly way to manage network connections.
  networking.networkmanager.enable = true;
  # Disable the service that waits for networking to be online at boot, as it can slow down startup.
  systemd.services.NetworkManager-wait-online.service.enable = false;

  # --- Time, Locale, and Console ---
  time.timeZone = "Asia/Kolkata"; # TODO: Set your timezone
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # --- User Accounts ---
  users.users.imli700 = {
    isNormalUser = true;
    description = "imli700";
    # Add user to the 'wheel' group for sudo access and 'networkmanager' to manage connections.
    extraGroups = [ "wheel" "networkmanager" "videa" "input" ];
  };

  # By gemini
  services.xserver.displayManager.gdm.enable = true;

  # --- Graphical Environment (Sway) ---
  programs.sway = {
    enable = true;
    # Allows Sway to manage wrapper scripts for packages.
    wrapperFeatures.gtk = true;
  };
  # Enable PipeWire for audio. It's the modern standard.
  sound.enable = true;
  services.pulseaudio.enable = false; # Disable pulseaudio in favor of pipewire
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Enable Bluetooth support
  hardware.bluetooth.enable = true;
  services.blueman.enable = true; # A graphical bluetooth manager

  # --- Hardware Acceleration (for your AMD Integrated GPU) ---
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      libva-utils # For va-info utility
      amdvlk
      rocmPackages.clr
    ];
  };

  # --- Allow Unfree Packages ---
  # This is required for packages like megasync.
  nixpkgs.config.allowUnfree = true;

  # --- System-Wide Packages ---
  # This list is derived from your `install-system.sh` script.
  environment.systemPackages = with pkgs; [
    # Core Utilities
    git
    wget
    curl
    acpi
    brightnessctl
    duf
    fd # Replaces fd-find
    fzf
    p7zip
    rename # Replaces 'prename'
    ripgrep
    unrar
    unzip
    wl-clipboard # Wayland clipboard tool, often better than xclip in sway
    xclip

    # Development
    clang
    (lua5_1.withPackages (ps: [ ps.luarocks ])) # Lua 5.1 with luarocks

    # Wayland/Sway Ecosystem
    grim # Screenshots
    slurp # Screen selection
    mako # Notification daemon
    rofi-wayland
    swappy # Screenshot editing
    wdisplays
    wf-recorder
    wl-mirror
    wshowkeys
    lxqt.lxqt-policykit # PolicyKit agent for GUIs needing root

    # Applications
    android-tools
    flatpak
    calibre
    dictd
    flatpak
    hunspellDicts.en_US # US English dictionary
    libreoffice

    # Multimedia & Codecs
    vlc
    mpv
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav
    gst_all_1.gst-vaapi
    libva # VA-API library (pulled in by hardware.vaapi.enable)
    zathura
    xournalpp
    libnotify # For sending desktop notifications from scripts

    # Fonts
    noto-fonts
    noto-fonts-cjk-sans

    noto-fonts-emoji
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    corefonts

    # Proprietary Apps
    megasync
  ];

  # --- Services ---
  services.xserver.enable = true; # Even for Wayland, this helps with XWayland support
  # Enable printing support
  services.printing.enable = true;

  # --- System State ---
  # This value determines the Nixpkgs release from which the default
  # settings for stateful data, like file locations and database versions,
  # are taken. It's perfectly fine and recommended to leave this value
  # matching the release of Nixpkgs you're using.
  system.stateVersion = "25.05";
}
