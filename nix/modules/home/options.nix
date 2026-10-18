{ lib, config, ... }:
{
  options.dotfiles.dir = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/Repository/dotfiles";
    defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/Repository/dotfiles"'';
    description = "このリポジトリを clone した場所。zshrc などの symlink 先になる";
  };
}
