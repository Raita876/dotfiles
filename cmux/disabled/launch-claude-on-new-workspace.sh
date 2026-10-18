#!/bin/bash
# cmux 0.65.1 回避策（2026-10-13 追加）
# 0.65.1 で ⌘N（File > New Workspace）が ui.newWorkspace.action を無視するようになった
# （upstream PR #19112 で skipConfiguredAction: true が付いたため）。
# ~/.cmuxterm/automations.json のルールから surface.created(origin=workspace_initial) で呼ばれ、
# 「素のシェルだけの新規ワークスペース」のときだけ claude を起動する。
# upstream が直ったら automations.json のルールごと削除してよい。

CMUX=/Applications/cmux.app/Contents/Resources/bin/cmux
export CMUX_QUIET=1
LOG="$HOME/Library/Logs/cmux-launch-claude.log"
log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }

event="${CMUX_AUTOMATION_EVENT_JSON:-$CMUX_AUTOMATION_EVENT}"
ws=$(printf '%s' "$event" | /opt/homebrew/bin/jq -r '.workspace_id // empty')
sf=$(printf '%s' "$event" | /opt/homebrew/bin/jq -r '.surface_id // .payload.surface_id // empty')
[[ -n "$ws" && -n "$sf" ]] || { log "skip: no ids"; exit 0; }

# アプリ起動直後はセッション復元中なので触らない
app_pid=$(ps -axo pid=,command= | awk '$2 == "/Applications/cmux.app/Contents/MacOS/cmux" && NF == 2 {print $1; exit}')
if [[ -n "$app_pid" ]]; then
    up=$(ps -o etime= -p "$app_pid" | tr -d ' ')
    if [[ "$up" =~ ^([0-9]+):([0-9]+)$ ]] && (( 10#${BASH_REMATCH[1]} * 60 + 10#${BASH_REMATCH[2]} < 30 )); then
        log "skip $ws: app just launched ($up)"; exit 0
    fi
fi

# home-claude アクション等の起動コマンドが動き出すのを待ってから判定する
sleep 1.5

list=$("$CMUX" rpc surface.list "{\"workspace_id\":\"$ws\"}" 2>/dev/null) || { log "skip $ws: surface.list failed"; exit 0; }
ok=$(printf '%s' "$list" | /opt/homebrew/bin/jq -r --arg sf "$sf" '
  (.surfaces | length) == 1
  and .surfaces[0].id == $sf
  and .surfaces[0].type == "terminal"
  and .surfaces[0].initial_command == null
  and .surfaces[0].resume_binding == null
  and .surfaces[0].tmux_start_command == null
  and .surfaces[0].title != "Claude"')
[[ "$ok" == "true" ]] || { log "skip $ws: not a plain new workspace"; exit 0; }

agent=$("$CMUX" rpc surface.input_state "{\"surface_id\":\"$sf\"}" 2>/dev/null | /opt/homebrew/bin/jq -r '.agent')
[[ "$agent" == "false" ]] || { log "skip $ws: agent=$agent"; exit 0; }

"$CMUX" rpc surface.send_text "{\"workspace_id\":\"$ws\",\"surface_id\":\"$sf\",\"text\":\"cd ~ && claude\\n\"}" >/dev/null 2>&1 \
    && log "launched claude in $ws/$sf" || log "send_text failed for $ws/$sf"
