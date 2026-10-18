{ lib, config, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.dotfiles;
in
{
  # 端末ごとに変わる値。darwinModules.default を読み込む側 (職場用の flake など) で設定する
  options.dotfiles = {
    username = mkOption {
      type = types.str;
      description = "macOS のユーザー名";
    };

    hostname = mkOption {
      type = types.str;
      description = "ホスト名 (Finder / AirDrop に表示される名前にも使う)";
    };

    homedir = mkOption {
      type = types.str;
      default = "/Users/${cfg.username}";
      defaultText = lib.literalExpression ''"/Users/''${config.dotfiles.username}"'';
      description = "ホームディレクトリ";
    };

    dir = mkOption {
      type = types.str;
      default = "${cfg.homedir}/Repository/dotfiles";
      defaultText = lib.literalExpression ''"''${config.dotfiles.homedir}/Repository/dotfiles"'';
      description = "このリポジトリを clone した場所。zshrc などの symlink 先になる";
    };

    dock = {
      apps = mkOption {
        type = types.listOf types.str;
        default = [
          "/System/Applications/Apps.app"
          "/Applications/Google Chrome.app"
          "/System/Applications/System Settings.app"
          "/Applications/Discord.app"
          "/Applications/Notion.app"
          "/Applications/Visual Studio Code.app"
          "/Applications/cmux.app"
        ];
        description = "Dock に並べるアプリ (左から順に)。設定すると既定の並びを丸ごと置き換える";
      };

      others = mkOption {
        type = types.listOf types.str;
        default = [ "${cfg.homedir}/Downloads" ];
        defaultText = lib.literalExpression ''[ "''${config.dotfiles.homedir}/Downloads" ]'';
        description = "Dock の右側に置くフォルダ";
      };
    };
  };
}
