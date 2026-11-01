{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (config.lib.dotfiles) link;
  piExtensions = pkgs.importNpmLock.buildNodeModules {
    npmRoot = ../../../packages/pi-extensions;
    nodejs = pkgs.nodejs;
    derivationArgs.npmFlags = [ "--legacy-peer-deps" ];
  };
in
{
  programs.pi-coding-agent = {
    enable = true;
    mutableSettings = true;
    extraPackages = [ pkgs.nodejs ];
    settings.defaultProvider = lib.mkDefault "openai";
    settings.defaultModel = lib.mkDefault "gpt-6.1-sol";
    keybindings = {
      "tui.editor.cursorLineStart" = [
        "home"
        "ctrl+a"
        "super+shift+left"
      ];
      "tui.editor.cursorLineEnd" = [
        "end"
        "ctrl+e"
        "super+shift+right"
      ];
    };
    settings.packages = [
      "${piExtensions}/node_modules/pi-web-access"
      "${piExtensions}/node_modules/billion-context"
      "${piExtensions}/node_modules/cc-safety-net"
      "${piExtensions}/node_modules/pi-btw"
      "${piExtensions}/node_modules/pi-lsp"
      "${piExtensions}/node_modules/@juicesharp/rpiv-ask-user-question"
      "${piExtensions}/node_modules/@juicesharp/rpiv-todo"
      "${piExtensions}/node_modules/pi-open-tui"
      "${piExtensions}/node_modules/pi-subagents"
    ];
  };

  # 更新は Nix の lock に集約し、拡張による自己更新を防ぐ。
  home.sessionVariables = {
    ACP_AUTO_UPDATE = "0";
    BILI_ADVISORY_CHECK = "0";
  };

  home.file.".pi/agent/lsp.json".source = (pkgs.formats.json { }).generate "pi-lsp.json" {
    version = 1;
    servers = [
      {
        id = "nixd";
        enabled = true;
        include = [ "**/*.nix" ];
        rootMarkers = [
          "flake.nix"
          "default.nix"
          "shell.nix"
        ];
        bin = "${pkgs.nixd}/bin/nixd";
        args = [ ];
        cwd = "{root}";
        languageIdByExtension.".nix" = "nix";
      }
    ];
  };

  # context オプションだと store へのコピーになり、編集のたびに switch が要るので、自前で symlink する。
  # スキルは pi が ~/.agents/skills も読むので、codex.nix が置いたものをそのまま使う
  home.file.".pi/agent/AGENTS.md".source = link "agents/AGENTS.md";
}
