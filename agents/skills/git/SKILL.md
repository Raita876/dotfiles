---
name: git
description: Git のブランチ作成、worktree での作業、main の取り込み、コンフリクト調査、コミット・push・PR 作成を安全に進める。feature ブランチは原則 main 起点で git wt を使い、既存コミットのハッシュを保つため merge で同期する。
compatibility: A coding agent with file-reading and command-execution tools, plus git and git-wt. GitHub PR operations also require authenticated gh.
---

# Git workflow

## 基本方針

- ユーザーの明示指示と対象リポジトリの規約を確認し、起点ブランチ・命名・検証方法などの個別ルールを優先する。指示が衝突する場合は実行前に確認する。
- feature ブランチは、特にルールがなければ `main` から作る。現在のブランチを暗黙の起点にしない。`main` がない場合は別のブランチを推測で使わず確認する。
- ブランチを切って作業するときは `git wt <branch> <start-point>` で worktree を作り、その中で作業する。`git switch -c` や `git worktree add` で代替しない。`git wt` が利用できない場合は停止して報告する。
- `main` の変更は `git merge` で取り込む。既存コミットのハッシュを保つため、`rebase`、`pull --rebase`、`merge --squash` に置き換えない。履歴を書き換える操作を明示依頼された場合は影響を説明して確認する。
- コンフリクトは勝手に解消しない。原因となったコミット・ブランチ・PR を調べ、マージ元とマージ先のどちらの差分を優先するかユーザーに確認する。

## 1. 作業前の確認

```sh
git status --short --branch
git branch --show-current
git remote -v
git worktree list
git diff
git diff --cached
```

- 対象リポジトリ、現在のブランチ、未コミット・未追跡ファイル、ステージ済み差分、進行中の merge / rebase を確認する。既存の変更を今回の作業へ混ぜない。
- 未完了の Git 操作があれば、勝手に続行・中止しない。元からある変更の stash・移動・削除もしない。
- 以降の `origin` は例。実際の remote を確認して使い、push 先と upstream が異なる構成では混同しない。認証情報を含む URL や差分内の秘密情報を報告に載せない。
- `git fetch <remote>` で参照を更新する。失敗した場合は最新とみなさず、接続・権限の問題を報告する。

## 2. main 起点の worktree を作る

`git log --oneline --left-right main...origin/main` などでローカル `main` と remote の差を確認する。

- 一致していれば、`main` を明示して作る。
- ローカル `main` が遅れているだけなら、fetch 済みの `origin/main` を起点に `git wt feat/example origin/main` で作ってよい。これは remote の `main` 起点であり、別 worktree のローカル `main` を書き換えずに済む。
- ローカル `main` に固有コミットがある、分岐している、remote の `main` がないなど、起点が曖昧なら確認する。`reset` で揃えない。

```sh
git wt feat/example main
```

起点を選んで作成コマンドを一度だけ実行する。作成前に同名ブランチ・worktree の有無を確認し、既存なら新規作成されたものとみなさず、起点と変更を確認する。

`git wt` はシェル連携がない実行環境ではカレントディレクトリを変更しない。出力されたパスを作業ディレクトリに指定するか明示的に移動し、`git branch --show-current` と `git status --short --branch` で対象を再確認してから編集する。

## 3. main の変更を取り込む

作業ブランチの worktree で、未コミット変更がなく、別の Git 操作も進行していないことを確認する。変更があれば勝手に commit / stash せず、扱いを確認する。

```sh
git fetch origin
git merge origin/main
```

fetch が成功した場合だけ merge へ進む。`git pull` の暗黙設定に依存せず、取り込む参照を明示する。ローカル `main` 固有の変更を取り込む指示なら `git merge main` を使う。

マージ元は取り込む側の参照（この例では `origin/main`）、マージ先は現在の作業ブランチ。必要に応じて両者のブランチ名と SHA を merge 前に記録する。fast-forward も既存コミットのハッシュを保つため許容する。成功後は差分と履歴を確認し、関連テストを実行する。

## 4. コンフリクトを調査して指示を仰ぐ

コンフリクト発生後は解消・ステージ・コミットを止める。一括の `--ours` / `--theirs` や、どちらかを採用する自動解消オプションを使わない。

### 調査

```sh
git status
git diff --name-only --diff-filter=U
git diff --cc
git log --merge --oneline -- path/to/conflicted-file
git log --oneline <merge-base>..<destination-sha> -- path/to/conflicted-file
git log --oneline <merge-base>..<source-sha> -- path/to/conflicted-file
git show <commit-sha> -- path/to/conflicted-file
```

- `<merge-base>` は `git merge-base <destination-sha> <source-sha>` で調べる。複数の共通祖先がある場合は `git merge-base --all` で確認し、単一の祖先だけで原因を断定しない。
- ファイル単位のログだけで断定せず、該当箇所の diff と必要に応じた `git blame <sha> -- <path>` で、両側の変更意図と原因コミットを追う。rename / delete / modify などの競合種別も確認する。
- ブランチ名は記録済みのマージ元・先を示す。原因コミットの元ブランチは `git branch -a --contains <commit-sha>` や PR 情報で調べるが、「コミットを含むブランチ」と「変更が作られたブランチ」は同一とは限らない。
- GitHub なら認証済みの `gh` で関連 PR を調べる。例: `gh api repos/{owner}/{repo}/commits/<commit-sha>/pulls`。候補 PR は `gh pr view <number> --json number,url,title,baseRefName,headRefName,mergeCommit` で確認する。複数候補を推測で一つに絞らない。
- PR がない、ブランチが削除済み、権限がない、squash で元コミットを追えないなどの場合は、確認できた証拠と不明点を分ける。PR・ブランチを捏造せず、追加調査に必要な情報を伝える。

### 報告と確認

次をまとめて、解消前にユーザーへ確認する。

- マージ元とマージ先のブランチ名・SHA、競合ファイルと箇所。
- 両側の原因コミット（SHA・件名・変更意図）と関連ブランチ・PR の番号 / URL。特定できなかった項目と理由。
- マージ元・先それぞれを優先した場合の挙動の違いと、テスト・互換性への影響。
- 「この競合では、マージ元 `<source>` とマージ先 `<destination>` のどちらの差分を優先しますか。必要なら両方を残す方針も指定してください」という質問。

ファイル・箇所ごとに異なる判断が必要ならまとめて確認する。回答を待つ間は merge 途中の状態を保ち、勝手に `git merge --abort` もしない。中止を依頼された場合のみ、元の変更を失わないことを確認して実行する。

方針の回答後も、未回答の競合は解消しない。許可された範囲で解消し、競合マーカーの残存、`git diff --check`、ステージ済み差分、関連テストを確認してから merge を完了する。ユーザーの回答だけをテスト成功の代わりにしない。

## 5. コミット・push・PR

- ユーザーの依頼範囲でのみ実行する。ローカル作業の依頼だけで push / PR 作成まで許可されたと解釈しない。PR 作成を依頼された場合は必要な commit / push を含めて進めてよいが、PR の merge は別途依頼を待つ。
- `git diff --check` とプロジェクト所定の検証を行う。失敗・未実行を成功と報告しない。
- `git add <path>...` で今回の変更だけをステージし、`git diff --cached` で内容と秘密情報の混入を確認する。無関係な変更を `git add .` や `git commit -a` で巻き込まない。
- 新規コミットを基本とし、`commit --amend`、`reset --hard`、`clean -fd`、force push、ブランチの強制削除などは明示許可なしに行わない。hook や署名を無断で無効化しない。
- push 先 remote とブランチを確認し、例として `git push -u origin feat/example` のように明示する。拒否されたら force push せず原因を調べる。remote の変更を取り込む必要があれば merge を基本とする。
- PR 作成前に既存 PR を確認し、重複作成を避ける。base / head を明示し、概要、変更理由、検証結果、未解決事項を本文に記載する。PR 作成後は URL を確認して報告する。
- 最後にブランチ、コミット、検証結果、PR URL と残作業を報告する。worktree は勝手に削除しない。
