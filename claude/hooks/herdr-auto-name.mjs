import { execFile } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import { createReadStream } from "node:fs";
import { mkdir, open, readFile, rm, stat, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join, resolve } from "node:path";
import { createInterface } from "node:readline";
import { pathToFileURL } from "node:url";
import { promisify } from "node:util";
import { createBridge } from "../../herdr/auto-name/bridge.mjs";
import { createNamer, INTERVAL, SYSTEM_PROMPT } from "../../herdr/auto-name/naming.mjs";

const execute = promisify(execFile);
export const LABEL = "dotfiles.claude-auto-name";

export async function conversation(input) {
  if (typeof input.last_assistant_message !== "string" || !input.last_assistant_message.trim()) return "";
  const messages = [];
  if (typeof input.transcript_path === "string") {
    const stream = createReadStream(input.transcript_path, { encoding: "utf8" });
    const lines = createInterface({ input: stream, crlfDelay: Infinity });
    try {
      for await (const line of lines) {
        let entry;
        try { entry = JSON.parse(line); } catch { continue; }
        if (entry.isMeta || entry.isSidechain || !["user", "assistant"].includes(entry.type)) continue;
        const message = entry.message;
        if (!message || message.role !== entry.type) continue;
        const text = typeof message.content === "string" ? message.content : (message.content || [])
          .filter((part) => part.type === "text").map((part) => part.text).join("\n");
        if (!text.trim()) continue;
        const last = messages.at(-1);
        if (message.id && last?.id === message.id) last.text = `${last.text}\n${text}`.slice(-2000);
        else messages.push({ role: message.role, id: message.id, text: text.slice(0, 2000) });
        if (messages.length > 6) messages.shift();
      }
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
    } finally {
      lines.close();
      stream.destroy();
    }
  }
  // Stop の時点では transcript に最後の回答がまだ書かれていない場合がある。
  if (messages.at(-1)?.role === "assistant") messages.pop();
  messages.push({ role: "assistant", text: input.last_assistant_message.slice(0, 2000) });
  return messages.slice(-6).map(({ role, text }) => `${role}: ${text}`).join("\n\n");
}

export function generationOptions(env) {
  const childEnv = { ...env, CLAUDE_HERDR_AUTO_NAME: "0" };
  // Claude の多重起動ガードと Herdr の親端末識別を、要約専用プロセスへ引き継がない。
  delete childEnv.CLAUDECODE;
  delete childEnv.HC_TERMINAL_ID;
  delete childEnv.HC_TERMINAL_SOCKET;
  return {
    args: ["-p", "--safe-mode", "--tools", "", "--strict-mcp-config",
      "--mcp-config", '{"mcpServers":{}}', "--no-session-persistence",
      "--model", env.CLAUDE_HERDR_AUTO_NAME_MODEL || "haiku",
      "--system-prompt", SYSTEM_PROMPT, "--output-format", "json"],
    env: childEnv,
  };
}

export async function summarize(text, signal, env = process.env, command = "claude") {
  const options = generationOptions(env);
  const pending = execute(command, options.args, {
    env: options.env, cwd: homedir(), signal, timeout: 30_000, maxBuffer: 1024 * 1024,
  });
  pending.child.stdin.on("error", () => {});
  pending.child.stdin.end(text);
  const { stdout } = await pending;
  const reply = JSON.parse(stdout);
  return reply.subtype === "success" && !reply.is_error ? reply.result : "";
}

async function optionalRead(path) {
  try { return await readFile(path, "utf8"); }
  catch (error) { if (error.code === "ENOENT") return ""; throw error; }
}

export async function handle(input, {
  env = process.env, root = join(env.XDG_CACHE_HOME || join(homedir(), ".cache"), "dotfiles/herdr-auto-name"),
  bridge = createBridge(env, { app: "claude-code", label: LABEL }),
  generate = (text, signal) => summarize(text, signal, env),
} = {}) {
  if (env.CLAUDE_HERDR_AUTO_NAME === "0" || !env.HC_TERMINAL_ID || !env.HC_TERMINAL_SOCKET || !bridge) return;
  if (!["Stop", "UserPromptSubmit", "SessionEnd"].includes(input.hook_event_name)) return;
  if (input.agent_id) return;
  const key = createHash("sha256").update(`${env.HC_TERMINAL_SOCKET}\0${env.HC_TERMINAL_ID}`).digest("hex");
  const dir = join(root, key);
  await mkdir(dir, { recursive: true, mode: 0o700 });
  const generationPath = join(dir, "generation");
  if (input.hook_event_name !== "Stop") {
    await writeFile(generationPath, randomUUID(), { mode: 0o600 });
    return;
  }
  const generation = await optionalRead(generationPath);
  const text = await conversation(input);
  if (!text) return;
  const lockPath = join(dir, "lock");
  let lock;
  try { lock = await open(lockPath, "wx", 0o600); }
  catch (error) {
    if (error.code !== "EEXIST") throw error;
    // 強制終了後のロックだけを次のターンで回収する。生成には 30 秒の上限がある。
    try { if (Date.now() - (await stat(lockPath)).mtimeMs > 120_000) await rm(lockPath, { force: true }); }
    catch (error) { if (error.code !== "ENOENT") throw error; }
    return;
  }
  let timer;
  let namer;
  try {
    if (generation !== await optionalRead(generationPath)) return;
    const lastAttempt = Number(await optionalRead(join(dir, "attempt")));
    if (lastAttempt && Date.now() - lastAttempt < INTERVAL) return;
    let checking = false;
    timer = setInterval(async () => {
      if (checking) return;
      checking = true;
      try { if (generation !== await optionalRead(generationPath)) namer.cancel(); }
      catch { namer.cancel(); }
      finally { checking = false; }
    }, 100);
    namer = createNamer({
      bridge: {
        ...bridge,
        inspect: async (signal) => {
          const target = await bridge.inspect(signal);
          return generation === await optionalRead(generationPath) ? target : null;
        },
      },
      summarize: async (text, signal) => {
        await writeFile(join(dir, "attempt"), String(Date.now()), { mode: 0o600 });
        return generate(text, signal);
      },
      report: () => {},
    });
    await namer.run(text);
  } finally {
    clearInterval(timer);
    namer?.cancel();
    await lock.close();
    await rm(lockPath, { force: true });
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    let raw = "";
    for await (const chunk of process.stdin) raw += chunk;
    const command = process.argv[2] || "claude";
    await handle(JSON.parse(raw), { generate: (text, signal) => summarize(text, signal, process.env, command) });
  } catch {
    // 補助的な命名の失敗で、通常の対話や次の入力を止めない。
  }
}
