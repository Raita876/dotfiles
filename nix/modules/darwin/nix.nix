{
  pkgs,
  lib,
  config,
  ...
}:
{
  nixpkgs.config.allowUnfree = true;

  nix = {
    # 既定の pkgs.nix はインストール済みの Nix より古く、switch でダウングレードされるため
    package = lib.mkDefault pkgs.nixVersions.latest;

    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        config.dotfiles.username
      ];
    };

    gc = {
      automatic = lib.mkDefault true;
      interval = lib.mkDefault {
        Weekday = 0;
        Hour = 3;
        Minute = 0;
      };
      options = lib.mkDefault "--delete-older-than 30d";
    };
    optimise.automatic = true;
  };
}
