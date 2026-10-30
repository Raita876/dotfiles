# push の手順

push の前に、リポジトリの指示と今のブランチを確かめる。ブランチや PR について決まりがあれば従う。

今のブランチが `main` か `master` なら push しない。`git wt <branch>` で worktree を作ってそちらでコミットし直すか、ユーザーに確認する。

upstream があるか確かめる。

```sh
git rev-parse --abbrev-ref --symbolic-full-name @{u}
```

upstream が同じ名前のリモートブランチなら、そのまま push する。

```sh
git push
```

upstream が無いとき、または `origin/main` のような別のブランチを指しているときは、ユーザーに upstream を設定して push するか確認する。

- はい: `git push -u origin HEAD`
- いいえ: push しない
