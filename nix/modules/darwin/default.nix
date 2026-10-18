{
  pkgs,
  hostname,
  username,
  homedir,
  ...
}:
{
  imports = [
    ./system.nix
    ./homebrew.nix
  ];

  nixpkgs.config.allowUnfree = true;

  nix = {
    # 既定の pkgs.nix (stable 系) はインストール済みの 2.35 より古いので、switch で Nix をダウングレードしないよう latest 系を使う
    package = pkgs.nixVersions.latest;

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

    # 毎週日曜 3:00 に、30 日より古い世代と参照されなくなったパッケージを削除する
    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 3;
        Minute = 0;
      };
      options = "--delete-older-than 30d";
    };
    # 同じ中身のファイルをハードリンクでまとめてディスクを節約する
    optimise.automatic = true;
  };

  networking = {
    hostName = hostname;
    localHostName = hostname;
    # Finder / AirDrop に表示される名前
    computerName = hostname;
  };

  # home-manager がホームディレクトリを知るために必要
  users.users.${username}.home = homedir;

  programs.zsh = {
    enable = true;
    # compinit は zsh/zshrc 側で呼ぶので、/etc/zshrc での二重実行を避ける
    enableGlobalCompInit = false;
  };

  # sudo を Touch ID で通す
  security.pam.services.sudo_local.touchIdAuth = true;

  system = {
    primaryUser = username;
    stateVersion = 6;
  };
}
