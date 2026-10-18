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
      hostname = "raita-mba";
      username = "raita";
      homedir = "/Users/${username}";
      # 設定ファイルの symlink 先。リポジトリを移動したらここを変える
      dotfilesDir = "${homedir}/Repository/dotfiles";
    in
    {
      darwinConfigurations.${hostname} = nix-darwin.lib.darwinSystem {
        inherit system;
        specialArgs = { inherit hostname username homedir; };
        modules = [
          ./nix/modules/darwin
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              # 既存の ~/.zshrc などと衝突したら *.before-nix に退避する
              backupFileExtension = "before-nix";
              extraSpecialArgs = { inherit dotfilesDir; };
              users.${username} = ./nix/modules/home;
            };
          }
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
