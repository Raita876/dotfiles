{ lib, ... }:
{
  programs.git = {
    enable = true;
    settings.user = {
      name = lib.mkDefault "Raita876";
      email = lib.mkDefault "31537047+Raita876@users.noreply.github.com";
    };
  };
}
