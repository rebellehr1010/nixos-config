{ pkgs, ... }:
{
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
    groups = {
      libvirtd.members = [ "riley" ];
      kvm.members = [ "riley" ];
    };
    users.riley = {
      description = "riley";
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      isNormalUser = true;
      # packages = with pkgs; [ ];
      shell = pkgs.zsh;
      # Keys allowed to SSH in as riley (sshd is key-only).
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ2Za5kgvnr5Yv6dQdCidCCTQudwPJYM9JlqK4kSehHK riley@nixos" # nixos-desktop
      ];
    };
  };
}
