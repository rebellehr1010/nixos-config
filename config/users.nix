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
    };
  };
}
