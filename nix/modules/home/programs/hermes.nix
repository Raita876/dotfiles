{ config, lib, ... }:
{
  options.dotfiles.hermes.model = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = "Hermes model settings, overridable per host or by consuming flakes.";
  };

  config = {
    dotfiles.hermes.model = {
      provider = lib.mkDefault "openai-codex";
      default = lib.mkDefault "gpt-6.1-sol";
      base_url = lib.mkDefault "https://chatgpt.com/backend-api/codex";
    };

    programs.hermes-agent.enable = true;

    services.hermes-agent = {
      enable = true;
      gateway.enable = lib.mkDefault false;
      workingDirectory = "${config.home.homeDirectory}/hermes-workspace";
      environmentFiles = [ "${config.home.homeDirectory}/.config/hermes/secrets.env" ];
      environment = {
        DISCORD_ALLOW_ALL_USERS = "false";
        GATEWAY_ALLOW_ALL_USERS = "false";
        DISCORD_REQUIRE_MENTION = "true";
        DISCORD_ALLOW_BOTS = "none";
      };
      settings = {
        model = config.dotfiles.hermes.model;
        group_sessions_per_user = true;
        approvals = {
          mode = "manual";
          unattended_mode = "deny";
          cron_mode = "deny";
        };
      };
    };
  };
}
