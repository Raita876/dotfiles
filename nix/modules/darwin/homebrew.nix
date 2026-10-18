{
  homebrew = {
    enable = true;

    onActivation = {
      # 初回適用は "none" で行い、Nix 版の動作確認後に "uninstall" へ切り替える (docs/plan.md「適用手順」)
      # "uninstall": 宣言していない formula / cask をアンインストールする
      cleanup = "none";
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
