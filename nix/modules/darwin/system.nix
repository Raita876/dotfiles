{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (config.dotfiles) username homedir;

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
  system.defaults = lib.mapAttrsRecursive (_: lib.mkDefault) {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      "com.apple.swipescrolldirection" = false;
    };

    finder.FXPreferredViewStyle = "Nlsv";

    trackpad = {
      Clicking = true;
      TrackpadRightClick = false;
      TrackpadCornerSecondaryClick = 2;
    };
  };

  # system.defaults.dock は switch のたびに Dock を再起動し、全画面アプリの上に Dock が出たままになるため、
  # 並びが変わったときだけ作り直す
  system.activationScripts.postActivation.text = ''
    if [ "$(cat ${dockStamp} 2>/dev/null)" != "${setDock}" ]; then
      echo "updating Dock..." >&2
      launchctl asuser "$(id -u -- ${username})" sudo --user=${username} -- sh -c \
        'mkdir -p "$(dirname ${dockStamp})" && ${setDock} && echo ${setDock} > ${dockStamp}'
    fi
  '';
}
