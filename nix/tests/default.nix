{
  lib,
  pkgs,
  base,
}:
lib.genAttrs [
  "claude-code"
  "homebrew"
  "hermes"
  "agent-skills"
] (name: import (./. + "/${name}.nix") { inherit lib pkgs base; })
