# nix run .#<name> で使う操作。どのディレクトリから実行してもこのリポジトリを対象にする
{
  pkgs,
  lib,
  darwinRebuild,
  dir,
  host,
}:
let
  target = "${dir}#${host}";
  systemAttr = "${dir}#darwinConfigurations.${host}.system";

  mkApp = name: description: text: {
    type = "app";
    program = lib.getExe (pkgs.writeShellApplication { inherit name text; });
    meta = { inherit description; };
  };
in
{
  switch = mkApp "switch" "設定をビルドして反映する" ''
    sudo ${lib.getExe darwinRebuild} switch --flake ${target} "$@"
  '';

  build = mkApp "build" "ビルドだけしてエラーを確認する (反映しない)" ''
    nix build --no-link ${systemAttr} "$@"
    echo "build ok: ${host}"
  '';

  update = mkApp "update" "flake.lock を更新してビルドを確認する (反映は switch で行う)" ''
    nix flake update --flake ${dir} "$@"
    nix build --no-link ${systemAttr}
    git -C ${dir} diff --stat -- flake.lock
  '';
}
