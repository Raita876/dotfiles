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

    # comma が引く nix-index のデータベースを週次ビルド済みのもので配る
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      nix-index-database,
      ...
    }:
    let
      system = "aarch64-darwin";
    in
    {
      darwinModules.default = {
        imports = [
          home-manager.darwinModules.home-manager
          ./nix/modules/darwin
          { home-manager.sharedModules = [ nix-index-database.homeModules.nix-index ]; }
        ];
      };
      homeModules.default = {
        imports = [
          ./nix/modules/home
          nix-index-database.homeModules.nix-index
        ];
      };

      darwinConfigurations.raita-mba = nix-darwin.lib.darwinSystem {
        inherit system;
        modules = [
          self.darwinModules.default
          ./nix/hosts/raita-mba.nix
        ];
      };

      apps.${system} = import ./nix/apps.nix {
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (nixpkgs) lib;
        darwinRebuild = nix-darwin.packages.${system}.darwin-rebuild;
        dir = self.darwinConfigurations.raita-mba.config.dotfiles.dir;
        host = "raita-mba";
      };

      templates.node = {
        path = ./templates/node;
        description = "Node.js devShell (direnv 対応)";
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;
    };
}
