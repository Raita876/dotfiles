{ config, ... }:
let
  inherit (config.lib.dotfiles) link;
in
{
  programs.pi-coding-agent.enable = true;

  # context オプションだと store へのコピーになり、編集のたびに switch が要るので、自前で symlink する。
  # スキルは pi が ~/.agents/skills も読むので、codex.nix が置いたものをそのまま使う
  home.file.".pi/agent/AGENTS.md".source = link "agents/AGENTS.md";
}
