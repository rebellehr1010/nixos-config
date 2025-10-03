{ pkgs, lib, ... }:
let
  # Helper to define a plugin. Use lib.fakeSha256 first; build will print the real hash.
  gh =
    {
      owner,
      repo,
      rev ? "master",
      file ? null,
    }:
    {
      name = repo;
      src = pkgs.fetchFromGitHub {
        inherit owner repo rev;
        sha256 = lib.fakeSha256; # replace with real hash after first build failure
      };
      inherit file;
    }
    // (if file == null then { } else { inherit file; });
in
{
  # List consumed directly by programs.zsh.plugins
  plugin_list = [
    (gh {
      owner = "zsh-users";
      repo = "zsh-autosuggestions";
    })
    (gh {
      owner = "zsh-users";
      repo = "zsh-completions";
    })
    (gh {
      owner = "zsh-users";
      repo = "zsh-syntax-highlighting";
    })
    (gh {
      owner = "zsh-users";
      repo = "zsh-history-substring-search";
    })
    (gh {
      owner = "romkatv";
      repo = "powerlevel10k";
      file = "powerlevel10k.zsh-theme";
    })
    (gh {
      owner = "spwhitt";
      repo = "nix-zsh-completions";
    })
    (gh {
      owner = "popstas";
      repo = "zsh-command-time";
    })
    (gh {
      owner = "Aloxaf";
      repo = "fzf-tab";
    })
    (gh {
      owner = "unixorn";
      repo = "fzf-zsh-plugin";
    })
    (gh {
      owner = "MichaelAquilina";
      repo = "zsh-you-should-use";
    })
    (gh {
      owner = "fdellwing";
      repo = "zsh-bat";
    })
  ];
}
