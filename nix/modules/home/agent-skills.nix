{
  lib,
  config,
  pkgs,
  ...
}:
{
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

  config.home.file = lib.mapAttrs' (
    name: source: lib.nameValuePair ".agents/skills/${name}" { inherit source; }
  ) config.lib.dotfiles.agentSkillSources;
}
