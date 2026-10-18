{
  # Nix 版 git は macOS の /Library/Developer/CommandLineTools/.../gitconfig を読まず、
  # credential.helper=osxkeychain が効かなくなる。GitHub の認証は gh に任せる
  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
    settings.git_protocol = "https";
  };
}
