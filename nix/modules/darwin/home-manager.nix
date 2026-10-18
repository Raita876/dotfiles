{ lib, config, ... }:
let
  cfg = config.dotfiles;
in
{
  # home-manager.darwinModules.home-manager と一緒に読み込む前提 (flake.nix の darwinModules.default を参照)
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    # 既存の ~/.zshrc などと衝突したら *.before-nix に退避する
    backupFileExtension = lib.mkDefault "before-nix";
    users.${cfg.username} = {
      imports = [ ../home ];
      dotfiles.dir = lib.mkDefault cfg.dir;
    };
  };
}
