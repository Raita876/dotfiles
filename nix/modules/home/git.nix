{ lib, ... }:
{
  programs.git = {
    enable = true;
    # 職場の Mac では会社の名前とメールアドレスに上書きできるよう mkDefault にする
    settings.user = {
      name = lib.mkDefault "Raita876";
      email = lib.mkDefault "31537047+Raita876@users.noreply.github.com";
    };
  };
}
