# Herdr の設定

macOS アプリ版 Herdr の `~/.config/herdr-app/keys.json`、`settings.json` と起動用 mod `mods/pi-space/` を管理する。TUI 版の設定ではない。
`cmux/cmux.json` のカスタム設定と、そこで変更していない cmux の既定キーに合わせる。

## cmux との対応

| 操作 | キー | Herdr の action |
|---|---|---|
| 新しいワークスペース / スペース | `⌘N` | `mod.open:pi-space` |
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
- `⌘N` は `pi-space` mod を介して `space.new { argv: ["pi"] }` を実行する。フォーカス中のターミナルのフォルダを引き継ぎ、Pi 終了後はシェルに戻る。`pi` がインストールされ、シェルから実行できる必要がある。
- サイドバーやメニューからの新規スペース、`⌘T`、ペイン分割は通常どおりシェルを起動する。`pi-space` は一時的なオーバーレイとして開き、起動後すぐ閉じるため、レイアウトや配布済み mods の複製は不要。
- cmux の `⌘⌃O/L` (ワークスペースの上下移動) と `⌘⌃,/.` (surface の左右移動) は未割り当て。Herdr の `space.move` / `tab.move` は対象 ID と絶対位置が必要で、単純なキー割り当てでは相対移動を表せない。
- cmux の `⌘9` / `⌃9` は最後の項目を選ぶが、Herdr は 9 番目を選ぶ。
- Herdr 固有のエージェント移動は、前 / 次を `⌘I` / `⌘K` に割り当てる。
- レイアウト切替 (`⌘⇧L`)、ペイン入替 (`⌘⌥⇧矢印`)、ヘルプ (`⌘/`)、画像貼付 (`Ctrl+V`) は維持する。
- `Ctrl+Tab` / `Ctrl+Shift+Tab` と `⌘⇧[` / `⌘⇧]` もタブ移動用に維持する。
- Herdr の既定キー全体をこのファイルで管理する。アプリ更新で既定キーが追加されても自動で取り込まない。

## テレメトリ

`nix/modules/darwin/programs/herdr.nix` で `telemetry = false` を宣言し、Home Manager が生成する読み取り専用の `settings.json` への symlink でテレメトリを無効化する。設定は GUI ではなく Nix で管理し、変更後に `nix run .#switch` を実行する。

既存の `settings.json` とのマージは行わない。残したい設定があれば、適用前に同じ Nix の設定へ追加する。更新チェックや mod による通信は無効化しない。
設定先は Home Manager の `xdg.configHome` に従う。`HERDR_APP_HOME` で別の場所を指定する構成は対象外。

[Herdr の公式仕様](https://github.com/herdrdev/herdr-app/blob/master/docs/security.md#telemetry)では、無効化時にローカルのインストール ID と未送信レポートを削除する。送信済みのレポートは取り消せない。

## macOS のデスクトップ通知

`desktop_notifications.py` が Herdr App のローカルソケットを 2 秒ごとに読み、エージェントの状態変化を `terminal-notifier` で macOS に通知する。ツールとログイン時に起動する LaunchAgent は `nix/modules/darwin/programs/herdr.nix` で管理する。Herdr の配布済み mod は変更しない。

- Herdr が状態を把握できる全エージェントが対象。サブエージェントは除外する。
- `working` / `blocked` / `error` から `done` への遷移で完了を通知する。閲覧済みの `idle` は通知しない。
- `blocked` / `error` に変わると入力待ち・エラーを通知する。これは対象の端末を見ているときも通知する。
- 起動・再接続直後や新たに検出した端末の既存状態は通知しない。Herdr が起動していない間は待機する。
- ポーリングの間に終わる短い状態変化は見逃す場合がある。
- 通知にエージェント名・Space 名・Tab 名を含む。会話本文は送信しない。ロック画面での表示は macOS 側で制御する。
- 通知をクリックすると Herdr を前面に出す。該当端末への直接移動はしない。Herdr 標準の通知音・トーストはそのまま残す。
- `HERDR_APP_HOME` による別の設定先は対象外。

適用後、macOS の「システム設定 → 通知」で **terminal-notifier** の通知を許可する。通知の送信元は Herdr ではなく terminal-notifier になる。集中モード等で抑制される場合もある。初回の通知時に許可を求められる場合は許可する。

通知許可の診断、稼働状態、エラーログ:

```sh
terminal-notifier -diagnose
launchctl print gui/$(id -u)/org.nix-community.home.herdr-desktop-notifications
tail -n 30 ~/Library/Logs/herdr-desktop-notifications.log
```

単体テスト（実際の通知は送信しない）:

```sh
python3 -m unittest discover -s herdr -p 'test_*.py'
```

## 適用

Herdr に設定を上書きされないよう、適用前に Herdr アプリを終了する。Herdr 内のターミナルではなく、別のターミナルから作業する。
PR のマージ後、通常の dotfiles ディレクトリで `nix run .#switch` を実行し、Herdr を起動し直す。Settings → Privacy の「Share anonymous usage data」が OFF になっていることを確認する。
既存の `~/.config/herdr-app/keys.json` と `settings.json` は、既定では Home Manager がそれぞれ `keys.json.before-nix` と `settings.json.before-nix` に自動退避する。安全のため事前の手動バックアップを推奨する。自動退避先が既に存在する場合は、別名に移してから実行する。
`keys.json`、`settings.json` と `mods/pi-space/` を symlink し、セッション・レイアウト・配布済み mods は Herdr 側に残す。
キー設定はライブ反映される。アプリの設定リセットで symlink が置き換わったら、退避先の重複に注意して `switch` し直す。
