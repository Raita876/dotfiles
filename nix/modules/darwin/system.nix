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

    # eMudhra の暫定対応 (macOS 側)。標準の curl / git / python3 などは /etc/ssl/cert.pem を失効確認なしで使うので、
    # そこからも同じルートを外す。macOS のアップデートで戻ったら次の switch でまた外す
    if grep -qE '^=== .*/CN=(AAA Certificate Services|emSign ECC Root CA - G3)$' /etc/ssl/cert.pem; then
      echo "removing eMudhra-affected roots from /etc/ssl/cert.pem..." >&2
      cp -p /etc/ssl/cert.pem /etc/ssl/cert.pem.bak
      awk '/^(###|===) /{skip=0}
        /^=== .*\/CN=(AAA Certificate Services|emSign ECC Root CA - G3)$/{skip=1}
        !skip' /etc/ssl/cert.pem.bak > /etc/ssl/cert.pem
    fi

    # 標準の pip3 は自前の古いルート証明書を使うので、上の /etc/ssl/cert.pem を見させる
    # (CommandLineTools が無いときに /usr/bin/python3 を呼ぶとインストールのダイアログが出るので確かめてから)
    if xcode-select -p >/dev/null 2>&1; then
      sitecustomize="$(/usr/bin/python3 -c 'import sysconfig; print(sysconfig.get_path("stdlib"))')/sitecustomize.py"
      if ! grep -qs PIP_CERT "$sitecustomize"; then
        echo 'import os; os.environ.setdefault("PIP_CERT", "/etc/ssl/cert.pem")' >> "$sitecustomize"
        chmod 644 "$sitecustomize"
      fi
    fi
  '';
}
