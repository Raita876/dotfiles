---
name: commit
description: 変更を 1 つずつ revert できる小さなコミットに分けて作る。コミットするとき、hunk 単位で変更を分けるとき、コミットメッセージを書くときに使う。`push=true` を渡すとコミット後に push する。
---

# コミット

小さく、それぞれ単独で revert できるコミットを作る。

## 引数

- `push`: コミットの後に push するか (既定は `false`)。`true` で push する

## 手順

1. 今の状態を確かめる。

   ```sh
   git status --short
   git diff HEAD
   git log --oneline -10
   ```

2. 履歴を見たうえで、変更を「それぞれ単独で revert できる最小の単位」に分ける。関係ない変更は入れない。ファイルの移動や切り出しは、追加・削除・参照の更新を 1 つのコミットにまとめる。分け方の例は [`references/revertable-commits.md`](references/revertable-commits.md) を参照。

3. 単位ごとに `git apply --cached -v` で対話なしにステージする。うまく当たらないときは [`references/git-apply.md`](references/git-apply.md) を参照。

   - `git add -A`、`git add --all`、`git add .`、`git add -u` は使わない。関係ない変更まで入ってしまう
   - ファイルまるごとがその単位に入るなら、`git add <path>` でパスを指定する
   - `git add -p` などの対話的なステージは使わない
   - `git commit -a` / `-am` も同じ理由で使わない。インデックスからだけコミットする

   **ステージ済みの変更を信用しない。** Nix flake はステージされたファイルしか見ないので、`nix run .#switch` のために前もってステージした変更が残っていることがある。コミットの前に `git diff --cached --stat` で確かめ、今の単位に入らないものは `git restore --staged <path>` で外す。

4. コミットメッセージを書く。

   - **形式と言語はリポジトリの履歴に合わせる。** `git log --oneline -20` を見て、Conventional Commits か、英語の命令形の 1 行 (`Add ...`、`Fix ...`) か、日本語かを判断する
   - 履歴から決まらないときは、英語の Conventional Commits にする

     ```text
     <type>(<scope>): <subject>

     <body>
     ```

     type は `feat`、`fix`、`docs`、`refactor`、`chore`、`test`、`ci`、`build`、`perf`、`revert` などの標準的なものを使う。
   - 件名だけで伝わらないときは、本文に何を・なぜ変えたかを短く書く
   - コミットの末尾に付ける署名 (`Co-Authored-By` など) の指示がハーネスやリポジトリにあれば従う

5. コミットして、`git show HEAD` と `git diff --check` で確かめる。

push 済みのコミットへのレビュー修正は、amend せず追加のコミットにする。amend するのは、まだ push していない手元のミスか、明示的に頼まれたときだけ。

## push

`push=true` のときは、すべてのコミットを作り終えてから push する。リポジトリのフックは飛ばさない。手順は [`references/push.md`](references/push.md) を参照。

---

[ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles) の `commit` スキルを元に、日本語にしてこの環境に合わせたもの (MIT License、`LICENSE` を参照)。
