import assert from "node:assert/strict";
import { test } from "node:test";
import { registerHooks } from "node:module";
import { accountIdFromToken, createMonitor, fetchUsage, formatUsage, parseUsage, UsageError } from "./usage.mjs";

const now = 1800000000000;
const window = (used = 25, seconds = 18000) => ({ used_percent: used, limit_window_seconds: seconds, reset_at: now / 1000 + 7200 });
const payload = () => ({ rate_limit: { primary_window: window(), secondary_window: window(42, 604800) } });
const token = `header.${Buffer.from(JSON.stringify({ "https://api.openai.com/auth": { chatgpt_account_id: "account-123" } })).toString("base64url")}.signature`;
const signal = () => new AbortController().signal;
const flush = () => new Promise((resolve) => setImmediate(resolve));

function fakeTimers() {
  let id = 0;
  const intervals = new Map();
  const timeouts = new Map();
  return {
    intervals, timeouts,
    setInterval(fn, ms) { intervals.set(++id, { fn, ms }); return id; },
    clearInterval(id) { intervals.delete(id); },
    setTimeout(fn, ms) { timeouts.set(++id, { fn, ms }); return id; },
    clearTimeout(id) { timeouts.delete(id); },
  };
}

test("extracts only a Codex account token", () => {
  assert.equal(accountIdFromToken(token), "account-123");
  for (const invalid of ["sk-api-key", "a.e30.b", "a.!!!.b", ""]) {
    assert.throws(() => accountIdFromToken(invalid), /認証が必要/);
  }
});

test("parses windows by actual duration, including weekly-only primary", () => {
  const windows = parseUsage(payload());
  assert.deepEqual(windows.map((w) => w.used), [25, 42]);
  assert.equal(windows[0].resetAt, now + 7200000);
  const weekly = parseUsage({ rate_limit: { primary_window: window(10, 604800) } });
  assert.match(formatUsage({ windows: weekly }, now).text, /週: 残り 90%/);
  assert.match(formatUsage({ windows }, now).text, /5h: 残り 75%.*週: 残り 58%/);
});

test("rejects missing and malformed quotas instead of showing unused quota", () => {
  for (const invalid of [null, {}, { rate_limit: {} }]) {
    assert.throws(() => parseUsage(invalid), /ありません/);
  }
  for (const patch of [
    { used_percent: "25" }, { used_percent: -1 }, { used_percent: 101 },
    { used_percent: NaN }, { reset_at: null }, { limit_window_seconds: 0 },
  ]) {
    assert.throws(() => parseUsage({ rate_limit: { primary_window: { ...window(), ...patch } } }), /形式が不正/);
  }
});

test("expired values are not presented as current remaining quota", () => {
  const windows = parseUsage(payload());
  const expired = formatUsage({ windows }, now + 7200000);
  assert.match(expired.text, /更新待ち/);
  assert.doesNotMatch(expired.text, /残り/);
  assert.equal(formatUsage({ windows: parseUsage({ rate_limit: { primary_window: window(95) } }) }, now).color, "error");
  assert.equal(formatUsage({ windows: parseUsage({ rate_limit: { primary_window: window(75) } }) }, now).color, "warning");
});

test("fetches usage only from the fixed origin and refuses redirects", async () => {
  const result = await fetchUsage(token, signal(), async (url, options) => {
    assert.equal(url, "https://chatgpt.com/backend-api/wham/usage");
    assert.equal(options.redirect, "error");
    assert.equal(options.headers.Authorization, `Bearer ${token}`);
    assert.equal(options.headers["ChatGPT-Account-Id"], "account-123");
    return Response.json(payload());
  });
  assert.equal(result.length, 2);
  let called = false;
  await assert.rejects(fetchUsage("sk-key", signal(), () => { called = true; }), /認証が必要/);
  assert.equal(called, false);
});

test("handles HTTP, invalid JSON, and oversized bodies without leaking content", async () => {
  for (const status of [401, 403, 429, 500]) {
    await assert.rejects(fetchUsage(token, signal(), async () => new Response("secret", { status })), status === 401 || status === 403 ? /再認証/ : /HTTP/);
  }
  await assert.rejects(fetchUsage(token, signal(), async () => new Response("secret")), /形式が不正/);
  await assert.rejects(fetchUsage(token, signal(), async () => new Response("x".repeat(65537))), /大きすぎ/);
});

test("shares in-flight requests and refreshes network/display on separate timers", async () => {
  const timers = fakeTimers();
  const displays = [];
  let calls = 0;
  let release;
  const monitor = createMonitor({
    timers, now: () => now,
    load: () => { calls++; return new Promise((resolve) => { release = resolve; }); },
    render: (display) => displays.push(display),
  });
  const first = monitor.refresh();
  assert.equal(monitor.refresh(), first);
  await flush();
  assert.equal(calls, 1);
  release(parseUsage(payload()));
  await first;
  assert.match(displays.at(-1).text, /残り 75%/);
  assert.equal(timers.timeouts.size, 0);
  [...timers.intervals.values()].find((t) => t.ms === 60000).fn();
  assert.equal(calls, 1);
  [...timers.intervals.values()].find((t) => t.ms === 300000).fn();
  await flush();
  assert.equal(calls, 2);
  monitor.dispose();
  await flush();
  assert.equal(timers.intervals.size, 0);
  assert.equal(timers.timeouts.size, 0);
});

test("failure hides old percentages and keeps last successful timestamp", async () => {
  let fail = false;
  const displays = [];
  const monitor = createMonitor({
    timers: fakeTimers(), now: () => now,
    load: async () => {
      if (fail) throw new Error(`sensitive token ${token}`);
      return parseUsage(payload());
    },
    render: (display) => displays.push(display),
  });
  await monitor.refresh();
  fail = true;
  await monitor.refresh();
  assert.match(displays.at(-1).text, /取得失敗.*最終取得/);
  assert.doesNotMatch(displays.at(-1).text, /残り|sensitive|signature/);
  monitor.dispose();
});

test("timeout also bounds a credential resolver that ignores abort", async () => {
  const timers = fakeTimers();
  let last;
  let requestSignal;
  const monitor = createMonitor({
    timers, load: (signal) => { requestSignal = signal; return new Promise(() => {}); },
    render: (display) => { last = display; },
  });
  const request = monitor.refresh();
  await flush();
  [...timers.timeouts.values()][0].fn();
  await request;
  assert.equal(requestSignal.aborted, true);
  assert.match(last.text, /タイムアウト/);
  monitor.dispose();
  assert.equal(timers.timeouts.size, 0);
});

test("shutdown cancels work, removes timers, and never updates a replaced widget", async () => {
  const timers = fakeTimers();
  let updates = 0;
  let release;
  const monitor = createMonitor({
    timers, load: () => new Promise((resolve) => { release = resolve; }),
    render: () => updates++,
  });
  const request = monitor.refresh();
  await flush();
  monitor.dispose();
  monitor.dispose();
  await request;
  const before = updates;
  release(parseUsage(payload()));
  await flush();
  assert.equal(updates, before);
  assert.equal(timers.intervals.size, 0);
  assert.equal(timers.timeouts.size, 0);
  await monitor.refresh();
  assert.equal(updates, before);
});

test("Pi adapter displays above editor, resolves Codex auth independently of active model, and cleans up", async (t) => {
  const hook = registerHooks({
    resolve(specifier, context, nextResolve) {
      if (specifier === "@earendil-works/pi-tui") {
        return { url: "data:text/javascript,export const truncateToWidth = (text, width) => text.slice(0, width)", shortCircuit: true };
      }
      return nextResolve(specifier, context);
    },
  });
  let setup;
  try { setup = (await import("./index.ts")).default; }
  finally { hook.deregister(); }
  const previousFetch = globalThis.fetch;
  const previousEnv = process.env.PI_CODEX_USAGE;
  t.after(() => {
    globalThis.fetch = previousFetch;
    if (previousEnv === undefined) delete process.env.PI_CODEX_USAGE;
    else process.env.PI_CODEX_USAGE = previousEnv;
  });
  delete process.env.PI_CODEX_USAGE;
  const handlers = new Map();
  const commands = new Map();
  setup({
    on: (event, handler) => handlers.set(event, handler),
    registerCommand: (name, command) => commands.set(name, command),
  });
  t.after(() => handlers.get("session_shutdown")());
  let calls = 0;
  let redraws = 0;
  let component;
  const ctx = {
    mode: "rpc", model: { provider: "openai" },
    modelRegistry: { getApiKeyForProvider: async (provider) => {
      assert.equal(provider, "openai-codex");
      calls++;
      return token;
    } },
    ui: {
      setWidget: (key, factory, options) => {
        assert.equal(key, "codex-usage");
        assert.equal(options.placement, "aboveEditor");
        component = factory({ requestRender: () => redraws++ }, { fg: (_color, text) => text });
      },
      notify() {},
    },
  };
  globalThis.fetch = async () => Response.json(payload());
  handlers.get("session_start")({}, ctx);
  await flush();
  assert.equal(calls, 0);
  ctx.mode = "tui";
  process.env.PI_CODEX_USAGE = "0";
  handlers.get("session_start")({}, ctx);
  await flush();
  assert.equal(calls, 0);
  delete process.env.PI_CODEX_USAGE;
  handlers.get("session_start")({}, ctx);
  await commands.get("codex-usage").handler("", ctx);
  assert.equal(calls, 1);
  assert.match(component.render(200)[0], /Codex.*残り 75%/);
  assert.equal(component.render(20)[0].length, 20);
  assert.ok(redraws > 0);
  handlers.get("session_shutdown")();
  await commands.get("codex-usage").handler("", ctx);
  assert.equal(calls, 1);
  handlers.get("session_start")({}, ctx);
  await commands.get("codex-usage").handler("", ctx);
  assert.equal(calls, 2);
});

test("missing login is actionable and retryable", async () => {
  let loggedIn = false;
  let last;
  const monitor = createMonitor({
    timers: fakeTimers(), now: () => now,
    load: async () => {
      if (!loggedIn) throw new UsageError("Codex 認証が必要です (/login)");
      return parseUsage(payload());
    },
    render: (display) => { last = display; },
  });
  await monitor.refresh();
  assert.match(last.text, /\/login/);
  loggedIn = true;
  await monitor.refresh();
  assert.match(last.text, /残り 75%/);
  monitor.dispose();
});
