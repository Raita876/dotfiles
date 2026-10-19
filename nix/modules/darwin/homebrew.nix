{ lib, ... }:
{
  homebrew = {
    enable = true;

    onActivation = {
      cleanup = lib.mkDefault "uninstall";
      autoUpdate = lib.mkDefault false;
      upgrade = lib.mkDefault false;
    };

    brews = [
      "colima"
      "docker"
      "docker-buildx"
      "docker-compose"
    ];

    casks = [
      "ghostty"
      "google-chrome"
      "notion"
      "visual-studio-code"
      "cmux"
      "zoom"
    ];

    # 宣言されていない拡張機能は switch で削除される
    vscode = lib.importJSON ../../../vscode/extensions.json;
  };
}
