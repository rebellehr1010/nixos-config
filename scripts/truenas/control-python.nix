let
  flake = builtins.getFlake (toString ../..);
  pkgs = import flake.inputs.nixpkgs { system = builtins.currentSystem; };
in
pkgs.python3.withPackages (ps: [ ps.tinytuya ps.tuya-device-sharing-sdk ps.qrcode ps.pillow ])
