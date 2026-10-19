{ config, ... }:
let
  link = path: config.lib.file.mkOutOfStoreSymlink "${config.dotfiles.dir}/${path}";
in
{
  home.file = {
    ".zshrc".source = link "zsh/zshrc";
    ".zprofile".source = link "zsh/zprofile";
    ".config/starship.toml".source = link "starship/starship.toml";
    "Library/Application Support/Code/User/settings.json".source = link "vscode/settings.json";
  };

  # 一時ファイルに書いてから置き換える保存方式でもリンクが切れないよう、ディレクトリごとリンクする
  xdg.configFile = {
    "cmux".source = link "cmux";
  };
}
