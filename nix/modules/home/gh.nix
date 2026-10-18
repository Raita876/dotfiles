{ lib, ... }:
{
  # Nix 版 git は CommandLineTools の gitconfig (credential.helper=osxkeychain) を読まないため
  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
    settings.git_protocol = lib.mkDefault "https";
  };
}
