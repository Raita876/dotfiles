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
      "herdr-app"
      "google-chrome"
      "notion"
      "zoom"
    ];
  };
}
