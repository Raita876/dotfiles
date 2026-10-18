{ lib, config, ... }:
let
  cfg = config.dotfiles;
in
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = lib.mkDefault "before-nix";
    users.${cfg.username} = {
      imports = [ ../home ];
      dotfiles.dir = lib.mkDefault cfg.dir;
    };
  };
}
