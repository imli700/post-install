# /etc/nixos/home.nix
{ pkgs, ... }:

{
  # --- Dotfiles Management ---
  # Home Manager will fetch the specified git repository and place its contents
  # into your home directory. This is the declarative equivalent of your
  # bare repo checkout script. It will overwrite existing files.
  # CRITICAL: You must have a working SSH key for GitHub before building!
  home.file.".".source = pkgs.fetchFromGitHub {
    owner = "imli700";
    repo = "dotfiles";
    rev = "main";
    # IMPORTANT: Since your repo is private, Nix needs to be told to trust
    # the hash. After the first build fails due to a hash mismatch, Nix will
    # print the correct hash. Copy and paste it here.
    hash = "sha256-YOUR_HASH_HERE"; # e.g., "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
  };

  # --- User-Specific Packages (replaces install-user-apps.sh) ---
  home.packages = with pkgs; [
    # Anki (the official binary version is often most reliable)
    anki-bin

    # Node.js via Nix (replaces FNM)
    # This installs the latest LTS version of Node.js available in Nixpkgs 23.11
    nodejs_20

    # Your global npm packages, installed declaratively
    nodePackages.live-server
    nodePackages.neovim
    nodePackages."@mermaid-js/mermaid-cli"
  ];

  # --- Git Configuration ---
  programs.git = {
    enable = true;
    # TODO: Replace with your actual name and email
    userName = "imli700";
    userEmail = "imlijangba@gmail.com";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = false;
    };
  };

  # --- Home Manager State ---
  # This must be set. It's okay to use the same version as the system.
  home.stateVersion = "23.11";
}
