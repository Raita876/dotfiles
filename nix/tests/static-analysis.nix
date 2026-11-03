{ pkgs, src }:
let
  inherit (pkgs) lib;
  nixSource = lib.fileset.toSource {
    root = src;
    fileset = lib.fileset.fileFilter (file: file.hasExt "nix") src;
  };
  lint = pkgs.writeShellApplication {
    name = "nix-lint";
    runtimeInputs = [
      pkgs.statix
      pkgs.deadnix
    ];
    text = ''
      statix check "$1"
      deadnix --fail "$1"
    '';
  };
in
{
  nix-lint = pkgs.runCommand "nix-lint" { } ''
    ${lib.getExe lint} ${nixSource}
    touch "$out"
  '';

  nix-lint-tests = pkgs.runCommand "nix-lint-tests" { } ''
    export NIX_LINT=${lib.getExe lint}
    ${pkgs.bash}/bin/bash ${./static-analysis.sh}
    touch "$out"
  '';
}
