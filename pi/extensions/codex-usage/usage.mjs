const USAGE_URL = "https://chatgpt.com/backend-api/wham/usage";

export class UsageError extends Error {}

export function accountIdFromToken(token) {
  try {
    const payload = JSON.parse(Buffer.from(token.split(".")[1], "base64url").toString());
    const id = payload["https://api.openai.com/auth"]?.chatgpt_account_id;
    if (typeof id === "string" && id.trim()) return id;
  } catch {}
  throw new UsageError("Codex 認証が必要です (/login)");
}

export function parseUsage(data) {
  const windows = [];
  for (const key of ["primary_window", "secondary_window"]) {
    const value = data?.rate_limit?.[key];
    if (value == null) continue;
    const { used_percent: used, limit_window_seconds: seconds, reset_at: reset } = value;
    if (!Number.isFinite(used) || used < 0 || used > 100 ||
        !Number.isFinite(seconds) || seconds <= 0 ||
        !Number.isFinite(reset) || reset <= 0) {
      throw new UsageError("利用枠データの形式が不正です");
    }
    windows.push({ used, seconds, resetAt: reset * 1000 });
  }
  if (!windows.length) throw new UsageError("利用枠データがありません");
  return windows;
}

export async function fetchUsage(token, signal, fetcher = fetch) {
  const accountId = accountIdFromToken(token);
  signal.throwIfAborted();
  const response = await fetcher(USAGE_URL, {
    headers: { Authorization: `Bearer ${token}`, "ChatGPT-Account-Id": accountId },
    redirect: "error",
    signal,
  });
  if (!response.ok) {
    await response.body?.cancel();
    if (response.status === 401 || response.status === 403) {
      throw new UsageError("Codex 再認証が必要です (/login)");
    }
    throw new UsageError(`取得失敗 (HTTP ${response.status})`);
  }
  const reader = response.body?.getReader();
  if (!reader) throw new UsageError("利用枠データがありません");
  const chunks = [];
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > 65536) throw new UsageError("利用枠データが大きすぎます");
      chunks.push(Buffer.from(value));
    }
  } finally {
    await reader.cancel();
    reader.releaseLock();
  }
  try {
    return parseUsage(JSON.parse(Buffer.concat(chunks).toString("utf8")));
  } catch (error) {
    if (error instanceof UsageError) throw error;
    throw new UsageError("利用枠データの形式が不正です");
  }
}

function duration(milliseconds) {
  const minutes = Math.max(1, Math.ceil(milliseconds / 60000));
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h${minutes % 60}m`;
  return `${Math.floor(hours / 24)}d${hours % 24}h`;
}

/** @returns {{ text: string, color: "dim" | "muted" | "warning" | "error" }} */
export function formatUsage(state, now = Date.now()) {
  if (state.error) {
    const updated = state.updatedAt === undefined ? "" : ` · 最終取得 ${duration(now - state.updatedAt)}前`;
    return { text: `Codex  ${state.error}${updated}`, color: "warning" };
  }
  if (!state.windows) return { text: "Codex  利用枠を取得中…", color: "dim" };
  const parts = state.windows.map(({ used, seconds, resetAt }) => {
    const label = seconds === 604800 ? "週" : seconds % 3600 === 0 ? `${seconds / 3600}h` : `${Math.round(seconds / 60)}m`;
    if (resetAt <= now) return `${label}: 更新待ち`;
    return `${label}: 残り ${Math.round(100 - used)}% · ${duration(resetAt - now)}後リセット`;
  });
  const maximum = Math.max(...state.windows.filter((w) => w.resetAt > now).map((w) => w.used), 0);
  return { text: `Codex  ${parts.join(" | ")}`, color: maximum >= 90 ? "error" : maximum >= 70 ? "warning" : "muted" };
}

export function createMonitor({ load, render, now = Date.now, timers = globalThis }) {
  let state = {};
  let disposed = false;
  let inFlight;
  let controller;
  const draw = () => { if (!disposed) render(formatUsage(state, now())); };
  const refresh = () => {
    if (disposed) return Promise.resolve();
    if (inFlight) return inFlight;
    controller = new AbortController();
    const current = controller;
    let timeout;
    const deadline = new Promise((_, reject) => {
      current.signal.addEventListener("abort", () => reject(current.signal.reason), { once: true });
      timeout = timers.setTimeout(() => {
        current.abort(new UsageError("取得タイムアウト"));
      }, 10000);
    });
    inFlight = Promise.race([Promise.resolve().then(() => {
      current.signal.throwIfAborted();
      return load(current.signal);
    }), deadline])
      .then((windows) => { state = { windows, updatedAt: now() }; })
      .catch((error) => {
        state = { updatedAt: state.updatedAt, error: error instanceof UsageError ? error.message : "取得失敗 (通信または認証エラー)" };
      })
      .finally(() => {
        timers.clearTimeout(timeout);
        inFlight = undefined;
        draw();
      });
    return inFlight;
  };
  draw();
  const networkTimer = timers.setInterval(() => { void refresh(); }, 300000);
  const displayTimer = timers.setInterval(draw, 60000);
  void refresh();
  return {
    refresh,
    dispose() {
      disposed = true;
      controller?.abort();
      timers.clearInterval(networkTimer);
      timers.clearInterval(displayTimer);
    },
  };
}
