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

    # GUI アプリ (どの端末にも入れるもの。個人用は nix/hosts/ に書く)
    casks = [
      "ghostty"
      "google-chrome"
      "notion"
      "visual-studio-code"
      "cmux"
      "zoom"
    ];

    # VS Code の拡張機能 (`code --install-extension` で入れる)。更新は VS Code に任せる
    # cleanup = "uninstall" なので、宣言されていない拡張機能は switch で削除される。VS Code から追加したらここか端末側に書く
    # ここには共通の設定と対になるものだけを置き、それ以外は nix/hosts/ の端末ごとのファイルに書く
    vscode = [
      "anthropic.claude-code"
      "jnoortheen.nix-ide"
    ];
  };
}
