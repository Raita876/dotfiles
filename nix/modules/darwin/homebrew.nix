{
  homebrew = {
    enable = true;

    onActivation = {
      # 宣言していない formula / cask / tap を削除する。"zap" と違ってアプリの設定データは残す
      cleanup = "uninstall";
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
  };
}
