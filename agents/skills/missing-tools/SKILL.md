---
name: missing-tools
description: 必要なコマンドが入っていないときに、グローバルにインストールせず実行する。コマンドが使えないとき、シェルが command not found を返したとき、ツールを一時的に使いたいときに使う。
---

コマンドが見つからないときは、次の順に試す。

1. comma で実行する: `, <command> <args>`
   - コマンド名から nixpkgs のパッケージを探して、その場で実行する
   - 候補のパッケージが複数あると、端末の無い環境ではピッカーを開けず `Failed to open tty` で失敗する。そのときは `, -p <command>` で候補を一覧し、正しいパッケージを選んで手順 3 か 4 を使う
   - `, -i` (`--install`) はプロファイルに入れてしまうので使わない
2. プロジェクトの環境を使う: `direnv exec . <command> <args>`
   - devShell にあるツールは、こちらのほうがプロジェクトの想定するバージョンになる
3. パッケージ名が分かっているなら: `nix run nixpkgs#<package> -- <args>`
4. パッケージ名は分かっているが、パッケージ名とコマンド名が違う、または一時的なシェルが要るなら: `nix shell nixpkgs#<package> --command <command> <args>`

例外:

- shebang のインタプリタが無いスクリプト: shebang を読み、`nix shell nixpkgs#<package> --command ./<script>` で実行する
- 最後の手段: `docker run --rm -v "$PWD:/workspace" -w /workspace <image> <command>`

グローバルにはインストールしない。`brew install`、`npm install -g`、`pip install`、`go install`、`curl ... | sh` は使わない。
ずっと使うツールなら、dotfiles (`~/Repository/dotfiles`) の Nix の設定に追加することをユーザーに提案する。

---

[ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles) の `missing-tools` スキルを元に、日本語にしてこの環境に合わせたもの (MIT License、`LICENSE` を参照)。
