{
  pkgs,
  lib,
  config,
  dotfilesDir,
  ...
}:
let
  claudeConfigDir = "${config.home.homeDirectory}/.claude";
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/${path}";

  jq = lib.getExe pkgs.jq;
  checkJsonschema = lib.getExe pkgs.check-jsonschema;
  jsonFormat = pkgs.formats.json { };

  settings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    permissions.defaultMode = "auto";
    skipDangerousModePermissionPrompt = true;
    theme = "dark";
  };
  settingsFile = jsonFormat.generate "claude-settings.json" settings;

  # agents/skills/ 以下のディレクトリを 1 つずつリンクする (~/.claude/skills/synced は claude.ai の同期用なので触らない)
  skillNames = builtins.attrNames (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir ../../../../agents/skills)
  );
in
{
  home.packages = [ pkgs.claude-code ];

  # コピーではなくマージする: Claude Code は /config や /permissions でこのファイルを自分で書き換えるため、
  # 丸ごと置き換えるとその内容が switch のたびに消える。上の settings のキーが優先され、それ以外は残る
  home.activation.writeClaudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
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

  home.activation.validateClaudeSettings = lib.hm.dag.entryAfter [ "writeClaudeSettings" ] ''
    SETTINGS_FILE="${claudeConfigDir}/settings.json"
    SCHEMA_URL=$(${jq} -r '.["$schema"]' "$SETTINGS_FILE")

    echo "Validating Claude Code settings.json..."
    if ${checkJsonschema} --schemafile "$SCHEMA_URL" "$SETTINGS_FILE" 2>&1; then
      echo "Claude Code settings.json validation passed"
    else
      echo "Claude Code settings.json validation failed (non-blocking, schema may be outdated)" >&2
    fi
  '';

  home.file = {
    # ユーザー全体の指示は CLAUDE.md という名前でしか読まれないので、共通の AGENTS.md をこの名前でリンクする
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
