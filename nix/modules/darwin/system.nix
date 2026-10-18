{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (config.dotfiles) username homedir;

  # Dock の並びを作り直して再起動するスクリプト。並びが変わるとスクリプトのパスも変わる
  setDock = pkgs.writeShellScript "set-dock" ''
    dockutil=${lib.getExe pkgs.dockutil}
    $dockutil --remove all --no-restart
    ${lib.concatMapStrings (
      app: "$dockutil --add ${lib.escapeShellArg app} --no-restart\n"
    ) config.dotfiles.dock.apps}
    ${lib.concatMapStrings (
      dir:
      "$dockutil --add ${lib.escapeShellArg dir} --view auto --display stack --sort name --no-restart\n"
    ) config.dotfiles.dock.others}
    killall Dock || true
  '';
  dockStamp = "${homedir}/.local/state/nix-darwin/dock";
in
{
  # 2026-10-15 時点でこの Mac の初期値から変更されていた設定 (defaults read で確認)
  # 端末ごとに上書きできるよう、すべての値を mkDefault にする
  system.defaults = lib.mapAttrsRecursive (_: lib.mkDefault) {
    NSGlobalDomain = {
      # ダークモード
      AppleInterfaceStyle = "Dark";
      # ナチュラルスクロール オフ
      "com.apple.swipescrolldirection" = false;
    };

    # Finder をリスト表示
    finder.FXPreferredViewStyle = "Nlsv";

    trackpad = {
      # タップでクリック
      Clicking = true;
      # 2 本指クリックでの右クリックはオフにして、右下隅のクリックで右クリック
      TrackpadRightClick = false;
      TrackpadCornerSecondaryClick = 2;
    };
  };

  # system.defaults.dock を使うと、設定が変わっていなくても switch のたびに Dock が再起動される。
  # 全画面のアプリの上に Dock が出たまま引っ込まなくなるので、並びが変わったときだけ作り直す
  system.activationScripts.postActivation.text = ''
    if [ "$(cat ${dockStamp} 2>/dev/null)" != "${setDock}" ]; then
      echo "updating Dock..." >&2
      launchctl asuser "$(id -u -- ${username})" sudo --user=${username} -- sh -c \
        'mkdir -p "$(dirname ${dockStamp})" && ${setDock} && echo ${setDock} > ${dockStamp}'
    fi
  '';
}
