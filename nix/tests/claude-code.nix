{
  lib,
  pkgs,
  base,
}:
let
  username = base.config.dotfiles.username;
  home = base.config.home-manager.users.${username};
  settings = home.dotfiles.claudeCode.settings;
  consumerHook = {
    hooks = [
      {
        type = "command";
        command = "echo consumer-stop";
      }
    ];
  };
  extendSettings =
    extra:
    (base.extendModules {
      modules = [
        {
          home-manager.users.${username}.dotfiles.claudeCode = extra;
        }
      ];
    }).config.home-manager.users.${username}.dotfiles.claudeCode.settings;
  merged = extendSettings {
    settings = {
      hooks.Stop = [ consumerHook ];
      theme = "light";
      permissions.defaultMode = "default";
    };
  };
  disabled = extendSettings {
    herdrAutoName.enable = false;
  };
  disabledWithConsumer = extendSettings {
    herdrAutoName.enable = false;
    settings.hooks.Stop = [ consumerHook ];
  };
  command = "${lib.getExe pkgs.nodejs} ${lib.escapeShellArg "${home.dotfiles.dir}/claude/hooks/herdr-auto-name.mjs"} ${lib.getExe base.pkgs.claude-code}";
  expectedHooks = {
    Stop = [
      {
        hooks = [
          {
            type = "command";
            inherit command;
            async = true;
          }
        ];
      }
    ];
  }
  // lib.genAttrs [ "UserPromptSubmit" "SessionEnd" ] (_: [
    {
      hooks = [
        {
          type = "command";
          inherit command;
          timeout = 5;
        }
      ];
    }
  ]);
  failures = lib.runTests {
    testAutoNameEnabledByDefault = {
      expr = home.dotfiles.claudeCode.herdrAutoName.enable;
      expected = true;
    };
    testAllAutoNameHooksRegistered = {
      expr = settings.hooks;
      expected = expectedHooks;
    };
    testConsumerStopIsMerged = {
      expr = {
        count = builtins.length merged.hooks.Stop;
        hasAutoName = builtins.elem (builtins.head expectedHooks.Stop) merged.hooks.Stop;
        hasConsumer = builtins.elem consumerHook merged.hooks.Stop;
      };
      expected = {
        count = 2;
        hasAutoName = true;
        hasConsumer = true;
      };
    };
    testConsumerStopPreservesCancellationHooks = {
      expr = removeAttrs merged.hooks [ "Stop" ];
      expected = removeAttrs expectedHooks [ "Stop" ];
    };
    testScalarDefaultsAreOverridable = {
      expr = {
        inherit (merged) theme permissions;
      };
      expected = {
        theme = "light";
        permissions.defaultMode = "default";
      };
    };
    testOptOutRemovesAllAutoNameHooks = {
      expr = disabled.hooks or { };
      expected = { };
    };
    testOptOutPreservesConsumerHooks = {
      expr = disabledWithConsumer.hooks;
      expected.Stop = [ consumerHook ];
    };
    testOptOutPreservesOtherSettings = {
      expr = removeAttrs disabled [ "hooks" ];
      expected = removeAttrs settings [ "hooks" ];
    };
  };
in
assert lib.assertMsg (failures == [ ]) "Claude Code tests failed: ${builtins.toJSON failures}";
pkgs.runCommand "claude-code-tests" { } ''
  touch "$out"
''
