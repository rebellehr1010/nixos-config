{ ... }:
{
  networking.hostName = "nixos-hp-envy";

  # This laptop has 8 GB RAM. Avoid many memory-heavy compilers competing;
  # other hosts retain their existing concurrency settings.
  nix.settings = {
    max-jobs = 2;
    cores = 4;
  };
}
