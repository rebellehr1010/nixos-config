# Anycubic Slicer Next Flake

Packages Anycubic's official **2.0.06** Debian release for **x86_64 Linux**.
The vendor names this archive `AnycubicSlicerNext_linux-v2.0.0.5-20260913065625.deb`;
`2.0.06` is its version in both the Debian package and package index. The
executable reports `AnycubicSlicerNext-2.0.0.5` in its help output.

The download is pinned by URL and SHA-256. Nix extracts the package without running
its installer scripts. A `buildFHSEnv` wrapper provides the `/usr` resource paths
and shared libraries the application expects, plus its GStreamer plugins.
Nothing is installed into the host's `/usr`.

The [Debian repack investigation](https://github.com/betoldster/anycubicslicernext-deb-repack)
helped identify the runtime requirements. Its Debian dependency metadata fixes
aren't needed here because Nix supplies the dependencies directly.

## Validation

Tested on x86_64 NixOS on 2026-10-04: `nix flake check` and a build from a
standalone copy of this directory, desktop entry validation, command-line help,
and STL import/export. With an isolated home directory and Xvfb, the main window
and setup wizard rendered and the process stayed running for 60 seconds. The
launcher also handles a fresh home without an existing `.config` directory.

Printer-specific slicing/G-code, hardware-accelerated 3D rendering, cloud login,
printer discovery, camera playback, and non-NixOS hosts still need manual testing.

## Build and run locally

Run these commands from this directory:

```sh
nix flake check
nix build .#anycubic-slicer-next
nix run .
```

Both `AnycubicSlicerNext` and `anycubic-slicer-next` launch the application. Installing
it also provides a desktop entry and icon.

Nix must have `nix-command` and `flakes` enabled. The package needs a graphical
session, working graphics drivers, and permission to create the user namespaces
used by bubblewrap. NixOS is the primary test platform; other Linux distributions
with Nix need their own graphics/namespace testing. macOS and ARM are unsupported.

## Install from a public repository

Publish this directory as the root of a repository, replacing `OWNER/REPO` below
with its actual GitHub location. No Nixpkgs submission or binary cache is required.

```sh
# Try it without installing:
nix run github:OWNER/REPO

# Install into your user profile:
nix profile install github:OWNER/REPO#anycubic-slicer-next
```

`nix profile install` also works as the older spelling of `nix profile add` on
recent Nix. For reproducible deployment, use a release tag or commit in the URL,
for example `github:OWNER/REPO/v2.0.06#anycubic-slicer-next` after creating that tag.

## Use in a NixOS flake

Add the input and module to your existing configuration:

```nix
{
  inputs.anycubic-slicer.url = "github:OWNER/REPO";

  outputs = { nixpkgs, anycubic-slicer, ... }: {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        anycubic-slicer.nixosModules.default
        {
          programs.anycubicSlicer = {
            enable = true;
            # Use the dependency versions tested by the standalone flake.
            package = anycubic-slicer.packages.x86_64-linux.default;
          };
        }
      ];
    };
  };
}
```

Omit `programs.anycubicSlicer.package` to build using the host's Nixpkgs instead.
You can also set `inputs.anycubic-slicer.inputs.nixpkgs.follows = "nixpkgs"` to share
the host's pin; test the runtime after changing dependency versions.

For Home Manager, add the package directly:

```nix
home.packages = [ anycubic-slicer.packages.x86_64-linux.default ];
```

An overlay is also available:

```nix
{
  nixpkgs.overlays = [ anycubic-slicer.overlays.default ];
  environment.systemPackages = [ pkgs.anycubic-slicer-next ];
}
```

## Publishing

Copy `flake.nix`, `flake.lock`, `package.nix`, and this README into a separate
repository. Include a license for your packaging code and replace the placeholder
GitHub URLs. Keep the lockfile committed. The upstream payload includes an AGPLv3
license, preserved by this package; a license for this repository's Nix expressions
does not replace upstream's licenses. The repository only needs the packaging
files, not the downloaded `.deb`, build results, or personal NixOS configuration.

Before tagging a release:

1. Run `nix flake check` in a clean checkout.
2. Run `nix run .` on a graphical NixOS machine.
3. Confirm the workbench renders, import an STL, slice it, and export G-code.
4. Test printer discovery, cloud login, and camera playback if you use those features.
5. Test a non-NixOS distribution before claiming support for it.

## Updating

Inspect the vendor's package index for the version, filename, and checksum:

```sh
curl -fsSL https://cdn-universe-slicer.anycubic.com/prod/dists/noble/main/binary-amd64/Packages
nix store prefetch-file --json 'https://cdn-universe-slicer.anycubic.com/prod/FILENAME_FROM_INDEX'
```

Update `version`, `src.url`, and `src.hash` in `package.nix`. Compare the download
hash with the index, inspect any changed runtime dependencies, then build and
repeat the graphical checks. Evaluation never queries the index for a moving
"latest" version. If the vendor removes a pinned archive, new builds will need a
new available source and matching hash.

Update the standalone dependency pin with `nix flake update nixpkgs`, then repeat
the checks. This is separate from updating the slicer itself.
