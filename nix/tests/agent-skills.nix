{
  lib,
  pkgs,
  base,
}:
let
  home = base.config.home-manager.users.${base.config.dotfiles.username};
  sources = home.lib.dotfiles.agentSkillSources;
  skill = sources.security-audit;
  failures = lib.runTests {
    testSharedSkillSources = {
      expr = builtins.all (
        name:
        toString home.home.file.".claude/skills/${name}".source == toString sources.${name}
        && toString home.home.file.".agents/skills/${name}".source == toString sources.${name}
      ) (builtins.attrNames sources);
      expected = true;
    };
    testLocalSkillRemainsEditable = {
      expr = toString sources.pr-review;
      expected = toString (home.lib.dotfiles.link "agents/skills/pr-review");
    };
  };
in
assert lib.assertMsg (failures == [ ]) (builtins.toJSON failures);
pkgs.runCommand "agent-skills-tests" { nativeBuildInputs = [ pkgs.nodejs_26 ]; } ''
  test -f ${skill}/SKILL.md
  test -f ${skill}/RECONNAISSANCE.md
  test -f ${skill}/HUNTING.md
  test -f ${skill}/VALIDATION-AND-REPORTING.md
  test -f ${skill}/report-schema.json
  node --test ${skill}/validate-findings.test.cjs ${skill}/validate-coverage-ledger.test.cjs
  touch "$out"
''
