{ config, pkgs, ... }:
{
  # sops-nix: secrets are stored encrypted in git and decrypted at activation
  # into $XDG_RUNTIME_DIR/secrets.d (never the Nix store).
  #
  # Decrypt with the user's existing SSH key (converted to age).
  # Recipients for encryption live in /etc/nixos/.sops.yaml.
  sops.age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];

  # Once secrets/secrets.yaml exists (`sops secrets/secrets.yaml`), set:
  #   sops.defaultSopsFile = ../../secrets/secrets.yaml;
  #   sops.secrets.<name> = { };   # -> config.sops.secrets.<name>.path

  # Lets the `sops` CLI (editing secrets/*.yaml) use the same SSH-derived age key.
  home.sessionVariables.SOPS_AGE_KEY_CMD = "ssh-to-age -private-key -i ${config.home.homeDirectory}/.ssh/id_ed25519";

  home.packages = with pkgs; [
    sops
    age
    ssh-to-age
  ];
}
