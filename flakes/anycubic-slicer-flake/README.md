# Anycubic Slicer Next Flake

This flake packages the community AppImage release from:

- https://github.com/thecalamityjoe87/anycubic-slicer-next-packages

It is simpler on NixOS than repacking the upstream Debian package because the
AppImage already carries the FHS-style runtime layout that the vendor binary
expects.

## Build

```bash
nix build .#anycubic-slicer-next
```

## Run

```bash
nix run
```

## Use in a NixOS flake

```nix
{
  inputs.anycubic-slicer.url = "path:/home/riley/Downloads/anycubic-slicer-flake";

  outputs = { self, nixpkgs, anycubic-slicer, ... }: {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        anycubic-slicer.nixosModules.default
        {
          programs.anycubicSlicer.enable = true;
        }
      ];
    };
  };
}
```

## Overlay usage

```nix
{
  nixpkgs.overlays = [ anycubic-slicer.overlays.default ];

  environment.systemPackages = [ pkgs.anycubic-slicer-next ];
}
```

## Updating

1. Update `version` in `package.nix`.
2. Replace the GitHub release hash.
3. Run `nix build .#anycubic-slicer-next` again.

You can fetch the new hash with:

```bash
curl -fsSL \
  https://github.com/thecalamityjoe87/anycubic-slicer-next-packages/releases/download/vVERSION/AnycubicSlicer-VERSION-x86_64.AppImage.sha256
```