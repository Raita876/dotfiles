{
  pkgs,
  lib,
  config,
  ...
}:
let
  agents = {
    claude = pkgs.claude-code;
    inherit (pkgs) codex;
  };

  # cmux.json はリポジトリへの symlink で端末ごとに書き分けられないので、起動するエージェントはこのコマンドで切り替える
  cmuxAgent = pkgs.writeShellScriptBin "cmux-agent" ''
    exec ${lib.getExe agents.${config.dotfiles.cmux.agent}} "$@"
  '';
in
{
  options.dotfiles.cmux.agent = lib.mkOption {
    type = lib.types.enum (builtins.attrNames agents);
    default = "claude";
    description = "cmux の新しいワークスペースで起動するコーディングエージェント";
  };

  config = {
    homebrew.casks = [ "cmux" ];

    home-manager.users.${config.dotfiles.username} =
      { config, ... }:
      {
        home.packages = [ cmuxAgent ];
        # 一時ファイルに書いてから置き換える保存方式でもリンクが切れないよう、ディレクトリごとリンクする
        xdg.configFile."cmux".source = config.lib.dotfiles.link "cmux";
      };
  };
}
