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
    # Zsh plugin sources as flake inputs (non-flake) so we don't need manual sha256 prefetch.
    zsh-autosuggestions-src.url = "github:zsh-users/zsh-autosuggestions";
    zsh-autosuggestions-src.flake = false;
    zsh-completions-src.url = "github:zsh-users/zsh-completions";
    zsh-completions-src.flake = false;
    zsh-syntax-highlighting-src.url = "github:zsh-users/zsh-syntax-highlighting";
    zsh-syntax-highlighting-src.flake = false;
    zsh-history-substring-search-src.url = "github:zsh-users/zsh-history-substring-search";
    zsh-history-substring-search-src.flake = false;
    powerlevel10k-src.url = "github:romkatv/powerlevel10k";
    powerlevel10k-src.flake = false;
    nix-zsh-completions-src.url = "github:spwhitt/nix-zsh-completions";
    nix-zsh-completions-src.flake = false;
    zsh-command-time-src.url = "github:popstas/zsh-command-time";
    zsh-command-time-src.flake = false;
    fzf-tab-src.url = "github:Aloxaf/fzf-tab";
    fzf-tab-src.flake = false;
    fzf-zsh-plugin-src.url = "github:unixorn/fzf-zsh-plugin";
    fzf-zsh-plugin-src.flake = false;
    you-should-use-src.url = "github:MichaelAquilina/zsh-you-should-use";
    you-should-use-src.flake = false;
    zsh-bat-src.url = "github:fdellwing/zsh-bat";
    zsh-bat-src.flake = false;
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    {
      nixosConfigurations = {
        nixos-framework = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./config/boot.nix
            ./config/configuration.nix
            ./config/hosts/nixos-framework/hardware-configuration.nix
            ./config/hosts/nixos-framework/host.nix
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
        nixos-desktop = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./config/boot.nix
            ./config/configuration.nix
            ./config/hosts/nixos-desktop/hardware-configuration.nix
            ./config/hosts/nixos-desktop/host.nix
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
    };
}
