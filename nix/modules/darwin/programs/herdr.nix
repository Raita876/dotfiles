{ config, ... }:
{
  homebrew.casks = [ "herdr-app" ];

  home-manager.users.${config.dotfiles.username} =
    { config, ... }:
    {
      # セッションや UI の状態は Herdr に管理させ、キー設定だけを共有する
      xdg.configFile."herdr-app/keys.json".source = config.lib.dotfiles.link "herdr/keys.json";
    };
}
