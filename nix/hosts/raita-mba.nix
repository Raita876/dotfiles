{ lib, ... }:
{
  dotfiles = {
    username = "raita";
    hostname = "raita-mba";
  };

  homebrew = {
    casks = [
      "discord"
      "clipy"
      "google-japanese-ime"
    ];

    vscode = lib.importJSON ../../vscode/extensions.raita-mba.json;
  };
}
