# revert できるコミットの例

## 良い例: 独立した実装の段階ごとに分ける

```text
feat(auth): add RefreshTokenService class

Added RefreshTokenService to handle token lifecycle management.
This service generates and invalidates refresh tokens with
configurable expiry periods.
```

```text
feat(auth): integrate token rotation in middleware

Updated auth middleware to call RefreshTokenService when validating
tokens. This can be reverted independently without removing the
service itself.
```

2 つ目だけを revert しても、1 つ目のサービスは残って動く。

## 良い例: 移動の両側を 1 つのコミットにまとめる

1 つのコミットに次をすべて入れる。

- `A agents/skills/tdd/references/vitest-example.md`
- `M agents/skills/tdd/SKILL.md`
- `D agents/skills/tdd/vitest-example.md`

小さいが完結している。古いパスが消え、新しいパスが追加され、参照もすべて新しいパスを指している。

## 悪い例: 1 つの移動を不完全なコミットに分ける

1 つ目のコミット:

- `A agents/skills/tdd/references/vitest-example.md`

2 つ目のコミット:

- `M agents/skills/tdd/SKILL.md`
- `D agents/skills/tdd/vitest-example.md`

1 つ目のコミットは単独では revert できない。2 つ目が入るまで、内容が重複したり、どこからも参照されないファイルが残ったりする。

## 良い例: レビューコメント 1 つにつき 1 コミット

「型チェックとテストの前に format を走らせて」と指摘されたら、その手順の文言と、それに対応する箇所だけを 1 つのコミットで直す。関係ない例の修正や誤字の修正は別のコミットにする。

## 悪い例: まとめて整理したコミット

次をまとめたコミットは避ける。

- PR レビューの手順の変更
- TypeScript の型アサーションの指針
- データソースの修正
- Markdown のコードフェンスの整形
- 生成された symlink の同期

どれも正しい変更でも、1 つを revert すると関係ない変更まで戻ってしまう。
