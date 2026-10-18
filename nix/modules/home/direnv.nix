{
  # zshrc は programs.zsh ではなく symlink で管理しているため、
  # シェルへのフックは zsh/zshrc の `eval "$(direnv hook zsh)"` で行う
  programs.direnv = {
    enable = true;
    # devShell をキャッシュし、cd のたびに再評価しない
    nix-direnv.enable = true;
  };
}
