{ lib, config, ... }:
let
  categories = [
    "brews"
    "casks"
    "vscode"
  ];
  excluded = config.dotfiles.homebrew.exclude;
in
{
  options = {
    dotfiles.homebrew.exclude = lib.genAttrs categories (
      category:
      lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Homebrew の ${category} から除外する名前。外部モジュールで追加した項目にも適用される";
      }
    );

    homebrew = lib.genAttrs categories (
      category:
      lib.mkOption {
        apply = builtins.filter (
          entry: !(builtins.elem (if builtins.isString entry then entry else entry.name) excluded.${category})
        );
      }
    );
  };

  config.homebrew = {
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
      "zoom"
    ];
  };
}
