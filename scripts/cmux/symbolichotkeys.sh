#!/bin/sh
# ⌃⌘D (辞書で調べる) を無効にする。cmux の ⌃⌘D (下に分割) と衝突するため。
set -eu

plist="$HOME/Library/Preferences/com.apple.symbolichotkeys.plist"
key=":AppleSymbolicHotKeys:70:enabled"

# defaults 経由で plist をディスクに書き出させてから PlistBuddy で編集する
defaults read com.apple.symbolichotkeys >/dev/null 2>&1 || true
if /usr/libexec/PlistBuddy -c "Print $key" "$plist" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Set $key false" "$plist"
else
  /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:70 dict" "$plist" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add $key bool false" "$plist"
fi

/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

echo "⌃⌘D (辞書で調べる) を無効にした"
