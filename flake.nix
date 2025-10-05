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
    pia = {
      url = "github:Fuwn/pia.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      pia,
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
            home-manager.nixosModules.home-manager
            pia.nixosModules."x86_64-linux".default
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.riley = import ./home.nix;
            }
          ];
          mkHost =
            host: hardwarePath:
            nixpkgs.lib.nixosSystem {
              inherit system;
              specialArgs = { inherit inputs; };
              modules = baseModules ++ [
                hardwarePath
                (./config/hosts + "/" + host + "/host.nix")
              ];
            };
        in
        {
          nixos-framework = mkHost "nixos-framework" ./config/hosts/nixos-framework/hardware-configuration.nix;
          nixos-desktop = mkHost "nixos-desktop" ./config/hosts/nixos-desktop/hardware-configuration.nix;
        };
    };
}
