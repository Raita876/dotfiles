{
  pkgs,
  lib,
  config,
  ...
}:
let
  agents = {
    pi = "pi";
    claude = "claude";
    codex = "codex";
  };

  # cmux.json はリポジトリへの symlink で端末ごとに書き分けられないので、起動するエージェントはこのコマンドで切り替える
  cmuxAgent = pkgs.writeShellScriptBin "cmux-agent" ''
    # cmux が PATH に追加する連携用ラッパーを経由するため、絶対パスでは起動しない
    exec ${lib.escapeShellArg agents.${config.dotfiles.cmux.agent}} "$@"
  '';
in
{
  options.dotfiles.cmux.agent = lib.mkOption {
    type = lib.types.enum (builtins.attrNames agents);
    default = "pi";
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
