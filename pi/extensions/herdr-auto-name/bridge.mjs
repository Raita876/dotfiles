import { createConnection } from "node:net";
import { homedir } from "node:os";
import { join } from "node:path";

export const LABEL = "dotfiles.pi-auto-name";

export function request(path, payload, signal, timeout = 2000) {
  return new Promise((resolve, reject) => {
    const socket = createConnection(path);
    socket.setEncoding("utf8");
    let buffer = "";
    let settled = false;
    const finish = (error, result) => {
      if (settled) return;
      settled = true;
      signal?.removeEventListener("abort", abort);
      socket.destroy();
      if (error) reject(error);
      else resolve(result);
    };
    const abort = () => finish(new Error("Herdr request cancelled"));
    socket.setTimeout(timeout, () => finish(new Error("Herdr request timed out")));
    socket.on("error", (error) => finish(error));
    socket.on("end", () => finish(new Error("Herdr closed without a reply")));
    signal?.addEventListener("abort", abort, { once: true });
    if (signal?.aborted) return abort();
    socket.on("connect", () => socket.write(`${JSON.stringify(payload)}\n`));
    socket.on("data", (chunk) => {
      buffer += chunk;
      if (buffer.length > 2 * 1024 * 1024) return finish(new Error("Herdr reply too large"));
      const end = buffer.indexOf("\n");
      if (end < 0) return;
      try {
        const reply = JSON.parse(buffer.slice(0, end));
        if (reply.error) return finish(new Error("Herdr request failed"));
        finish(null, payload.jsonrpc ? reply.result : reply);
      } catch (error) {
        finish(error);
      }
    });
  });
}

export function createBridge(env = process.env) {
  if (!env.HC_TERMINAL_ID || !env.HC_TERMINAL_SOCKET) return null;
  const terminal = env.HC_TERMINAL_ID;
  const appSocket = join(env.HERDR_APP_HOME || join(homedir(), ".config/herdr-app"), "herdr-app.sock");
  const core = (method, params, signal) => request(env.HC_TERMINAL_SOCKET, {
    jsonrpc: "2.0", id: 1, method, params,
  }, signal);

  return {
    async inspect(signal) {
      const info = await core("terminal.get", { terminal }, signal);
      if (info.parent || !info.labels?.["herdr.space"] || !info.labels?.["herdr.tab"]) return null;
      const spaceId = info.labels["herdr.space"];
      const tabId = info.labels["herdr.tab"];
      const listing = await request(appSocket, { ls: true }, signal);
      const space = listing.spaces?.find((item) => item.id === spaceId && item.machine == null);
      const tab = space?.tabs?.find((item) => item.id === tabId && item.active);
      if (tab?.terminals?.find((item) => item.app === "pi")?.terminal !== terminal) return null;
      // ls の表示名では、未命名の Space と手動名を区別できない。
      const document = await core("doc.get", { name: "herdr-app" }, signal);
      const stored = document.value?.spaces?.find((item) => item.id === spaceId);
      if (!stored || typeof stored.name !== "string") return null;
      let previous;
      try {
        previous = JSON.parse(info.labels[LABEL] || "null");
      } catch {
        previous = null;
      }
      return { space: spaceId, tab: tabId, name: stored.name, previous };
    },
    async rename(space, name, signal) {
      await request(appSocket, { do: "space.rename", args: { id: space, name } }, signal);
    },
    async remember(previous, signal) {
      await core("terminal.label", { terminal, labels: { [LABEL]: JSON.stringify(previous) } }, signal);
    },
  };
}
