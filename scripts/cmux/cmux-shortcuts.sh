#!/bin/sh
# cmux の [ ] 系ショートカットを JIS キーボード向けに登録する。
# cmux.json に "[" "]" を書くと US 配列前提の照合で二重に一致して誤動作するため (upstream issue #3061)、
# 設定画面 (Settings > Keyboard Shortcuts) と同じ形式で UserDefaults に直接書き込む。
# 値は data 型 (JSON のバイト列) なので nix-darwin の CustomUserPreferences では扱えない。
# 新しい Mac や cmux の設定をリセットしたときに 1 回実行し、cmux を再起動する。
set -eu

# keyCode は JIS の物理キー: 30 が [ キー、42 が ] キー ("key" は cmux が US 配列の文字として保存する値)
set_shortcut() {
  defaults write com.cmuxterm.app "shortcut.$1" -data "$(printf '%s' "$2" | xxd -p | tr -d '\n')"
}

# ⌘[ ⌘]: ワークスペースの切替
set_shortcut prevSidebarTab '{"key":"]","command":true,"shift":false,"option":false,"control":false,"keyCode":30}'
set_shortcut nextSidebarTab '{"key":"\\","command":true,"shift":false,"option":false,"control":false,"keyCode":42}'
# ⌃⌘[ ⌃⌘]: ワークスペースの並び替え
set_shortcut moveWorkspaceUp '{"key":"]","command":true,"shift":false,"option":false,"control":true,"keyCode":30}'
set_shortcut moveWorkspaceDown '{"key":"\\","command":true,"shift":false,"option":false,"control":true,"keyCode":42}'
# ⌥⌘[ ⌥⌘]: ブラウザの戻る・進む
set_shortcut browserBack '{"key":"]","command":true,"shift":false,"option":true,"control":false,"keyCode":30}'
set_shortcut browserForward '{"key":"\\","command":true,"shift":false,"option":true,"control":false,"keyCode":42}'

echo "cmux のショートカットを登録した。cmux を再起動すると反映される"
