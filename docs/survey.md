# dotfiles 構成の調査

調査日: 2026-10-14

## 調べたこと

1. dotfiles リポジトリ全体のうち、Nix を使っているものはどのくらいあるか
2. Nix を使っている人は、どの組み合わせ (nix-darwin / NixOS / home-manager) で管理しているか

## 1. dotfiles 全体での Nix の割合

GitHub の検索で、名前に `dotfiles` を含み ★20 以上のリポジトリを主要言語別に数えた。

| 主要言語 | 件数 |
|---|---|
| Shell | 1,083 |
| Lua (主に Neovim 設定) | 439 |
| Vim Script | 239 |
| **Nix** | **147** |
| Python | 124 |
| Emacs Lisp | 79 |
| 全体 | 2,626 |

- 全体に占める Nix の割合は **約 6%**。直近 1 年に更新があったものに絞ると 1,632 件中 126 件で **約 8%**。
- `nix-config` / `nixos-config` という名前のリポジトリ (Nix, ★20 以上) も別に 188 件ある。名前に `dotfiles` を付けない人も多いため、実際の割合はもう少し高い。
- **まとめ**: 主流はまだシェルスクリプトや symlink 管理。ただし Nix は少数派ながら存在感があり、熱心な層が使っている。

## 2. Nix を使っている人の構成

★50 以上の Nix dotfiles 系リポジトリ 99 件を clone し、`.nix` ファイルの中身から使っている仕組みを判定した (機械的な判定なので多少の誤差あり)。

| 構成 | 件数 | 割合 |
|---|---|---|
| home-manager を使っている | 95 | 96% |
| NixOS の構成を含む | 82 | 83% |
| nix-darwin (macOS) の構成を含む | 50 | 51% |
| └ NixOS と nix-darwin の両方 | 43 | |
| └ **nix-darwin のみ (macOS 専用)** | 7 | |
| NixOS も nix-darwin もなし (home-manager のみ) | 10 | 10% |
| flake-parts を使っている | 35 | 35% |

読み取れること:

- **home-manager はほぼ全員が使っている。** ユーザー環境の管理は事実上の標準。
- **NixOS ユーザーが多数派。** 人気リポジトリの多くは「Linux デスクトップ (NixOS) を Nix で丸ごと管理し、ついでに Mac も」という人たち。
- **macOS を管理する人の大半は nix-darwin を使う。** nix-darwin を含むリポジトリは半数あり、Mac を Nix で管理するなら nix-darwin + home-manager が定番。
- **flake-parts は 3 分の 1 程度。** 必須ではなく、規模が大きくなってから入れる人が多い。

## macOS 専用 (nix-darwin + home-manager) の例

本プランと同じ形。日本人の開発者が目立つ。

| リポジトリ | ★ | メモ |
|---|---|---|
| [babarot/dotfiles](https://github.com/babarot/dotfiles) | 782 | 日本人。Mac 2 台を 1 つの flake で管理。「1 ツール = 1 ファイル」の構成が参考になる。Ghostty + Herdr を使用 |
| [mizchi/chezmoi-dotfiles](https://github.com/mizchi/chezmoi-dotfiles) | 609 | 日本人 (Web 系で著名)。パッケージは home-manager + nix-darwin、設定ファイルは chezmoi という分担 |
| [ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles) | 268 | 日本人。Mac は nix-darwin、Linux は home-manager 単体 (NixOS ではない) |
| [matchai/dotfiles](https://github.com/matchai/dotfiles) | 210 | starship の作者 |
| [breuerfelix/dotfiles](https://github.com/breuerfelix/dotfiles) | 178 | |
| [NickSeagull/dotfiles](https://github.com/NickSeagull/dotfiles) | 99 | |
| [bjeanes/dotfiles](https://github.com/bjeanes/dotfiles) | 80 | |

## その他の有名どころ

| リポジトリ | ★ | 構成 |
|---|---|---|
| [Misterio77/nix-starter-configs](https://github.com/Misterio77/nix-starter-configs) | 3,850 | 入門用テンプレート集 (NixOS / home-manager) |
| [dustinlyons/nixos-config](https://github.com/dustinlyons/nixos-config) | 3,648 | macOS + NixOS。Mac 向けの解説が丁寧 |
| [mitchellh/nixos-config](https://github.com/mitchellh/nixos-config) | 3,115 | HashiCorp・Ghostty の作者。Mac 上の VM で NixOS を動かして開発する珍しいスタイル |
| [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config) | 2,096 | 著者は入門書「NixOS & Flakes Book」も書いている |
| [natsukium/dotfiles](https://github.com/natsukium/dotfiles) | 106 | 日本人。nixpkgs メンテナ。macOS + NixOS |

## 結論 (本プランへの影響)

- **「nix-darwin + home-manager で macOS を管理」は、Mac を Nix で管理する場合の定番構成。** 本プランの方針で問題ない。
- 日本人の Mac ユーザー (babarot, mizchi, ryoppippi) も同じ構成を採っている。参考にする候補として babarot さんを追加するとよい (設定がシンプルで、Ghostty / Herdr という同じ道具を使っている)。
- flake-parts は後から導入する方針のままでよい。
- mitchellh さんの「Mac 上で NixOS の VM を動かす」スタイルは実在するが少数派。
