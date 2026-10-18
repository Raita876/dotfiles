{
  imports = [
    ./packages.nix
    ./git.nix
    ./direnv.nix
    ./dotfiles.nix
  ];

  home.stateVersion = "26.11";

  programs.home-manager.enable = true;
}
