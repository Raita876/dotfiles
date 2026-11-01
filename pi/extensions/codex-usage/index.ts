import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";
import { createMonitor, fetchUsage, formatUsage, UsageError } from "./usage.mjs";

export default function (pi: ExtensionAPI) {
  let monitor: ReturnType<typeof createMonitor> | undefined;

  pi.on("session_start", (_event, ctx) => {
    monitor?.dispose();
    monitor = undefined;
    if (ctx.mode !== "tui" || process.env.PI_CODEX_USAGE === "0") return;
    let display: ReturnType<typeof formatUsage> = { text: "Codex  利用枠を取得中…", color: "dim" };
    let redraw: (() => void) | undefined;
    ctx.ui.setWidget("codex-usage", (tui, theme) => {
      redraw = () => tui.requestRender();
      return {
        render: (width) => [truncateToWidth(theme.fg(display.color, display.text), width)],
        invalidate() {},
      };
    }, { placement: "aboveEditor" });
    monitor = createMonitor({
      load: async (signal: AbortSignal) => {
        const token = await ctx.modelRegistry.getApiKeyForProvider("openai-codex");
        signal.throwIfAborted();
        if (!token) throw new UsageError("Codex 認証が必要です (/login)");
        return fetchUsage(token, signal);
      },
      render: (next: typeof display) => {
        display = next;
        redraw?.();
      },
    });
  });

  pi.registerCommand("codex-usage", {
    description: "Codex の利用枠を再取得する",
    handler: async (_args, ctx) => {
      if (!monitor) {
        ctx.ui.notify("Codex 利用枠表示は対話モードでのみ有効です。PI_CODEX_USAGE=0 では無効になります。", "info");
        return;
      }
      await monitor.refresh();
    },
  });

  pi.on("session_shutdown", () => {
    monitor?.dispose();
    monitor = undefined;
  });
}
