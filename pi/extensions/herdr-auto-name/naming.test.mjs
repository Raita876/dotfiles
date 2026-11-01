import assert from "node:assert/strict";
import { createServer } from "node:net";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import setup from "./index.ts";
import { createBridge, LABEL, request } from "./bridge.mjs";
import { conversation, createNamer, INTERVAL, titleFrom } from "./naming.mjs";

function fixture(overrides = {}) {
  let clock = 100_000;
  let target = { space: "s1", tab: "tab1", name: "", previous: null };
  const calls = [];
  const bridge = {
    inspect: async () => structuredClone(target),
    rename: async (space, title) => { calls.push([space, title]); target.name = title; },
    remember: async (previous) => { target.previous = previous; },
  };
  const errors = [];
  const namer = createNamer({ bridge, summarize: async () => "認証エラーの修正", now: () => clock,
    report: (error) => errors.push(error), ...overrides });
  return { namer, bridge, calls, errors, get target() { return target; },
    set target(value) { target = value; }, tick: () => { clock += INTERVAL; } };
}

test("text extraction excludes tools, thinking, images and incomplete responses", () => {
  const entries = [
    { type: "custom", data: "secret" },
    { type: "message", message: { role: "toolResult", content: "secret" } },
    { type: "message", message: { role: "user", content: [{ type: "text", text: "fix login" }, { type: "image", data: "secret" }] } },
    { type: "message", message: { role: "assistant", stopReason: "stop", content: [
      { type: "thinking", thinking: "secret" }, { type: "text", text: "fixed" },
    ] } },
  ];
  assert.equal(conversation(entries), "user: fix login\n\nassistant: fixed");
  entries.at(-1).message.stopReason = "aborted";
  assert.equal(conversation(entries), "");
});

test("conversation length is bounded", () => {
  const entries = Array.from({ length: 20 }, () => ({ type: "message", message: {
    role: "assistant", stopReason: "stop", content: [{ type: "text", text: "x".repeat(10_000) }],
  } }));
  assert.ok(conversation(entries).length < 12_100);
});

test("only short plain titles are accepted", () => {
  assert.equal(titleFrom("「ログインの修正」"), "ログインの修正");
  for (const text of ["", "a\nb", "a\u001bb", "a\u200bb", "x".repeat(61), "<title>", "`title`", null]) {
    assert.equal(titleFrom(text), null);
  }
});

test("names by explicit Space ID, persists provenance, throttles and updates", async () => {
  const f = fixture();
  await f.namer.run("first conversation");
  assert.deepEqual(f.calls, [["s1", "認証エラーの修正"]]);
  assert.equal(f.target.previous.title, f.target.name);
  await f.namer.run("second conversation");
  assert.equal(f.calls.length, 1);
  f.tick();
  await f.namer.run("first conversation");
  assert.equal(f.calls.length, 1);
  f.tick();
  await f.namer.run("second conversation");
  assert.equal(f.target.previous.at, 220_000);
  assert.equal(f.calls.length, 1);
});

test("existing manual names and malformed provenance are left alone", async () => {
  for (const previous of [null, {}, { space: "other", title: "manual" }]) {
    let generated = false;
    const f = fixture({ summarize: async () => { generated = true; return "auto"; } });
    f.target = { ...f.target, name: "manual", previous };
    await f.namer.run("context");
    assert.equal(generated, false);
    assert.deepEqual(f.calls, []);
  }
});

test("manual changes during generation are not overwritten", async () => {
  let f;
  f = fixture({ summarize: async () => { f.target.name = "user title"; return "auto"; } });
  await f.namer.run("context");
  assert.deepEqual(f.calls, []);
});

test("tab switches, Space removal and target changes discard pending names", async () => {
  for (const change of [() => null, (target) => ({ ...target, space: "s2" }), (target) => ({ ...target, tab: "tab2" })]) {
    let f;
    f = fixture({ summarize: async () => { f.target = change(f.target); return "auto"; } });
    await f.namer.run("context");
    assert.deepEqual(f.calls, []);
  }
});

test("new input or session shutdown cancels late results, without concurrent calls", async () => {
  let finish;
  let count = 0;
  const f = fixture({ summarize: () => { count++; return new Promise((resolve) => { finish = resolve; }); } });
  const pending = f.namer.run("context");
  await new Promise((resolve) => setImmediate(resolve));
  await f.namer.run("another context");
  assert.equal(count, 1);
  f.namer.cancel();
  finish("stale title");
  await pending;
  assert.deepEqual(f.calls, []);
});

test("failures are reported and retried no more than once per minute", async () => {
  const f = fixture({ summarize: async () => { throw new Error("offline"); } });
  await f.namer.run("context");
  await f.namer.run("context");
  assert.equal(f.errors.length, 1);
  assert.deepEqual(f.calls, []);
  f.tick();
  await f.namer.run("context");
  assert.equal(f.errors.length, 2);
});

test("clearing a manual name re-enables naming; persisted auto names survive reload", async () => {
  const f = fixture();
  f.target.name = "manual";
  await f.namer.run("context");
  f.target.name = "";
  await f.namer.run("context");
  assert.equal(f.calls.length, 1);
  f.tick();
  const reloaded = createNamer({ bridge: f.bridge, summarize: async () => "新しい作業", now: () => 300_000 });
  await reloaded.run("new context");
  assert.deepEqual(f.calls.at(-1), ["s1", "新しい作業"]);
});

async function server(t, path, respond) {
  const sockets = new Set();
  const instance = createServer((socket) => {
    sockets.add(socket);
    socket.on("close", () => sockets.delete(socket));
    socket.on("error", () => {});
    socket.setEncoding("utf8");
    let buffer = "";
    socket.on("data", (chunk) => {
      buffer += chunk;
      if (buffer.includes("\n")) respond(JSON.parse(buffer.split("\n")[0]), socket);
    });
  });
  await new Promise((resolve) => instance.listen(path, resolve));
  t.after(async () => {
    for (const socket of sockets) socket.destroy();
    await new Promise((resolve) => instance.close(resolve));
  });
}

async function directory(t) {
  const path = await mkdtemp(join(tmpdir(), "herdr-name-"));
  t.after(() => rm(path, { recursive: true, force: true }));
  return path;
}

test("bridge maps terminal labels to local active tab, reads raw names and writes provenance", async (t) => {
  const home = await directory(t);
  const coreSocket = join(home, "core.sock");
  let parent = null;
  let active = true;
  let machine = null;
  let leader = "t1";
  let labels = { "herdr.space": "s1", "herdr.tab": "tab1" };
  const commands = [];
  await server(t, coreSocket, (req, socket) => {
    let result;
    if (req.method === "terminal.get") result = { parent, labels };
    else if (req.method === "doc.get") result = { value: { spaces: [{ id: "s1", name: "" }] } };
    else if (req.method === "terminal.label") { labels = { ...labels, ...req.params.labels }; result = {}; }
    socket.end(`${JSON.stringify({ jsonrpc: "2.0", id: req.id, result })}\n`);
  });
  await server(t, join(home, "herdr-app.sock"), (req, socket) => {
    if (req.ls) socket.end(`${JSON.stringify({ spaces: [{ id: "s1", machine, tabs: [
      { id: "tab1", active, terminals: [{ terminal: leader, app: "pi" }, { terminal: "t1", app: "pi" }] },
    ] }] })}\n`);
    else { commands.push(req); socket.end("{\"ok\":true}\n"); }
  });
  assert.equal(createBridge({}), null);
  const bridge = createBridge({ HC_TERMINAL_ID: "t1", HC_TERMINAL_SOCKET: coreSocket, HERDR_APP_HOME: home });
  assert.equal((await bridge.inspect()).name, "");
  await bridge.rename("s1", "認証の修正");
  assert.deepEqual(commands, [{ do: "space.rename", args: { id: "s1", name: "認証の修正" } }]);
  await bridge.remember({ space: "s1", title: "認証の修正" });
  assert.equal(JSON.parse(labels[LABEL]).title, "認証の修正");
  parent = "t0";
  assert.equal(await bridge.inspect(), null);
  parent = null;
  active = false;
  assert.equal(await bridge.inspect(), null);
  active = true;
  machine = "remote";
  assert.equal(await bridge.inspect(), null);
  machine = null;
  leader = "other-pi";
  assert.equal(await bridge.inspect(), null);
});

test("socket requests handle UTF-8 split across chunks and protocol errors", async (t) => {
  const home = await directory(t);
  const path = join(home, "app.sock");
  await server(t, path, (req, socket) => {
    if (req.error) return socket.end('{"error":"unavailable"}\n');
    if (req.invalid) return socket.end("not json\n");
    const data = Buffer.from('{"name":"修正"}\n');
    socket.write(data.subarray(0, 10));
    setImmediate(() => socket.end(data.subarray(10)));
  });
  assert.deepEqual(await request(path, {}), { name: "修正" });
  await assert.rejects(request(path, { error: true }), /failed/);
  await assert.rejects(request(path, { invalid: true }), SyntaxError);
});

test("socket requests time out, abort and tolerate a closed app", async (t) => {
  const home = await directory(t);
  const path = join(home, "app.sock");
  await server(t, path, () => {});
  await assert.rejects(request(path, {}, undefined, 20), /timed out/);
  const controller = new AbortController();
  const pending = request(path, {}, controller.signal);
  controller.abort();
  await assert.rejects(pending, /cancelled/);
  await assert.rejects(request(join(home, "missing.sock"), {}));
});

test("Pi lifecycle runs tool-free naming in the background, only in Herdr TUI", async (t) => {
  const home = await directory(t);
  const savedEnv = { ...process.env };
  t.after(() => {
    for (const name of ["HC_TERMINAL_ID", "HC_TERMINAL_SOCKET", "HERDR_APP_HOME", "PI_HERDR_AUTO_NAME"]) {
      if (savedEnv[name] === undefined) delete process.env[name];
      else process.env[name] = savedEnv[name];
    }
  });
  process.env.HC_TERMINAL_ID = "t1";
  process.env.HC_TERMINAL_SOCKET = join(home, "core.sock");
  process.env.HERDR_APP_HOME = home;
  delete process.env.PI_HERDR_AUTO_NAME;
  let name = "";
  let labels = { "herdr.space": "s1", "herdr.tab": "tab1" };
  let remembered;
  const completed = new Promise((resolve) => { remembered = resolve; });
  await server(t, process.env.HC_TERMINAL_SOCKET, (req, socket) => {
    let result;
    if (req.method === "terminal.get") result = { parent: null, labels };
    else if (req.method === "doc.get") result = { value: { spaces: [{ id: "s1", name }] } };
    else if (req.method === "terminal.label") {
      labels = { ...labels, ...req.params.labels }; result = {}; remembered();
    }
    socket.end(`${JSON.stringify({ jsonrpc: "2.0", id: req.id, result })}\n`);
  });
  await server(t, join(home, "herdr-app.sock"), (req, socket) => {
    if (req.ls) socket.end(`${JSON.stringify({ spaces: [{ id: "s1", machine: null, tabs: [
      { id: "tab1", active: true, terminals: [{ terminal: "t1", app: "pi" }] },
    ] }] })}\n`);
    else { assert.equal(req.args.id, "s1"); name = req.args.name; socket.end('{"ok":true}\n'); }
  });
  const handlers = new Map();
  setup({ on: (event, handler) => handlers.set(event, handler) });
  let count = 0;
  let finish;
  const ctx = {
    mode: "rpc", model: { id: "stub" },
    sessionManager: { getBranch: () => [{ type: "message", message: {
      role: "assistant", stopReason: "stop", content: [{ type: "text", text: "fixed login" }],
    } }] },
    ui: { notify: () => assert.fail("unexpected warning") },
    modelRegistry: { streamSimple: (model, context, options) => {
      count++;
      assert.equal(model, ctx.model);
      assert.equal(context.tools, undefined);
      assert.equal(context.messages.length, 1);
      assert.equal(options.maxTokens, 512);
      assert.ok(options.signal instanceof AbortSignal);
      return { result: () => new Promise((resolve) => { finish = resolve; }) };
    } },
  };
  handlers.get("session_start")({}, ctx);
  handlers.get("agent_settled")({}, ctx);
  assert.equal(count, 0);
  ctx.mode = "tui";
  process.env.PI_HERDR_AUTO_NAME = "0";
  handlers.get("session_start")({}, ctx);
  handlers.get("agent_settled")({}, ctx);
  assert.equal(count, 0);
  delete process.env.PI_HERDR_AUTO_NAME;
  handlers.get("session_start")({}, ctx);
  assert.equal(handlers.get("agent_settled")({}, ctx), undefined);
  const deadline = Date.now() + 2000;
  while (!finish && Date.now() < deadline) await new Promise((resolve) => setTimeout(resolve, 5));
  assert.equal(count, 1);
  assert.equal(name, "");
  finish({ stopReason: "stop", content: [{ type: "text", text: "ログインの修正" }] });
  await completed;
  assert.equal(name, "ログインの修正");
  assert.equal(JSON.parse(labels[LABEL]).title, name);
  handlers.get("session_shutdown")({}, ctx);
});
