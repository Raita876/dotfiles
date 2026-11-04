{ config, lib, ... }:
{
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
}
