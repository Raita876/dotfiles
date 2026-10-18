{
  # zshrc は programs.zsh で管理していないので、フックは zsh/zshrc に書いている
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
