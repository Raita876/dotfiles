{
  dotfiles = {
    username = "raita";
    hostname = "raita-mba";
  };

  homebrew = {
    casks = [
      "discord"
      "clipy"
      "google-japanese-ime"
    ];

    vscode = [
      "bierner.markdown-mermaid"
      "bmewburn.vscode-intelephense-client"
      "dbaeumer.vscode-eslint"
      "docker.docker"
      "dsznajder.es7-react-js-snippets"
      "editorconfig.editorconfig"
      "esbenp.prettier-vscode"
      "formulahendry.auto-close-tag"
      "formulahendry.auto-rename-tag"
      "foxundermoon.shell-format"
      "golang.go"
      "mechatroner.rainbow-csv"
      "ms-azuretools.vscode-containers"
      "ms-azuretools.vscode-docker"
      "ms-vscode.makefile-tools"
      "redhat.vscode-yaml"
      "renesaarsoo.sql-formatter-vsc"
      "timonwong.shellcheck"
    ];
  };
}
