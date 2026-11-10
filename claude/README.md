# Claude Code

## Herdr Space の自動命名

`hooks/herdr-auto-name.mjs` は、Herdr 内の Claude Code の会話から短い Space 名を生成する。Pi 版と Herdr 通信・タイトルの検証・手動名の保護を `herdr/auto-name/` で共有する。

通常の `~/Repository/dotfiles` に変更を取り込み、`nix run .#switch` を実行し、Claude Code を起動し直す。設定は `nix/modules/home/programs/claude-code.nix` で管理し、スクリプトはリポジトリから直接読み込む。

### 動作

- `Stop` の非同期 command hook で開始する。Herdr 外、子ターミナル、サブエージェントでは命名しない。ローカル Space の選択中のタブで、最初の Claude ターミナルだけが対象。
- 直近 6 件のユーザー・アシスタント本文を各 2,000 文字まで送る。ツール結果・思考・画像・メタメッセージ・sidechain は除外する。transcript の書き込みが遅れる場合に備え、最後の回答には hook の `last_assistant_message` を使う。
- 生成専用の `claude -p` を追加起動する。`--safe-mode`、`--tools ""`、空の strict MCP 設定、独立した system prompt、`--no-session-persistence` により、プロジェクトの指示・カスタム hook・ツール・MCP・生成用セッションの保存を無効にする。認証は通常の Claude Code と同じ仕組みを使う。**`--safe-mode` 対応版が必要**（手元の 2.1.316 で CLI オプションを確認）。
- 既定の生成モデルは `haiku`。`CLAUDE_HERDR_AUTO_NAME_MODEL` で変更できる。**追加のモデル利用枠・料金を消費する**。本文に含まれる機密情報を自動で除去するものではない。
- 生成は最短 60 秒間隔、30 秒で打ち切る。次の入力・セッション終了で処理をキャンセルし、rename 前にも入力の世代と Herdr の状態を確認する。命名の失敗は会話を止めず、スキップする。
- 未命名、または同じ端末が前回付けた名前のままの Space だけ更新する。手動で別の名前を付けると停止し、名前を空にすると再開する。
- 前回のタイトル・会話のハッシュ・更新時刻を端末ラベル `dotfiles.claude-auto-name` に保存する。Pi のラベルとは分離する。
- 多重起動防止用ロック・入力世代・生成試行時刻のみを `$XDG_CACHE_HOME/dotfiles/herdr-auto-name/`（既定 `~/.cache/dotfiles/herdr-auto-name/`）に保存する。会話本文・タイトルはこのキャッシュに保存しない。強制終了後の古いロックは 2 分経過後の hook で回収し、その次の応答から再試行できる。

Herdr に条件付き rename API がないため、最後の状態確認と rename の間の手動変更は完全には保護できない。自動名と同じ文字列を手動で付けた場合も判別できない。別端末や別アプリが付けた自動名は手動名として扱うため、引き継ぐ場合は一度名前を空にする。

### 無効化・モデル変更

```sh
CLAUDE_HERDR_AUTO_NAME=0 claude
CLAUDE_HERDR_AUTO_NAME_MODEL=sonnet claude
```

常に無効にする場合は `~/.zshrc.local` に `export CLAUDE_HERDR_AUTO_NAME=0` を設定する。機密情報を扱う場合にもこの方法で追加のモデル送信を止められる。

Nix 側では、Home Manager の次のオプション (既定 `true`) で `Stop`・`UserPromptSubmit`・`SessionEnd` の自動命名 hook をまとめて登録対象から外せる。読み込む側が追加した hook は残る。

```nix
home-manager.users."<ユーザー名>".dotfiles.claudeCode.herdrAutoName.enable = false;
```

**既存ファイルへの注意:** switch は既存の `~/.claude/settings.json` に設定をマージするため、Nix からイベントキーが無くなっても、そのキーが既存 JSON にあれば残る。このオプションを `false` にするだけでは、既に書き込まれた hook を確実には停止できない。停止には `CLAUDE_HERDR_AUTO_NAME=0` を設定して Claude Code を起動し直すか、switch 後に `settings.json` の各イベントから `herdr-auto-name.mjs` を実行するエントリだけを手動で削除する。他の hook は削除しない。

イベントごとの hook リストは Nix モジュール間で連結される。リスト全体を置き換えるには `lib.mkForce` を使えるが、自動命名は 3 イベントが揃って機能するため、一括切り替えには上記オプションを使う。

### テスト

```sh
nix build .#checks.aarch64-darwin.claude-code --no-link
node --test claude/hooks/herdr-auto-name.test.mjs pi/extensions/herdr-auto-name/naming.test.mjs
```

Nix テストは、利用側の `Stop` との連結、3 イベントへの登録、一括無効化、スカラー初期値の上書きを検証する。

生成用 CLI はスタブ、Herdr 通信は一時 Unix ソケットで検証する。実際の Space 名やモデル API は変更・呼び出ししない。
