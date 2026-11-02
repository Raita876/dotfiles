{ config, ... }:
{
  homebrew.casks = [ "visual-studio-code" ];

  # 宣言されていない拡張機能は switch で削除される
  homebrew.vscode = [
    "anthropic.claude-code"
    "hashicorp.terraform"
    "jnoortheen.nix-ide"
    "ms-vscode-remote.remote-containers"
    "openai.chatgpt"
  ];

  home-manager.users.${config.dotfiles.username} =
    { config, ... }:
    {
      home.file."Library/Application Support/Code/User/settings.json".source =
        config.lib.dotfiles.link "vscode/settings.json";
    };
}
