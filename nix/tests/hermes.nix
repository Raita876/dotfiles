{
  lib,
  pkgs,
  base,
}:
let
  username = base.config.dotfiles.username;
  home = base.config.home-manager.users.${username};
  cfg = home.services.hermes-agent;
  disabledHome =
    (base.extendModules {
      modules = [
        {
          home-manager.users.${username}.services.hermes-agent.gateway.enable = lib.mkForce false;
        }
      ];
    }).config.home-manager.users.${username};
  overriddenModel = {
    provider = "custom";
    default = "hermes-default";
    base_url = "http://127.0.0.1:4000/v1";
    api_mode = "chat_completions";
  };
  overriddenCfg =
    (base.extendModules {
      modules = [
        {
          home-manager.users.${username}.dotfiles.hermes.model = overriddenModel;
        }
      ];
    }).config.home-manager.users.${username}.services.hermes-agent;
  failures = lib.runTests {
    testCliEnabled = {
      expr = home.programs.hermes-agent.enable;
      expected = true;
    };
    testHostGatewayEnabled = {
      expr = cfg.gateway.enable;
      expected = true;
    };
    testGatewayOptOut = {
      expr = disabledHome.services.hermes-agent.gateway.enable;
      expected = false;
    };
    testGatewayOptOutRemovesLaunchd = {
      expr = builtins.hasAttr "hermes-agent" disabledHome.launchd.agents;
      expected = false;
    };
    testPrivateEnvironmentFile = {
      expr = cfg.environmentFiles;
      expected = [ "${home.home.homeDirectory}/.config/hermes/secrets.env" ];
    };
    testEnvironment = {
      expr = cfg.environment;
      expected = {
        DISCORD_ALLOW_ALL_USERS = "false";
        GATEWAY_ALLOW_ALL_USERS = "false";
        DISCORD_REQUIRE_MENTION = "true";
        DISCORD_ALLOW_BOTS = "none";
      };
    };
    testSettings = {
      expr = cfg.settings;
      expected = {
        model = {
          provider = "openai-codex";
          default = "gpt-6.1-sol";
          base_url = "https://chatgpt.com/backend-api/codex";
        };
        group_sessions_per_user = true;
        approvals = {
          mode = "manual";
          unattended_mode = "deny";
          cron_mode = "deny";
        };
      };
    };
    testModelOverride = {
      expr = overriddenCfg.settings.model;
      expected = overriddenModel;
    };
    testModelOverridePreservesSettings = {
      expr = removeAttrs overriddenCfg.settings [ "model" ];
      expected = removeAttrs cfg.settings [ "model" ];
    };
    testWorkspace = {
      expr = cfg.workingDirectory;
      expected = "${home.home.homeDirectory}/hermes-workspace";
    };
    testHostLaunchdRunAtLoad = {
      expr = home.launchd.agents.hermes-agent.config.RunAtLoad;
      expected = true;
    };
    testLaunchdLabel = {
      expr = home.launchd.agents.hermes-agent.config.Label;
      expected = "org.nix-community.home.hermes-agent";
    };
    testDiscordCask = {
      expr = builtins.any (entry: entry.name == "discord") base.config.homebrew.casks;
      expected = true;
    };
  };
in
assert lib.assertMsg (failures == [ ]) "Hermes tests failed: ${builtins.toJSON failures}";
pkgs.runCommand "hermes-tests" { } ''
  export HOME="$TMPDIR/home"
  export HERMES_HOME="$HOME/.hermes"
  mkdir -p "$HOME"
  ${lib.getExe home.programs.hermes-agent.package} --help > "$TMPDIR/help.txt"
  grep -q gateway "$TMPDIR/help.txt"
  ${home.programs.hermes-agent.package.hermesVenv}/bin/python3 -c 'import discord; import plugins.platforms.discord'
  touch "$out"
''
