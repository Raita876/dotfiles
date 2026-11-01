{ config, ... }:
{
  homebrew.casks = [ "herdr-app" ];

  home-manager.users.${config.dotfiles.username} =
    { config, ... }:
    {
      # セッションや UI の状態、配布済み mods は Herdr に管理させる
      xdg.configFile."herdr-app/keys.json".source = config.lib.dotfiles.link "herdr/keys.json";
      xdg.configFile."herdr-app/mods/pi-space".source = config.lib.dotfiles.link "herdr/mods/pi-space";
    };
}
