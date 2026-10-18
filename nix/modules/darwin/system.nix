{
  pkgs,
  lib,
  username,
  homedir,
  ...
}:
let
  dockApps = [
    "/System/Applications/Apps.app"
    "/Applications/Google Chrome.app"
    "/System/Applications/System Settings.app"
    "/Applications/Discord.app"
    "/Applications/Notion.app"
    "/Applications/Visual Studio Code.app"
    "/Applications/cmux.app"
  ];
  dockOthers = [ "${homedir}/Downloads" ];

  # Dock の並びを作り直して再起動するスクリプト。並びが変わるとスクリプトのパスも変わる
  setDock = pkgs.writeShellScript "set-dock" ''
    dockutil=${lib.getExe pkgs.dockutil}
    $dockutil --remove all --no-restart
    ${lib.concatMapStrings (app: "$dockutil --add ${lib.escapeShellArg app} --no-restart\n") dockApps}
    ${lib.concatMapStrings (
      dir:
      "$dockutil --add ${lib.escapeShellArg dir} --view auto --display stack --sort name --no-restart\n"
    ) dockOthers}
    killall Dock || true
  '';
  dockStamp = "${homedir}/.local/state/nix-darwin/dock";
in
{
  # 2026-10-15 時点でこの Mac の初期値から変更されていた設定 (defaults read で確認)
  system.defaults = {
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
