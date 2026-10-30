# 根本原因をさかのぼる

バグはコールスタックの深いところで表に出ることが多い (間違ったディレクトリでの `git init`、間違った場所に作られたファイル、間違ったパスで開かれた DB など)。エラーが出た場所を直したくなるが、それは症状への対処にすぎない。

**原則: 呼び出しの連鎖を最初のきっかけまでさかのぼり、発生源で直す。**

## 使う場面

- エラーが入口ではなく、実行の深いところで起きている
- スタックトレースの呼び出しの連鎖が長い
- おかしなデータがどこで生まれたか分からない
- どのテストやコードが問題を起こしているか突き止めたい

さかのぼれないとき (行き止まり) だけ、症状が出た場所で直す。さかのぼれたら、発生源で直したうえで [`defense-in-depth.md`](defense-in-depth.md) の多層の検証も足す。

## さかのぼる手順

### 1. 症状を観察する
```
Error: git init failed in ~/project/packages/core
```

### 2. 直接の原因を見つける
これを直接起こしているコードはどれか。
```typescript
await execFileAsync('git', ['init'], { cwd: projectDir });
```

### 3. 誰が呼んだかを調べる
```typescript
WorktreeManager.createSessionWorktree(projectDir, sessionId)
  → Session.initializeWorkspace() から呼ばれる
  → Session.create() から呼ばれる
  → テストの Project.create() から呼ばれる
```

### 4. さらにさかのぼる
どんな値が渡されたか。
- `projectDir = ''` (空文字列)
- `cwd` に空文字列を渡すと `process.cwd()` になる
- つまりソースコードのディレクトリで実行されている

### 5. 最初のきっかけを見つける
空文字列はどこから来たか。
```typescript
const context = setupCoreTest(); // { tempDir: '' } を返す
Project.create('name', context.tempDir); // beforeEach より前に参照している
```

## スタックトレースを仕込む

手でさかのぼれないときは、診断用の出力を入れる。

```typescript
async function gitInit(directory: string) {
  const stack = new Error().stack;
  console.error('DEBUG git init:', {
    directory,
    cwd: process.cwd(),
    nodeEnv: process.env.NODE_ENV,
    stack,
  });

  await execFileAsync('git', ['init'], { cwd: directory });
}
```

実行して拾う:
```bash
npm test 2>&1 | grep 'DEBUG git init'
```

スタックトレースから次を読み取る。
- テストファイルの名前
- 呼び出しのきっかけになった行番号
- パターン (同じテストか、同じ引数か)

コツ:
- テストの中ではロガーではなく `console.error()` を使う。ロガーの出力は抑制されていることがある
- 失敗した後ではなく、危ない操作の前に出力する
- ディレクトリ、cwd、環境変数、時刻などの文脈も出す
- `new Error().stack` で呼び出しの連鎖をまるごと取れる

## どのテストが汚しているかを探す

テスト中に何かが作られるが、どのテストか分からないときは [`../scripts/find-polluter.sh`](../scripts/find-polluter.sh) を使う。テストを 1 つずつ実行し、最初に汚したテストで止まる。

```bash
bash scripts/find-polluter.sh '.git' 'src/**/*.test.ts'
```

## 実例: 空の projectDir

**症状:** ソースコードの `packages/core/` に `.git` が作られる

**さかのぼった連鎖:**
1. `git init` が `process.cwd()` で実行される ← cwd 引数が空
2. WorktreeManager に空の projectDir が渡される
3. Session.create() が空文字列を渡す
4. テストが beforeEach より前に `context.tempDir` を参照している
5. setupCoreTest() は最初 `{ tempDir: '' }` を返す

**根本原因:** トップレベルの変数初期化で、まだ空の値を参照していた

**修正:** beforeEach より前に参照したら例外を投げる getter に tempDir を変えた

**多層の防御も追加した:**
- 層 1: Project.create() がディレクトリを検証する
- 層 2: WorkspaceManager が空でないことを検証する
- 層 3: テスト中は tmpdir の外での `git init` を拒否する
- 層 4: `git init` の前にスタックトレースを出力する

## 要点

**エラーが出た場所だけを直さない。** 最初のきっかけまでさかのぼって発生源で直し、さらに各層に検証を足して、そのバグが起こりえない状態にする。
