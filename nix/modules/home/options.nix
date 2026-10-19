{ lib, config, ... }:
{
  options.dotfiles.dir = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/Repository/dotfiles";
    defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/Repository/dotfiles"'';
    description = "このリポジトリを clone した場所。zshrc などの symlink 先になる";
  };

  # リポジトリ内のファイルへの symlink を作る (編集が即反映され、switch 不要)
  config.lib.dotfiles.link =
    path: config.lib.file.mkOutOfStoreSymlink "${config.dotfiles.dir}/${path}";
}
