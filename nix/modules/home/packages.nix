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

    # Nix の言語サーバーとフォーマッタ (VS Code の nix-ide から使う)
    nixd
    nixfmt

    # デフォルトの言語ランタイム (プロジェクトの devShell があればそちらが優先される)
    nodejs_24
    pnpm
    go_1_27
  ];
}
