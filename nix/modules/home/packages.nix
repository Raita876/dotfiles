{ pkgs, lib, ... }:
let
  # Node2Shell (CVE-2026-111497) の暫定対応。nixpkgs の Node は nixpkgs の brotli にリンクするので、
  # master で nodejs_22 / 26 に当てているのと同じパッチを nodejs_24 の brotli にも当てる。
  # brotli 1.2.1 にはこの修正が入っているので、flake.lock の更新で 1.2.1 になったら当てずに nixpkgs のものを使う。
  # そうなったらこのブロックごと外す
  # https://github.com/NixOS/nixpkgs/pull/576792
  needsBrotliFix = lib.versionOlder pkgs.brotli.version "1.2.1";
  brotli = pkgs.brotli.overrideAttrs (old: {
    patches = old.patches ++ [
      (pkgs.fetchurl {
        url = "https://github.com/google/brotli/commit/0ed4268a4401abcb4472096340477cf4af7d1a2b.patch?full_index=1";
        hash = "sha256-1vliUJAAIj3vcGKVgim9CEV+XgMuftDR2U+3kLBUsfw=";
      })
    ];
  });
  # nodejs_24 は nodejs-slim_24 と npm をまとめたものなので、brotli は nodejs-slim_24 の側で差し替える
  nodejs_24 =
    if needsBrotliFix then
      pkgs.nodejs_24.override {
        nodejs-slim = pkgs.nodejs-slim_24.override { callPackage = pkgs.newScope { inherit brotli; }; };
      }
    else
      pkgs.nodejs_24;
in
{
  home.packages = with pkgs; [
    eza
    jq
    tree
    gitleaks
    git-secrets
    go-task
    awscli2
    terraform
    herdr

    nixd
    nixfmt

    nodejs_24
    pnpm
    go_1_27
  ];
}
