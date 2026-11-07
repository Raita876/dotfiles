{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.dotfiles.dir = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/Repository/dotfiles";
    defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/Repository/dotfiles"'';
    description = "このリポジトリを clone した場所。zshrc などの symlink 先になる";
  };

  # リポジトリ内のファイルへの symlink を作る (編集が即反映され、switch 不要)
  config.lib.dotfiles.link =
    path: config.lib.file.mkOutOfStoreSymlink "${config.dotfiles.dir}/${path}";

  config.lib.dotfiles.agentSkillSources =
    lib.mapAttrs (name: _: config.lib.dotfiles.link "agents/skills/${name}") (
      lib.filterAttrs (_: type: type == "directory") (builtins.readDir ../../../agents/skills)
    )
    // {
      argus-db = pkgs.runCommand "argus-db-skill" { } ''
        src=${
          pkgs.fetchFromGitHub {
            owner = "hugoassisj";
            repo = "argus-db";
            rev = "85f2abda7dff1eb0f4979c229dbdcb65683f16d1";
            hash = "sha256-03TqbIShp9DEaM0owpd5EjUg4nVxkhYgcJrSjo+Vi1M=";
          }
        }
        mkdir -p "$out"
        cp -R "$src/skills/review/." "$out/"
        cp "$src/LICENSE" "$out/LICENSE"
        chmod u+w "$out/SKILL.md"
        substituteInPlace "$out/SKILL.md" --replace-fail 'name: review' 'name: argus-db'
      '';
      security-audit = "${
        pkgs.fetchFromGitHub {
          owner = "cloudflare";
          repo = "security-audit-skill";
          rev = "c1c8a8c1471069fb0e188eeaff69b8e8db6564a8";
          hash = "sha256-oVVACjotkHvllQGxEP8yWaEt4c3GxT0d909TUM5P3NM=";
        }
      }/skills/security-audit";
    };
}
