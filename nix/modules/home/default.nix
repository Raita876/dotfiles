{
  imports = [
    ./options.nix
    ./packages.nix
    ./git-hooks.nix
    ./programs/zsh.nix
    ./programs/starship.nix
    ./programs/git.nix
    ./programs/gh.nix
    ./programs/direnv.nix
    ./programs/comma.nix
    ./programs/claude-code.nix
    ./programs/codex.nix
  ];

  home.stateVersion = "26.11";

  programs.home-manager.enable = true;
}
