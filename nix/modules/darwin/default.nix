{
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
    ./nix.nix
    ./system.nix
    ./homebrew.nix
    ./home-manager.nix
    ./programs/vscode.nix
    ./programs/cmux.nix
    ./programs/herdr.nix
  ];

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
