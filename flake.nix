{
  description = "raita's dotfiles: nix-darwin + home-manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      ...
    }:
    let
      system = "aarch64-darwin";
    in
    {
      # 職場用の flake などから読み込めるよう、設定を部品として公開する。
      # 読み込む側は dotfiles.username / dotfiles.hostname を設定し、必要な値を上書きする (README を参照)
      darwinModules.default = {
        imports = [
          home-manager.darwinModules.home-manager
          ./nix/modules/darwin
        ];
      };
      homeModules.default = ./nix/modules/home;

      darwinConfigurations.raita-mba = nix-darwin.lib.darwinSystem {
        inherit system;
        modules = [
          self.darwinModules.default
          ./nix/hosts/raita-mba.nix
        ];
      };

      # プロジェクトに devShell の雛形を置く: nix flake init -t ~/Repository/dotfiles#node
      templates.node = {
        path = ./templates/node;
        description = "Node.js devShell (direnv 対応)";
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;
    };
}
