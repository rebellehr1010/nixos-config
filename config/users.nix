{ pkgs, ... }:
{
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
    users.riley = {
      isNormalUser = true;
      description = "riley";
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      shell = pkgs.zsh;
      # packages = with pkgs; [ ];
    };
  };
}
