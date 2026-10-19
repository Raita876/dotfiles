{ config, ... }:
{
  homebrew.casks = [ "cmux" ];

  home-manager.users.${config.dotfiles.username} =
    { config, ... }:
    {
      # 一時ファイルに書いてから置き換える保存方式でもリンクが切れないよう、ディレクトリごとリンクする
      xdg.configFile."cmux".source = config.lib.dotfiles.link "cmux";
    };
}
