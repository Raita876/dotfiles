{
  pkgs,
  lib,
  config,
  ...
}:
let
  claudeConfigDir = "${config.home.homeDirectory}/.claude";
  link = path: config.lib.file.mkOutOfStoreSymlink "${config.dotfiles.dir}/${path}";

  jq = lib.getExe pkgs.jq;
  checkJsonschema = lib.getExe pkgs.check-jsonschema;
  jsonFormat = pkgs.formats.json { };

  settingsFile = jsonFormat.generate "claude-settings.json" config.dotfiles.claudeCode.settings;

  # ~/.claude/skills/synced は claude.ai の同期用なので触らない
  skillNames = builtins.attrNames (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir ../../../../agents/skills)
  );
in
{
  options.dotfiles.claudeCode.settings = lib.mkOption {
    inherit (jsonFormat) type;
    default = { };
    description = "~/.claude/settings.json に switch のたびに書き込む設定。ここに無いキーは Claude Code が書いた値のまま残る";
  };

  config.dotfiles.claudeCode.settings = lib.mapAttrsRecursive (_: lib.mkDefault) {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    permissions.defaultMode = "auto";
    skipDangerousModePermissionPrompt = true;
    theme = "dark";
  };

  config.home.packages = [ pkgs.claude-code ];

  # Claude Code 自身もこのファイルを書き換えるので、置き換えずにマージする
  config.home.activation.writeClaudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    SETTINGS_FILE="${claudeConfigDir}/settings.json"
    mkdir -p "${claudeConfigDir}"

    if [ -f "$SETTINGS_FILE" ]; then
      TEMP_FILE="$(mktemp "${claudeConfigDir}/.settings.json.XXXXXX")"
      if ! ${jq} -s '.[0] * .[1]' "$SETTINGS_FILE" ${settingsFile} > "$TEMP_FILE"; then
        rm -f "$TEMP_FILE"
        exit 1
      fi
      mv "$TEMP_FILE" "$SETTINGS_FILE"
    else
      cp --no-preserve=mode,ownership ${settingsFile} "$SETTINGS_FILE"
    fi
    chmod 644 "$SETTINGS_FILE"
  '';

  config.home.activation.validateClaudeSettings = lib.hm.dag.entryAfter [ "writeClaudeSettings" ] ''
    SETTINGS_FILE="${claudeConfigDir}/settings.json"
    SCHEMA_URL=$(${jq} -r '.["$schema"]' "$SETTINGS_FILE")

    echo "Validating Claude Code settings.json..."
    if ${checkJsonschema} --schemafile "$SCHEMA_URL" "$SETTINGS_FILE" 2>&1; then
      echo "Claude Code settings.json validation passed"
    else
      echo "Claude Code settings.json validation failed (non-blocking, schema may be outdated)" >&2
    fi
  '';

  config.home.file = {
    ".claude/CLAUDE.md".source = link "agents/AGENTS.md";
    ".claude/shared".source = link "agents/shared";
    ".claude/commands".source = link "claude/commands";
    ".claude/agents".source = link "claude/agents";
    ".claude/output-styles".source = link "claude/output-styles";
  }
  // lib.listToAttrs (
    map (
      name: lib.nameValuePair ".claude/skills/${name}" { source = link "agents/skills/${name}"; }
    ) skillNames
  );
}
