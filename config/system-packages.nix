{ pkgs, inputs, ... }:
{
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment = {
    systemPackages = with pkgs; [
      inputs.nix-software-center.packages."${pkgs.system}".nix-software-center
      
    ];
    variables.EDITOR = "micro";
  };

  programs = {
  };
}
