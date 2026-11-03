{ pkgs, ... }:
{
  home.packages = with pkgs; [
    eza
    jq
    tree
    dust
    gitleaks
    git-secrets
    git-wt
    go-task
    awscli2
    terraform
    herdr

    nixd
    nixfmt

    nodejs_26
    pnpm
    go_1_27
  ];
}
