{
  pkgs,
  lib,
  config,
  ...
}:
let
  codexConfigDir = "${config.home.homeDirectory}/.codex";
  inherit (config.lib.dotfiles) link agentSkillNames;

  jq = lib.getExe pkgs.jq;
  toml2json = lib.getExe' pkgs.remarshal "toml2json";
  json2toml = lib.getExe' pkgs.remarshal "json2toml";
  checkJsonschema = lib.getExe pkgs.check-jsonschema;
  tomlFormat = pkgs.formats.toml { };

  settingsFile = tomlFormat.generate "codex-config.toml" config.dotfiles.codex.settings;
  # 入れている版に合わせたスキーマで検証する
  schemaUrl = "https://raw.githubusercontent.com/openai/codex/rust-v${pkgs.codex.version}/codex-rs/core/config.schema.json";
in
{
  options.dotfiles.codex.settings = lib.mkOption {
    inherit (tomlFormat) type;
    default = { };
    description = "~/.codex/config.toml に switch のたびに書き込む設定。ここに無いキーは Codex が書いた値のまま残る";
  };

  # Claude Code の auto モードに寄せる。コマンドはサンドボックス内で動かし、
  # サンドボックスの外に出るとき (ネットワークや書き込み範囲外など) は auto_review のサブエージェントが判断する
  config.dotfiles.codex.settings = lib.mapAttrsRecursive (_: lib.mkDefault) {
    approval_policy = "on-request";
    approvals_reviewer = "auto_review";
    sandbox_mode = "workspace-write";
    web_search = "live";
    # AGENTS.md の無いリポジトリでも CLAUDE.md を読む
    project_doc_fallback_filenames = [ "CLAUDE.md" ];
    # 更新は nix で行う
    check_for_update_on_startup = false;
  };

  config.home.packages = [ pkgs.codex ];

  # Codex 自身もこのファイルを書き換える (プロジェクトの trust など) ので、置き換えずにマージする
  config.home.activation.writeCodexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    CONFIG_FILE="${codexConfigDir}/config.toml"
    mkdir -p "${codexConfigDir}"

    if [ -f "$CONFIG_FILE" ]; then
      TEMP_FILE="$(mktemp "${codexConfigDir}/.config.toml.XXXXXX")"
      if ! ${jq} -s '.[0] * .[1]' <(${toml2json} "$CONFIG_FILE") <(${toml2json} ${settingsFile}) \
          | ${json2toml} > "$TEMP_FILE"; then
        rm -f "$TEMP_FILE"
        exit 1
      fi
      mv "$TEMP_FILE" "$CONFIG_FILE"
    else
      cp --no-preserve=mode,ownership ${settingsFile} "$CONFIG_FILE"
    fi
    chmod 644 "$CONFIG_FILE"
  '';

  config.home.activation.validateCodexConfig = lib.hm.dag.entryAfter [ "writeCodexConfig" ] ''
    CONFIG_FILE="${codexConfigDir}/config.toml"

    echo "Validating Codex config.toml..."
    if ${checkJsonschema} --schemafile "${schemaUrl}" "$CONFIG_FILE" 2>&1; then
      echo "Codex config.toml validation passed"
    else
      echo "Codex config.toml validation failed (non-blocking, schema may be outdated)" >&2
    fi
  '';

  # Codex は ~/.codex/AGENTS.md を、スキルは ~/.agents/skills を読む
  config.home.file = {
    ".codex/AGENTS.md".source = link "agents/AGENTS.md";
  }
  // lib.listToAttrs (
    map (
      name: lib.nameValuePair ".agents/skills/${name}" { source = link "agents/skills/${name}"; }
    ) agentSkillNames
  );
}
