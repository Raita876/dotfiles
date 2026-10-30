# 条件で待つ

不安定なテストは、決め打ちの待ち時間でタイミングを当てにしていることが多い。速いマシンでは通るが、負荷がかかったときや CI では落ちる競合状態になる。

**原則: かかりそうな時間を推測して待つのではなく、本当に待ちたい条件が満たされるのを待つ。**

## 使う場面

- テストに決め打ちの待ち (`setTimeout`、`sleep`、`time.sleep()`) がある
- テストが不安定 (通ったり、負荷がかかると落ちたりする)
- 並列実行するとタイムアウトする
- 非同期の処理が終わるのを待っている

**使わない場面:**
- タイミングそのものをテストしている (debounce や throttle の間隔など)
- その場合も、決め打ちの待ち時間にはなぜ必要かを必ず書く

## 基本の形

```typescript
// ❌ 前: タイミングを推測している
await new Promise(r => setTimeout(r, 50));
const result = getResult();
expect(result).toBeDefined();

// ✅ 後: 条件を待つ
await waitFor(() => getResult() !== undefined, 'result');
const result = getResult();
expect(result).toBeDefined();
```

## よくある形

| 場面 | 書き方 |
|---|---|
| イベントを待つ | `waitFor(() => events.find(e => e.type === 'DONE'), 'DONE event')` |
| 状態を待つ | `waitFor(() => machine.state === 'ready', 'ready state')` |
| 件数を待つ | `waitFor(() => items.length >= 5, '5 items')` |
| ファイルを待つ | `waitFor(() => fs.existsSync(path), path)` |
| 複合条件 | `waitFor(() => obj.ready && obj.value > 10, 'obj ready')` |

## 実装

汎用のポーリング関数:

```typescript
async function waitFor<T>(
  condition: () => T | undefined | null | false,
  description: string,
  timeoutMs = 5000
): Promise<T> {
  const startTime = Date.now();

  while (true) {
    const result = condition();
    if (result) return result;

    if (Date.now() - startTime > timeoutMs) {
      throw new Error(`Timeout waiting for ${description} after ${timeoutMs}ms`);
    }

    await new Promise(r => setTimeout(r, 10));
  }
}
```

## よくある間違い

- **間隔が短すぎる** (`setTimeout(check, 1)`): CPU を無駄にする。10ms 間隔で十分
- **タイムアウトが無い**: 条件が満たされないと永遠に待つ。分かりやすいエラーつきのタイムアウトを必ず付ける
- **古いデータを見ている**: ループの前に状態を取り出している。ループの中で毎回取り直す

## 決め打ちの待ち時間が正しい場合

```typescript
// ツールは 100ms ごとに tick する。途中の出力を確かめるには 2 tick 必要
await waitForEvent(manager, 'TOOL_STARTED'); // 先にきっかけの条件を待つ
await new Promise(r => setTimeout(r, 200));   // その後でタイミングに依存する挙動を待つ
```

条件:
1. 先にきっかけの条件を待つ
2. 推測ではなく、分かっているタイミングに基づく
3. なぜその時間なのかをコメントに書く
