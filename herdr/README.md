# Herdr のキー設定

macOS アプリ版 Herdr の `~/.config/herdr-app/keys.json` を管理する。TUI 版の設定ではない。
`cmux/cmux.json` のカスタム設定と、そこで変更していない cmux の既定キーに合わせる。

## cmux との対応

| 操作 | キー | Herdr の action |
|---|---|---|
| 新しいワークスペース / スペース | `⌘N` | `space.new` |
| ワークスペース / スペースを閉じる | `⌘⌃N` | `space.close` |
| 前 / 次のワークスペース / スペース | `⌘O` / `⌘L` | `space.prev` / `space.next` |
| ワークスペース / スペース名を変更 | `⌘R` | `space.rename` |
| 新しい surface / タブ | `⌘T` | `tab.new` |
| 前 / 次の surface / タブ | `⌘,` / `⌘.` | `tab.prev` / `tab.next` |
| surface / タブ名を変更 | `⌘⇧R` | `tab.rename` |
| 現在の surface / ペインを閉じる | `⌘W` | `pane.close` |
| ペインを右 / 下に分割 | `⌘D` / `⌘⇧D` | `pane.split:right` / `pane.split:down` |
| ペイン間を移動 | `⌘矢印` | `pane.go:<direction>` |
| ペインを最大化 / 元に戻す | `⌘⇧Enter` | `pane.zoom` |
| ワークスペース / スペースを番号で選択 | `⌘1〜9` | `space.select:<index>` |
| surface / タブを番号で選択 | `⌃1〜9` | `tab.select:<index>` |
| 移動先ピッカー | `⌘P` | `mod.open:picker` |
| コマンドパレット | `⌘⇧P` | `app.palette` |
| サイドバーの表示切替 | `⌘B` | `layout.toggle:sidebar` |
| 設定 | `⌘⇧,` | `app.settings` |

`⌘` = Command、`⌃` = Control、`⇧` = Shift、`⌥` = Option。

Herdr は terminal セクションが global セクションより優先される。そのため、既定の terminal の `⌘←` / `⌘→` (行頭 / 行末) は設定しない。ターミナルにフォーカスがあるときもペイン移動を使える。行頭 / 行末には `Ctrl+A` / `Ctrl+E` を使う。

## 揃えていない操作と注意点

- cmux の surface はペイン内のタブ。Herdr のタブは複数ペインを含められるので、構造は完全には一致しない。`⌘W` は現在のペインを閉じ、`⌘⇧W` は Herdr のタブ全体を閉じる。スペース全体を閉じるには `⌘⌃N` を使う。
- cmux の `⌘N` は Home + Agent のカスタム action を起動する。ここではキー設定のみを合わせ、Herdr の新しいスペースは通常どおりシェルを起動する。
- cmux の `⌘⌃O/L` (ワークスペースの上下移動) と `⌘⌃,/.` (surface の左右移動) は未割り当て。Herdr の `space.move` / `tab.move` は対象 ID と絶対位置が必要で、単純なキー割り当てでは相対移動を表せない。
- cmux の `⌘9` / `⌃9` は最後の項目を選ぶが、Herdr は 9 番目を選ぶ。
- Herdr 固有のエージェント移動 (`⌘[` / `⌘]`)、レイアウト切替 (`⌘⇧L`)、ペイン入替 (`⌘⌥⇧矢印`)、ヘルプ (`⌘/`)、画像貼付 (`Ctrl+V`) は維持する。
- `Ctrl+Tab` / `Ctrl+Shift+Tab` と `⌘⇧[` / `⌘⇧]` もタブ移動用に維持する。
- Herdr の既定キー全体をこのファイルで管理する。アプリ更新で既定キーが追加されても自動で取り込まない。

## 適用

PR のマージ後、通常の dotfiles ディレクトリで `nix run .#switch` を実行する。
初回は既存の `~/.config/herdr-app/keys.json` を退避する。Home Manager は既存の通常ファイルを上書きしない。
`keys.json` だけを symlink し、セッション・設定・レイアウト・mods は Herdr 側に残す。
キー設定はライブ反映される。アプリの設定リセットで symlink が置き換わったら、生成されたファイルを退避して `switch` し直す。
