{ ... }:
{
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.riley = {
    isNormalUser = true;
    description = "riley";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    # packages = with pkgs; [ ];
  };
}
