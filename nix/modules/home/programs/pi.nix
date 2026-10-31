{ config, pkgs, ... }:
let
  inherit (config.lib.dotfiles) link;
  piExtensions = pkgs.importNpmLock.buildNodeModules {
    npmRoot = ../../../packages/pi-web-access;
    nodejs = pkgs.nodejs;
    derivationArgs.npmFlags = [ "--legacy-peer-deps" ];
  };
in
{
  programs.pi-coding-agent = {
    enable = true;
    mutableSettings = true;
    settings.packages = [ "${piExtensions}/node_modules/pi-web-access" ];
  };

  # context オプションだと store へのコピーになり、編集のたびに switch が要るので、自前で symlink する。
  # スキルは pi が ~/.agents/skills も読むので、codex.nix が置いたものをそのまま使う
  home.file.".pi/agent/AGENTS.md".source = link "agents/AGENTS.md";
}
