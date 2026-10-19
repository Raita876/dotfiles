{ pkgs, config, ... }:
{
  home.packages = [ pkgs.starship ];

  xdg.configFile."starship.toml".source = config.lib.dotfiles.link "starship/starship.toml";
}
