{ config, ... }:
{
  home.file = {
    ".zshrc".source = config.lib.dotfiles.link "zsh/zshrc";
    ".zprofile".source = config.lib.dotfiles.link "zsh/zprofile";
  };
}
