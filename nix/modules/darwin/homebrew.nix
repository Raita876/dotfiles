{ lib, ... }:
{
  homebrew = {
    enable = true;

    onActivation = {
      # 宣言していない formula / cask / tap を削除する。"zap" と違ってアプリの設定データは残す
      # 職場の Mac など、管理外の brew パッケージがある端末では "none" に上書きする
      cleanup = lib.mkDefault "uninstall";
      # switch のたびに brew update しない
      autoUpdate = false;
      # 勝手にアップグレードしない (cask は各アプリの自動更新に任せる)
      upgrade = false;
    };

    # デーモン / サービス系は brew に残す
    brews = [
      "colima"
      "docker"
      "docker-buildx"
      "docker-compose"
    ];

    # GUI アプリ
    casks = [
      "ghostty"
      "google-chrome"
      "discord"
      "notion"
      "visual-studio-code"
      "cmux"
      "clipy"
      "google-japanese-ime"
      "zoom"
    ];

    # VS Code の拡張機能 (`code --install-extension` で入れる)。更新は VS Code に任せる
    # cleanup = "uninstall" なので、ここに無い拡張機能は switch で削除される。VS Code から追加したらここにも書く
    vscode = [
      "anthropic.claude-code"
      "bierner.markdown-mermaid"
      "bmewburn.vscode-intelephense-client"
      "dbaeumer.vscode-eslint"
      "docker.docker"
      "dsznajder.es7-react-js-snippets"
      "editorconfig.editorconfig"
      "esbenp.prettier-vscode"
      "formulahendry.auto-close-tag"
      "formulahendry.auto-rename-tag"
      "foxundermoon.shell-format"
      "golang.go"
      "hashicorp.terraform"
      "jnoortheen.nix-ide"
      "mechatroner.rainbow-csv"
      "ms-azuretools.vscode-containers"
      "ms-azuretools.vscode-docker"
      "ms-vscode-remote.remote-containers"
      "ms-vscode.makefile-tools"
      "redhat.vscode-yaml"
      "renesaarsoo.sql-formatter-vsc"
      "timonwong.shellcheck"
    ];
  };
}
