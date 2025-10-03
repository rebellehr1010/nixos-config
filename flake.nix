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
      nixosConfigurations.nixos-framework = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./config/boot.nix
          ./config/configuration.nix
          ./config/hosts/nixos-framework/hardware-configuration.nix
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
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.riley = import ./home.nix;
          }
        ];
      };
    };
}
