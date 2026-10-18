{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (config.dotfiles) username hostname homedir;
in
{
  imports = [
    ./options.nix
    ./system.nix
    ./homebrew.nix
    ./home-manager.nix
  ];

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
        username
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

  networking = {
    hostName = lib.mkDefault hostname;
    localHostName = lib.mkDefault hostname;
    computerName = lib.mkDefault hostname;
  };

  users.users.${username}.home = homedir;

  programs.zsh = {
    enable = true;
    # compinit は zsh/zshrc 側で呼ぶので、/etc/zshrc での二重実行を避ける
    enableGlobalCompInit = false;
  };

  security.pam.services.sudo_local.touchIdAuth = lib.mkDefault true;

  system = {
    primaryUser = username;
    stateVersion = 6;
  };
}
