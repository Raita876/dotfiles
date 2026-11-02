{
  lib,
  pkgs,
  base,
}:
let
  baseline = base.config.homebrew;
  configured =
    (base.extendModules {
      modules = [
        {
          homebrew = {
            casks = [
              "slack"
              {
                name = "firefox";
                greedy = true;
              }
              {
                name = "excluded-cask";
                greedy = true;
              }
            ];
            brews = [
              "watch"
              {
                name = "redis";
                restart_service = "changed";
              }
              {
                name = "excluded-brew";
                link = false;
              }
            ];
            vscode = [
              "ms-python.python"
              "excluded.extension"
            ];
          };
          dotfiles.homebrew.exclude = {
            casks = [
              "notion"
              "visual-studio-code"
              "cmux"
              "herdr-app"
              "discord"
              "excluded-cask"
              "missing-cask"
            ];
            brews = [
              "colima"
              "excluded-brew"
              "missing-brew"
            ];
            vscode = [
              "hashicorp.terraform"
              "excluded.extension"
              "missing.extension"
            ];
          };
        }
        {
          dotfiles.homebrew.exclude.casks = [ "zoom" ];
        }
      ];
    }).config.homebrew;
  forced =
    (base.extendModules {
      modules = [
        {
          homebrew.casks = lib.mkForce [
            "slack"
            "zoom"
          ];
          dotfiles.homebrew.exclude.casks = [ "zoom" ];
        }
      ];
    }).config.homebrew;
  names = entries: map (entry: entry.name) entries;
  sorted = builtins.sort builtins.lessThan;
  removedCasks = [
    "notion"
    "zoom"
    "visual-studio-code"
    "cmux"
    "herdr-app"
    "discord"
  ];
  failures = lib.runTests {
    testDefaultBrews = {
      expr = sorted (names baseline.brews);
      expected = sorted [
        "colima"
        "docker"
        "docker-buildx"
        "docker-compose"
      ];
    };
    testDefaultCasks = {
      expr = sorted (names baseline.casks);
      expected = sorted [
        "ghostty"
        "google-chrome"
        "notion"
        "zoom"
        "visual-studio-code"
        "cmux"
        "herdr-app"
        "discord"
        "clipy"
        "google-japanese-ime"
      ];
    };
    testCasks = {
      expr = sorted (names configured.casks);
      expected = sorted (
        (builtins.filter (name: !(builtins.elem name removedCasks)) (names baseline.casks))
        ++ [
          "slack"
          "firefox"
        ]
      );
    };
    testBrews = {
      expr = sorted (names configured.brews);
      expected = sorted (
        (builtins.filter (name: name != "colima") (names baseline.brews))
        ++ [
          "watch"
          "redis"
        ]
      );
    };
    testVscode = {
      expr = sorted configured.vscode;
      expected = sorted (
        (builtins.filter (name: name != "hashicorp.terraform") baseline.vscode) ++ [ "ms-python.python" ]
      );
    };
    testCaskArgumentsPreserved = {
      expr = (lib.findFirst (entry: entry.name == "firefox") null configured.casks).greedy;
      expected = true;
    };
    testBrewArgumentsPreserved = {
      expr = (lib.findFirst (entry: entry.name == "redis") null configured.brews).restart_service;
      expected = "changed";
    };
    testMkForce = {
      expr = names forced.casks;
      expected = [ "slack" ];
    };
    testBrewfile = {
      expr =
        lib.hasInfix ''cask "slack"'' configured.brewfile
        && lib.hasInfix ''brew "watch"'' configured.brewfile
        && !(lib.hasInfix ''cask "notion"'' configured.brewfile)
        && !(lib.hasInfix ''brew "colima"'' configured.brewfile)
        && lib.hasInfix ''vscode "ms-python.python"'' configured.brewfile
        && !(lib.hasInfix ''vscode "hashicorp.terraform"'' configured.brewfile)
        && !(lib.hasInfix ''vscode "excluded.extension"'' configured.brewfile);
      expected = true;
    };
  };
in
assert lib.assertMsg (failures == [ ]) "Homebrew tests failed: ${builtins.toJSON failures}";
pkgs.runCommand "homebrew-tests" { } ''
  touch "$out"
''
