# 多層の検証

おかしなデータが原因のバグを直すとき、検証を 1 か所に足せば十分に思える。しかしその 1 か所は、別のコードパスやリファクタリング、モックで簡単にすり抜けられる。

**原則: データが通るすべての層で検証し、そのバグが構造的に起こりえないようにする。**

1 か所の検証は「バグを直した」。複数の層の検証は「バグを起こせなくした」。層ごとに拾えるものが違う。

- 入口の検証で、ほとんどのバグを拾う
- 業務ロジックの検証で、端のケースを拾う
- 環境のガードで、特定の状況での危険を防ぐ
- デバッグ用の出力で、他の層がすり抜けたときに原因を追える

## 4 つの層

### 層 1: 入口での検証
API の境界で、明らかにおかしな入力を弾く。

```typescript
function createProject(name: string, workingDirectory: string) {
  if (!workingDirectory || workingDirectory.trim() === '') {
    throw new Error('workingDirectory cannot be empty');
  }
  if (!existsSync(workingDirectory)) {
    throw new Error(`workingDirectory does not exist: ${workingDirectory}`);
  }
  if (!statSync(workingDirectory).isDirectory()) {
    throw new Error(`workingDirectory is not a directory: ${workingDirectory}`);
  }
  // ...
}
```

### 層 2: 業務ロジックでの検証
その操作にとって筋の通ったデータかを確かめる。

```typescript
function initializeWorkspace(projectDir: string, sessionId: string) {
  if (!projectDir) {
    throw new Error('projectDir required for workspace initialization');
  }
  // ...
}
```

### 層 3: 環境のガード
特定の状況で危険な操作を止める。

```typescript
async function gitInit(directory: string) {
  if (process.env.NODE_ENV === 'test') {
    const normalized = normalize(resolve(directory));
    const tmpDir = normalize(resolve(tmpdir()));

    if (!normalized.startsWith(tmpDir)) {
      throw new Error(
        `Refusing git init outside temp dir during tests: ${directory}`
      );
    }
  }
  // ...
}
```

### 層 4: デバッグ用の出力
後から調べるための文脈を残す。

```typescript
async function gitInit(directory: string) {
  const stack = new Error().stack;
  logger.debug('About to git init', {
    directory,
    cwd: process.cwd(),
    stack,
  });
  // ...
}
```

## 当てはめ方

バグを見つけたら:

1. **データの流れを追う**: おかしな値はどこで生まれ、どこで使われるか
2. **通過点をすべて挙げる**: データが通る場所を全部書き出す
3. **各層に検証を足す**: 入口、業務ロジック、環境、デバッグ
4. **各層を試す**: 層 1 をすり抜けさせて、層 2 が拾うか確かめる

## 実例

バグ: 空の `projectDir` のせいで、ソースコードのディレクトリで `git init` が実行された

**データの流れ:**
1. テストのセットアップ → 空文字列
2. `Project.create(name, '')`
3. `WorkspaceManager.createWorkspace('')`
4. `git init` が `process.cwd()` で実行される

**足した 4 つの層:**
- 層 1: `Project.create()` が空でない・存在する・書き込めることを検証
- 層 2: `WorkspaceManager` が projectDir が空でないことを検証
- 層 3: `WorktreeManager` がテスト中は tmpdir の外での `git init` を拒否
- 層 4: `git init` の前にスタックトレースを出力

4 つとも必要だった。テストの中で、それぞれの層が他の層の見逃したバグを拾った。

- 別のコードパスが入口の検証をすり抜けた
- モックが業務ロジックの検証をすり抜けた
- プラットフォームごとの端のケースには環境のガードが要った
- デバッグ用の出力で、構造的な誤用が見つかった

**検証を 1 か所で終わらせない。** すべての層に足す。
