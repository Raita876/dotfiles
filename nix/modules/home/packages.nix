{ pkgs, ... }:
{
  home.packages = with pkgs; [
    eza
    jq
    tree
    gitleaks
    git-secrets
    go-task
    awscli2
    terraform
    herdr

    nixd
    nixfmt

    nodejs_24
    pnpm
    go_1_27
  ];
}
