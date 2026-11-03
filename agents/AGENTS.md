# Global Agent Instructions

すべてのエージェント向けの共通指示。Claude Code は `~/.claude/CLAUDE.md`、Codex は `~/.codex/AGENTS.md` として読み込む。
細かいルールは `shared/` に分けて、`@~/.claude/shared/<name>.md` で読み込む。
ただし Codex は `@` の読み込みに対応していないので、Codex にも効かせたいルールはこのファイルに直接書く。

## 言語

- 返答は基本日本語で書く

## Git 操作

- feature ブランチは、特に指示やリポジトリの規約がなければ `main` を起点にする
- ブランチを切って作業するときは `git wt <branch> <start-point>` で起点を明示して worktree を作り、その中で作業する。`git switch -c` や `git worktree add` は使わない
- `main` の変更を取り込むときは、既存コミットのハッシュを変えないよう `git merge` を使い、rebase はしない
- merge でコンフリクトしたら、原因となったコミット・ブランチ・PR を調査して報告する。特定できないものはその理由を伝え、マージ元・マージ先のどちらの差分を優先するか指示を仰ぐ。指示があるまで解消しない

## コードコメント

- コメントには「なぜ」だけを書く。「何をしているか」はコードで伝える
- 基本はコメントを書かない
- 変更履歴のコメント (`// X から Y に変更` など) は書かない。それはコミットメッセージに書く

## パッケージ・ツールのインストール

- パッケージやツールは必ず Nix で入れ、dotfiles リポジトリ (`Raita876/dotfiles`、手元では `~/Repository/dotfiles`) で管理する
- `brew install`、`npm install -g`、`pip install`、`go install`、`curl ... | sh` などで直接入れない。nixpkgs に無い GUI アプリは dotfiles の nix-darwin の Homebrew 設定に cask として足す
- 一時的に使うだけなら `nix shell nixpkgs#<pkg>` や `nix run nixpkgs#<pkg>` を使う
