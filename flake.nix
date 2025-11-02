{
  description = "NixOS System Configuration";

  inputs = {
    # If you want to use the latest upstream version, I recommend using
    # branch "nixos-unstable" instead of "23.11" (the latest stable release).
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-software-center.url = "github:snowfallorg/nix-software-center";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    {
      nixosConfigurations =
        let
          system = "x86_64-linux";
          baseModules = [
            ./config/boot.nix
            ./config/configuration.nix
            ./config/hardware.nix
            ./config/internationalisation.nix
            ./config/networking.nix
            ./config/security.nix
            ./config/services.nix
            ./config/system-packages.nix
            ./config/systemd.nix
            ./config/time.nix
            ./config/users.nix
            ./config/virtualisation.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.riley = import ./home.nix;
            }
          ];
          # Attrset of hosts -> directory (each directory contains hardware-configuration.nix & host.nix)
          hostDirs = {
            nixos-framework = ./config/hosts/nixos-framework;
            nixos-desktop = ./config/hosts/nixos-desktop;
          };
          # Build a NixOS system for each host, avoiding fragile path concatenation.
          mkHost =
            host: dir:
            nixpkgs.lib.nixosSystem {
              inherit system;
              specialArgs = { inherit inputs; };
              modules = baseModules ++ [
                (builtins.toPath "${dir}/hardware-configuration.nix")
                (builtins.toPath "${dir}/host.nix")
              ];
            };
        in
        nixpkgs.lib.mapAttrs mkHost hostDirs;
    };
}
