{
  pkgs,
  lib,
  config,
  ...
}:
let
  claudeConfigDir = "${config.home.homeDirectory}/.claude";
  inherit (config.lib.dotfiles) link agentSkillNames;
  cfg = config.dotfiles.claudeCode;

  claude = lib.getExe pkgs.claude-code;
  jq = lib.getExe pkgs.jq;
  checkJsonschema = lib.getExe pkgs.check-jsonschema;
  jsonFormat = pkgs.formats.json { };

  settingsFile = jsonFormat.generate "claude-settings.json" config.dotfiles.claudeCode.settings;
in
{
  options.dotfiles.claudeCode.settings = lib.mkOption {
    inherit (jsonFormat) type;
    default = { };
    description = "~/.claude/settings.json に switch のたびに書き込む設定。ここに無いキーは Claude Code が書いた値のまま残る";
  };

  options.dotfiles.claudeCode.marketplaces = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = "プラグインの取得元。マーケットプレイス名 → GitHub リポジトリ (owner/repo)";
  };

  options.dotfiles.claudeCode.plugins = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "<プラグイン名>@<マーケットプレイス名> の一覧。switch 時に入っていなければインストールする";
  };

  options.dotfiles.claudeCode.extraSkills = lib.mkOption {
    type = lib.types.attrsOf lib.types.path;
    default = { };
    description = "~/.claude/skills/<名前> に追加で置くスキル (名前 → ディレクトリ)。読み込む側のリポジトリのスキルを足すのに使う";
  };

  config.dotfiles.claudeCode.marketplaces.claude-plugins-official =
    lib.mkDefault "anthropics/claude-plugins-official";

  config.dotfiles.claudeCode.plugins = [
    "claude-security@claude-plugins-official"
    "pr-review-toolkit@claude-plugins-official"
  ];

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

  # ネットワークに繋がらないときも switch は止めない (次の switch で再試行される)
  config.home.activation.installClaudePlugins = lib.hm.dag.entryAfter [ "writeClaudeSettings" ] (
    lib.concatStrings (
      lib.mapAttrsToList (name: repo: ''
        if ! ${jq} -e --arg m ${lib.escapeShellArg name} 'has($m)' "${claudeConfigDir}/plugins/known_marketplaces.json" >/dev/null 2>&1; then
          run ${claude} plugin marketplace add ${lib.escapeShellArg repo} || echo "Claude Code marketplace ${name} could not be added" >&2
        fi
      '') cfg.marketplaces
    )
    + lib.concatMapStrings (plugin: ''
      if ! ${jq} -e --arg p ${lib.escapeShellArg plugin} '.plugins | has($p)' "${claudeConfigDir}/plugins/installed_plugins.json" >/dev/null 2>&1; then
        run ${claude} plugin install ${lib.escapeShellArg plugin} || echo "Claude Code plugin ${plugin} could not be installed" >&2
      fi
    '') cfg.plugins
  );

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
  # ~/.claude/skills/synced は claude.ai の同期用なので触らない
  // lib.listToAttrs (
    map (
      name: lib.nameValuePair ".claude/skills/${name}" { source = link "agents/skills/${name}"; }
    ) agentSkillNames
  )
  // lib.mapAttrs' (
    name: source: lib.nameValuePair ".claude/skills/${name}" { inherit source; }
  ) cfg.extraSkills;
}
