{ config, ... }:
{
  homebrew.casks = [ "herdr-app" ];

  home-manager.users.${config.dotfiles.username} =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      disableTelemetry = pkgs.writeShellScript "herdr-disable-telemetry" ''
        set -euo pipefail
        export PATH=${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.jq
          ]
        }

        settings_file="$1"
        settings_dir="$(dirname "$settings_file")"
        mkdir -p "$settings_dir"
        temp_file="$(mktemp "$settings_dir/.settings.json.XXXXXX")"
        trap 'rm -f "$temp_file"' EXIT

        if [ -e "$settings_file" ]; then
          jq -e -s '
            if length == 1 and (.[0] | type) == "object" then
              .[0] + {telemetry: false}
            else
              error("Herdr settings.json must contain exactly one JSON object")
            end
          ' "$settings_file" > "$temp_file"
        else
          jq -n '{telemetry: false}' > "$temp_file"
        fi

        mv "$temp_file" "$settings_file"
      '';
    in
    {
      # セッションや UI の状態、配布済み mods は Herdr に管理させる
      xdg.configFile."herdr-app/keys.json".source = config.lib.dotfiles.link "herdr/keys.json";
      xdg.configFile."herdr-app/mods/pi-space".source = config.lib.dotfiles.link "herdr/mods/pi-space";

      # GUI で変更したほかの設定を残し、settings.json を書き込み可能なままにする
      home.activation.disableHerdrTelemetry = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${disableTelemetry} ${lib.escapeShellArg "${config.xdg.configHome}/herdr-app/settings.json"}
      '';
    };
}
