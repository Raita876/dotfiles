# Global Agent Instructions

すべてのエージェント向けの共通指示。Claude Code は `~/.claude/CLAUDE.md`、Codex は `~/.codex/AGENTS.md` として読み込む。
細かいルールは `shared/` に分けて、`@~/.claude/shared/<name>.md` で読み込む。
ただし Codex は `@` の読み込みに対応していないので、Codex にも効かせたいルールはこのファイルに直接書く。

## 言語

- 返答は基本日本語で書く

## ブランチ

- ブランチを切って作業するときは `git wt <branch> [<start-point>]` で worktree を作り、その中で作業する。`git switch -c` や `git worktree add` は使わない

## コードコメント

- コメントには「なぜ」だけを書く。「何をしているか」はコードで伝える
- 基本はコメントを書かない
- 変更履歴のコメント (`// X から Y に変更` など) は書かない。それはコミットメッセージに書く

## パッケージ・ツールのインストール

- パッケージやツールは必ず Nix で入れ、dotfiles リポジトリ (`Raita876/dotfiles`、手元では `~/Repository/dotfiles`) で管理する
- `brew install`、`npm install -g`、`pip install`、`go install`、`curl ... | sh` などで直接入れない。nixpkgs に無い GUI アプリは dotfiles の nix-darwin の Homebrew 設定に cask として足す
- 一時的に使うだけなら `, <command>` (comma)、`nix run nixpkgs#<pkg>`、`nix shell nixpkgs#<pkg>` を使う。手順は missing-tools スキルにある
