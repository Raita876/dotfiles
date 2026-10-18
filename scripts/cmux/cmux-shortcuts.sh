#!/bin/sh
# cmux.json に "[" "]" を書くと JIS で誤動作するため (upstream issue #3061)、UserDefaults に直接登録する。
set -eu

# keyCode は JIS の物理キー: 30 が [ キー、42 が ] キー ("key" は cmux が US 配列の文字として保存する値)
set_shortcut() {
  defaults write com.cmuxterm.app "shortcut.$1" -data "$(printf '%s' "$2" | xxd -p | tr -d '\n')"
}

set_shortcut prevSidebarTab '{"key":"]","command":true,"shift":false,"option":false,"control":false,"keyCode":30}'
set_shortcut nextSidebarTab '{"key":"\\","command":true,"shift":false,"option":false,"control":false,"keyCode":42}'
set_shortcut moveWorkspaceUp '{"key":"]","command":true,"shift":false,"option":false,"control":true,"keyCode":30}'
set_shortcut moveWorkspaceDown '{"key":"\\","command":true,"shift":false,"option":false,"control":true,"keyCode":42}'
set_shortcut browserBack '{"key":"]","command":true,"shift":false,"option":true,"control":false,"keyCode":30}'
set_shortcut browserForward '{"key":"\\","command":true,"shift":false,"option":true,"control":false,"keyCode":42}'

echo "cmux のショートカットを登録した。cmux を再起動すると反映される"
