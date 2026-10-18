{ pkgs, ... }:
{
  home.packages = with pkgs; [
    eza
    starship
    jq
    tree
    gitleaks
    git-secrets
    go-task
    awscli2
    terraform

    nixd
    nixfmt

    nodejs_24
    pnpm
    go_1_27
  ];
}
