{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # CLI
    eza
    starship
    gh
    jq
    tree
    gitleaks
    git-secrets
    go-task
    awscli2
    terraform
    claude-code

    # デフォルトの言語ランタイム (プロジェクトの devShell があればそちらが優先される)
    nodejs_24
    pnpm
    go_1_27
  ];
}
