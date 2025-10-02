{ pkgs, inputs, ... }:
{
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment = {
    systemPackages = with pkgs; [
      inputs.nix-software-center.packages."${pkgs.system}".nix-software-center
      git
      wget
      gedit
      micro
      brave
      vscode
      htop
      nixfmt
      os-prober
      efibootmgr
    ];
    variables.EDITOR = "micro";
  };

  programs = {
    firefox.enable = true;
    git = {
      enable = true;
      config = {
        init = {
          defaultBranch = "main";
        };
        user.name = "rebellehr1010";
        user.email = "riley.lehr@connectsource.com.au";
      };
    };
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
      localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    };
  };
}
