# git apply のリファレンス

## 基本

```sh
# 先に当たるか確かめる
git apply --check patch_file.patch

# 詳細を出しながら当てる
git apply -v patch_file.patch

# 作業ツリーに触れずにステージする
git apply --cached -v patch_file.patch

# ref 間の差分をそのまま当てる
git diff main...HEAD -- <file> | git apply -v
```

hunk の一部だけをステージしたいときは、`git diff -- <file>` の出力から必要な hunk だけを残したパッチを作り、`git apply --cached -v` に渡す。

## よく使うフラグ

- `-v`, `--verbose`: 詳しい結果を出す。常に付ける
- `--check`: 変更せずに、きれいに当たるかだけ確かめる
- `--cached`: 作業ツリーに触れずにステージする
- `--stat`: 当てる前に影響するファイルを表示する
- `--whitespace=fix`: 行末の空白を自動で直す
- `--reject`: 当たらなかった部分を `.rej` ファイルに出し、全体を中止しない
- `--reverse` / `-R`: 当てたパッチを元に戻す

## 当たらないときの対処

行末の空白:

```sh
git apply --check --whitespace=fix patch_file.patch
git apply --whitespace=fix -v patch_file.patch
```

一部だけ失敗する:

```sh
git apply --reject -v patch_file.patch
```

前後の文脈が合わない:

```sh
git apply --ignore-whitespace -v patch_file.patch
```

改行コードの違い:

```sh
git apply --ignore-space-change -v patch_file.patch
```

## git apply と git am の違い

- `git apply`: コミットを作らずに、変更を当てるかステージする
- `git am`: コミットメッセージと作者情報ごとパッチを当てる

コミットの作成を自分で制御するため、このスキルでは `git apply -v` を使う。
