# /etc/nixos/flake.nix
{
  description = "imli700's NixOS configuration for codeMonkey";

  inputs = {
    # Nix Packages collection
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }: {
    nixosConfigurations.codeMonkey = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit home-manager; }; # Pass home-manager to the configuration
      modules = [
        # The main system configuration
        ./configuration.nix

        # Make Home Manager available as a NixOS module
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.imli700 = import ./home.nix;
        }
      ];
    };
  };
}
