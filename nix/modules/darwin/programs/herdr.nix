{ config, pkgs, ... }:
{
  homebrew.casks = [ "herdr-app" ];

  home-manager.users.${config.dotfiles.username} =
    { config, lib, ... }:
    {
      home.packages = [ pkgs.terminal-notifier ];
      # Nix store 内の未登録アプリは macOS に通知の許可を要求できないため。
      home.activation.registerHerdrNotifier = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
          -f ${pkgs.terminal-notifier}/Applications/terminal-notifier.app
      '';
      launchd.agents.herdr-desktop-notifications = {
        enable = true;
        config = {
          ProgramArguments = [
            "${pkgs.python3}/bin/python3"
            "${config.dotfiles.dir}/herdr/desktop_notifications.py"
            "--notifier"
            "${pkgs.terminal-notifier}/bin/terminal-notifier"
            "--socket"
            "${config.xdg.configHome}/herdr-app/herdr-app.sock"
          ];
          RunAtLoad = true;
          KeepAlive = true;
          ThrottleInterval = 10;
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/herdr-desktop-notifications.log";
        };
      };
      # セッションや UI の状態、配布済み mods は Herdr に管理させる
      xdg.configFile."herdr-app/keys.json".source = config.lib.dotfiles.link "herdr/keys.json";
      xdg.configFile."herdr-app/mods/pi-space".source = config.lib.dotfiles.link "herdr/mods/pi-space";
      xdg.configFile."herdr-app/settings.json".text = builtins.toJSON {
        telemetry = false;
      };
    };
}
