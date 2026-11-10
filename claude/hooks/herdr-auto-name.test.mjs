import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { chmod, mkdtemp, readdir, readFile, rm, symlink, utimes, writeFile } from "node:fs/promises";
import { createServer } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { conversation, generationOptions, handle, summarize } from "./herdr-auto-name.mjs";

async function directory(t) {
  const root = await mkdtemp(join(tmpdir(), "claude-name-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  return root;
}

function fixture(root, overrides = {}) {
  let target = { space: "s1", tab: "tab1", name: "", previous: null };
  const calls = [];
  const options = {
    root,
    env: { HC_TERMINAL_ID: "t1", HC_TERMINAL_SOCKET: "/test/core.sock" },
    bridge: {
      inspect: async () => structuredClone(target),
      rename: async (space, title) => { calls.push([space, title]); target.name = title; },
      remember: async (previous) => { target.previous = previous; },
    },
    generate: async () => "認証の修正",
    ...overrides,
  };
  return { options, calls, target, run: (input = {}) => handle({
    hook_event_name: "Stop", last_assistant_message: "fixed login", ...input,
  }, options) };
}

for (const entry of ["direct", "file symlink", "directory symlink chain"]) {
  test(`CLI handles stdin through ${entry}`, async (t) => {
    const root = await directory(t);
    const script = fileURLToPath(new URL("./herdr-auto-name.mjs", import.meta.url));
    let path = script;
    if (entry === "file symlink") {
      await symlink(script, join(root, "hook.mjs"));
      path = "./hook.mjs";
    } else if (entry === "directory symlink chain") {
      await symlink(fileURLToPath(new URL("../../", import.meta.url)), join(root, "home-manager-files"));
      await symlink("home-manager-files", join(root, "dotfiles"));
      path = "./dotfiles/claude/hooks/herdr-auto-name.mjs";
    }
    const terminal = "test-terminal";
    const socket = join(root, "unused.sock");
    const result = spawnSync(process.execPath, [path], {
      cwd: root,
      env: { ...process.env, CLAUDE_HERDR_AUTO_NAME: "1", XDG_CACHE_HOME: join(root, "cache"),
        HC_TERMINAL_ID: terminal, HC_TERMINAL_SOCKET: socket },
      input: JSON.stringify({ hook_event_name: "UserPromptSubmit" }),
      encoding: "utf8",
      timeout: 5000,
    });
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout, "");
    assert.equal(result.stderr, "");
    const key = createHash("sha256").update(`${socket}\0${terminal}`).digest("hex");
    const generation = await readFile(join(root, "cache/dotfiles/herdr-auto-name", key, "generation"), "utf8");
    assert.match(generation, /^[0-9a-f-]{36}$/);
  });
}

test("extracts bounded text only and uses authoritative final response", async (t) => {
  const root = await directory(t);
  const path = join(root, "transcript.jsonl");
  const entries = [
    ...Array.from({ length: 10 }, (_, i) => ({ type: "user", message: { role: "user", content: `old ${i}` } })),
    { type: "user", message: { role: "user", content: [{ type: "text", text: "fix login" }, { type: "image", data: "SECRET" }] } },
    { type: "user", message: { role: "user", content: [{ type: "tool_result", content: "SECRET" }] } },
    { type: "assistant", message: { role: "assistant", content: [{ type: "thinking", thinking: "SECRET" }] } },
    { type: "assistant", isSidechain: true, message: { role: "assistant", content: "SECRET" } },
    { type: "user", isMeta: true, message: { role: "user", content: "SECRET" } },
    { type: "assistant", message: { role: "assistant", content: [{ type: "text", text: "partial reply" }] } },
  ];
  await writeFile(path, entries.map(JSON.stringify).join("\n") + "\npartial JSON");
  const text = await conversation({ transcript_path: path, last_assistant_message: "fixed" });
  assert.ok(text.endsWith("user: fix login\n\nassistant: fixed"));
  assert.ok(!text.includes("SECRET") && !text.includes("partial reply"));
  assert.equal(text.split("\n\n").length, 6);
  assert.equal(await conversation({ last_assistant_message: "x".repeat(5000) }), `assistant: ${"x".repeat(2000)}`);
  assert.equal(await conversation({ transcript_path: path }), "");
  assert.equal(await conversation({ transcript_path: join(root, "missing"), last_assistant_message: "done" }), "assistant: done");
});

test("generation isolates customizations, tools, MCP, nested hooks and terminal identity", () => {
  const { args, env } = generationOptions({ CLAUDECODE: "1", HC_TERMINAL_ID: "t1", HC_TERMINAL_SOCKET: "sock", ANTHROPIC_API_KEY: "test" });
  for (const flag of ["--safe-mode", "--strict-mcp-config", "--no-session-persistence"]) assert.ok(args.includes(flag));
  assert.equal(args[args.indexOf("--tools") + 1], "");
  assert.equal(args[args.indexOf("--model") + 1], "haiku");
  assert.equal(env.CLAUDE_HERDR_AUTO_NAME, "0");
  assert.equal(env.CLAUDECODE, undefined);
  assert.equal(env.HC_TERMINAL_ID, undefined);
  assert.equal(env.HC_TERMINAL_SOCKET, undefined);
  assert.equal(env.ANTHROPIC_API_KEY, "test");
});

test("runs subprocess with prompt on stdin, validates result and aborts", async (t) => {
  const root = await directory(t);
  const command = join(root, "fake-claude");
  await writeFile(command, `#!${process.execPath}\nlet text = ''; for await (const chunk of process.stdin) text += chunk;
if (text === 'wait') setTimeout(() => {}, 10000);
else console.log(JSON.stringify({subtype: text === 'error' ? 'error' : 'success', result: '認証の修正'}));\n`);
  await chmod(command, 0o700);
  assert.equal(await summarize("fix login", undefined, {}, command), "認証の修正");
  assert.equal(await summarize("error", undefined, {}, command), "");
  const controller = new AbortController();
  const pending = summarize("wait", controller.signal, {}, command);
  controller.abort();
  await assert.rejects(pending, { name: "AbortError" });
});

test("default bridge targets the actual claude-code app and persists Claude provenance", async (t) => {
  const root = await directory(t);
  const env = { HC_TERMINAL_ID: "t1", HC_TERMINAL_SOCKET: join(root, "core.sock"), HERDR_APP_HOME: root };
  let labels = { "herdr.space": "s1", "herdr.tab": "tab1" };
  const commands = [];
  for (const [path, respond] of [
    [env.HC_TERMINAL_SOCKET, (req) => {
      let result;
      if (req.method === "terminal.get") result = { labels };
      if (req.method === "doc.get") result = { value: { spaces: [{ id: "s1", name: "" }] } };
      if (req.method === "terminal.label") { labels = { ...labels, ...req.params.labels }; result = {}; }
      return { jsonrpc: "2.0", id: req.id, result };
    }],
    [join(root, "herdr-app.sock"), (req) => {
      if (req.ls) return { spaces: [{ id: "s1", tabs: [{ id: "tab1", active: true,
        terminals: [{ app: "claude-code", terminal: "t1" }] }] }] };
      commands.push(req);
      return { ok: true };
    }],
  ]) {
    const instance = createServer((socket) => {
      let buffer = "";
      socket.on("error", () => {});
      socket.on("data", (chunk) => {
        buffer += chunk;
        if (buffer.includes("\n")) socket.end(`${JSON.stringify(respond(JSON.parse(buffer.split("\n")[0])))}\n`);
      });
    });
    await new Promise((resolve) => instance.listen(path, resolve));
    t.after(() => new Promise((resolve) => instance.close(resolve)));
  }
  await handle({ hook_event_name: "Stop", last_assistant_message: "fixed" }, {
    root: join(root, "cache"), env, generate: async () => "認証の修正",
  });
  assert.deepEqual(commands, [{ do: "space.rename", args: { id: "s1", name: "認証の修正" } }]);
  assert.equal(JSON.parse(labels["dotfiles.claude-auto-name"]).title, "認証の修正");
});

test("persists throttle across processes and leaves manual names alone", async (t) => {
  const root = await directory(t);
  const f = fixture(root);
  await f.run();
  assert.deepEqual(f.calls, [["s1", "認証の修正"]]);
  let generated = false;
  f.options.generate = async () => { generated = true; return "new"; };
  await f.run({ last_assistant_message: "different" });
  assert.equal(generated, false);
  const manual = fixture(await directory(t));
  manual.target.name = "手動名";
  await manual.run();
  assert.deepEqual(manual.calls, []);
});

test("skips outside Herdr, disabled naming, subagents and unrelated hooks", async (t) => {
  const root = await directory(t);
  for (const env of [{}, { HC_TERMINAL_ID: "t1" }, { HC_TERMINAL_ID: "t1", HC_TERMINAL_SOCKET: "sock", CLAUDE_HERDR_AUTO_NAME: "0" }]) {
    const f = fixture(root, { env });
    await f.run();
    assert.deepEqual(f.calls, []);
  }
  const f = fixture(root);
  await f.run({ hook_event_name: "SubagentStop" });
  await f.run({ agent_id: "child" });
  assert.deepEqual(f.calls, []);
  assert.deepEqual(await readdir(root), []);
});

test("serializes jobs and cancels late results on input or shutdown", async (t) => {
  for (const hook_event_name of ["UserPromptSubmit", "SessionEnd"]) {
    const root = await directory(t);
    let finish;
    let started;
    const ready = new Promise((resolve) => { started = resolve; });
    const f = fixture(root, { generate: (_text, signal) => new Promise((resolve) => {
      finish = resolve;
      signal.addEventListener("abort", () => resolve("late"), { once: true });
      started();
    }) });
    const pending = f.run();
    await ready;
    await f.run({ last_assistant_message: "concurrent" });
    await f.run({ hook_event_name });
    if (hook_event_name === "UserPromptSubmit") finish("late");
    await pending;
    assert.deepEqual(f.calls, []);
    const [key] = await readdir(root);
    assert.ok(!(await readdir(join(root, key))).includes("lock"));
  }
});

test("stale locks are recovered without removing live locks", async (t) => {
  const root = await directory(t);
  const f = fixture(root);
  await f.run({ hook_event_name: "UserPromptSubmit" });
  const [key] = await readdir(root);
  const lock = join(root, key, "lock");
  await writeFile(lock, "");
  await f.run();
  assert.deepEqual(f.calls, []);
  await utimes(lock, new Date(0), new Date(0));
  await f.run();
  assert.deepEqual(f.calls, []);
  await f.run();
  assert.deepEqual(f.calls, [["s1", "認証の修正"]]);
});

test("generation failures release locks and are throttled", async (t) => {
  const root = await directory(t);
  let count = 0;
  const f = fixture(root, { generate: async () => { count++; throw new Error("offline"); } });
  await f.run();
  await f.run();
  assert.equal(count, 1);
  assert.deepEqual(f.calls, []);
  const [key] = await readdir(root);
  assert.ok(Number(await readFile(join(root, key, "attempt"), "utf8")) > 0);
  assert.ok(!(await readdir(join(root, key))).includes("lock"));
});
