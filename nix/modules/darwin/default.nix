{
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

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      username
    ];
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
