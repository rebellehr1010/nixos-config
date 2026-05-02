{
  description = "Anycubic Slicer Next flake for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    let
      supportedSystems = [ "x86_64-linux" ];

      overlay = final: prev: {
        anycubic-slicer-next = final.callPackage ./package.nix { };
      };
    in
    flake-utils.lib.eachSystem supportedSystems (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };

        package = pkgs.anycubic-slicer-next;
      in
      {
        packages.default = package;
        packages.anycubic-slicer-next = package;

        apps.default = {
          type = "app";
          program = "${package}/bin/AnycubicSlicerNext";
          meta = {
            description = package.meta.description;
          };
        };

        formatter = pkgs.nixfmt;
      }
    )
    // {
      overlays.default = overlay;

      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.programs.anycubicSlicer;
          defaultPackage = pkgs.callPackage ./package.nix { };
        in
        {
          options.programs.anycubicSlicer = {
            enable = lib.mkEnableOption "Anycubic Slicer Next";

            package = lib.mkOption {
              type = lib.types.package;
              default = defaultPackage;
              description = "Package to install for Anycubic Slicer Next.";
            };
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];
          };
        };
    };
}
