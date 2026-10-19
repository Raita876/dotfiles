{
  pkgs,
  lib,
  config,
  ...
}:
let
  git = lib.getExe pkgs.git;

  # このリポジトリだけに置くフック (core.hooksPath は使わないので、ほかのリポジトリには影響しない)
  preCommit = pkgs.writeShellScript "dotfiles-pre-commit" ''
    set -euo pipefail

    ${lib.getExe pkgs.gitleaks} git --pre-commit --staged --redact --no-banner --log-level warn

    mapfile -t nixFiles < <(${git} diff --cached --name-only --diff-filter=ACMR -- '*.nix')
    if [ "''${#nixFiles[@]}" -gt 0 ] && ! ${lib.getExe pkgs.nixfmt} --check "''${nixFiles[@]}"; then
      echo "整形されていない .nix ファイルがある。nix fmt を実行して add し直す" >&2
      exit 1
    fi
  '';
in
{
  home.activation.installDotfilesGitHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -d "${config.dotfiles.dir}/.git" ]; then
      hooksDir="$(${git} -C "${config.dotfiles.dir}" rev-parse --path-format=absolute --git-path hooks)"
      run mkdir -p "$hooksDir"
      run ln -sf ${preCommit} "$hooksDir/pre-commit"
    fi
  '';
}
