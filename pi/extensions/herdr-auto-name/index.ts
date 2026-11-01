import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { createBridge } from "./bridge.mjs";
import { conversation, createNamer, SYSTEM_PROMPT } from "./naming.mjs";

export default function (pi: ExtensionAPI) {
  let namer: ReturnType<typeof createNamer> | undefined;
  let warned = false;

  pi.on("session_start", (_event, ctx) => {
    namer?.cancel();
    namer = undefined;
    if (ctx.mode !== "tui" || process.env.PI_HERDR_AUTO_NAME === "0") return;
    const bridge = createBridge();
    if (!bridge) return;
    namer = createNamer({
      bridge,
      summarize: async (text: string, signal: AbortSignal) => {
        if (!ctx.model) return "";
        const response = await ctx.modelRegistry.streamSimple(ctx.model, {
          systemPrompt: SYSTEM_PROMPT,
          messages: [{ role: "user", content: text, timestamp: Date.now() }],
        }, { signal, maxTokens: 512, reasoning: "minimal" }).result();
        if (response.stopReason !== "stop") return "";
        return response.content.filter((part) => part.type === "text")
          .map((part) => part.text).join("");
      },
      report: () => {
        if (warned) return;
        warned = true;
        ctx.ui.notify("Herdr の自動命名をスキップしました。接続またはモデル呼び出しに失敗しました。", "warning");
      },
    });
  });

  pi.on("before_agent_start", () => namer?.cancel());
  pi.on("session_shutdown", () => {
    namer?.cancel();
    namer = undefined;
  });
  pi.on("agent_settled", (_event, ctx) => {
    if (!namer || !ctx.model) return;
    // 通常の応答や次の入力を、タイトル生成の完了待ちで止めない。
    void namer.run(conversation(ctx.sessionManager.getBranch()));
  });
}
