# Hermes Agent と Discord

Hermes は公式 Nix flake の `messaging` パッケージと Home Manager モジュールで導入する。Discord デスクトップアプリは既存の `nix/hosts/raita-mba.nix` の cask で導入済み。Bot はアプリのログインとは別で、アプリを起動していなくても動く。

連携は Hermes 標準の messaging Gateway を使う。Discord MCP サーバーや個人アカウントのトークンは不要。

## 管理するもの

- 本体と Discord 用 Python 依存関係: `flake.nix` / `flake.lock`
- 連携設定: `nix/modules/home/programs/hermes.nix`
- 状態・記憶・認証: `~/.hermes/` (Git 管理外)
- 秘密情報の入力元: `~/.config/hermes/secrets.env` (Git 管理外、Nix store にも入れない)
- 作業ディレクトリ: `~/hermes-workspace`

switch 時に公式モジュールが `~/.hermes/config.yaml` へ宣言した設定をマージし、`.env` を非秘密設定と `secrets.env` から再生成する。`.env` への直接編集は次の switch で失われるため、トークン・許可ユーザー・API キーは必ず `secrets.env` に書く。既存の Hermes を移行する場合、先に `.env` を安全な場所へ退避し、必要な値を `secrets.env` へ移す。

記憶・履歴・`auth.json` はリポジトリに取り込まない。既定のプロバイダーは `openai-codex`、モデルは `gpt-6.1-sol` とし、Nix で管理する。ChatGPT アカウントでの OAuth 認証はローカルで行う。Gateway の自動起動は認証前の起動を避けるため既定で無効。

## 初回セットアップ

### 1. Discord Bot を作る

[Discord Developer Portal](https://discord.com/developers/applications) で Application を作成する。

1. Bot ページで Bot トークンを発行する。個人アカウントのトークンは使わない。
2. Privileged Gateway Intents の **Message Content Intent** を有効化する。数値ユーザー ID の許可リストなら Server Members Intent は不要。ユーザー名・ロールで制限する場合は有効化する。
3. OAuth2 URL Generator で `bot` と `applications.commands` を選ぶ。
4. 対象チャンネルに必要な権限だけ付ける: View Channels、Send Messages、Read Message History、Embed Links、Attach Files、Create Public Threads、Send Messages in Threads。Administrator は付けない。
5. 生成した URL から自分のサーバーへ招待する。
6. Discord のユーザー設定 → 詳細設定 → 開発者モードを有効にし、自分のユーザー ID をコピーする。

### 2. 秘密情報を用意する

```sh
install -d -m 700 ~/.config/hermes
# 新規ファイルの場合のみ作成。既存ファイルは消さない。
touch ~/.config/hermes/secrets.env
chmod 600 ~/.config/hermes/secrets.env
$EDITOR ~/.config/hermes/secrets.env
```

既定の OpenAI Codex を使う場合の内容:

```dotenv
DISCORD_BOT_TOKEN=<Bot のトークン>
DISCORD_ALLOWED_USERS=<自分の数値ユーザー ID>
```

OpenAI Codex は次の手順で OAuth 認証するため、`OPENROUTER_API_KEY` や `OPENAI_API_KEY` は不要。別の API プロバイダーへ変更する場合は、その API キーもこのファイルに追加する。

複数ユーザーはカンマ区切り。許可リストを空のまま使ったり、`DISCORD_ALLOW_ALL_USERS=true` / `GATEWAY_ALLOW_ALL_USERS=true` を追加したりしない。非秘密の既定設定も `secrets.env` 側の同名変数で上書きできるため、内容は自分で管理する。

### 3. 適用し、OpenAI Codex を認証する

マージ後、通常の dotfiles で実行する (Pi は終了し、通常のターミナルから switch する):

```sh
cd ~/Repository/dotfiles
nix run .#switch
hermes auth status openai-codex
```

未認証の場合だけ次を実行し、ブラウザーで利用する ChatGPT アカウントにログインして許可する。認証済みの場合は再認証不要。

```sh
hermes auth add openai-codex --type oauth --browser
```

生成された認証ファイルはローカルに保持する。契約に応じたモデルの利用可否・利用上限が適用される。

```sh
hermes config get model
hermes auth status openai-codex
hermes
```

`provider: openai-codex`、`default: gpt-6.1-sol`、認証状態 `logged in` を確認し、`hermes` でツールを使わない簡単な会話を試す。

Home Manager 管理下では `hermes model` からモデル設定を保存できない。プロバイダー・モデルを変更する場合は `nix/modules/home/programs/hermes.nix` の `services.hermes-agent.settings.model` を変更して switch する。API キー方式のプロバイダーを使う場合、API の利用料金は通常のチャットの月額契約とは別途発生する。

### 4. 手動で接続を確認する

```sh
hermes gateway
```

許可したユーザーから Bot に DM、またはサーバー内で `@Bot` を送る。サーバーではメンション必須、他 Bot からの入力は無効、共有チャンネルのセッションはユーザー別にしている。

まずツールを使わない簡単な会話を試す。許可していないユーザーが利用できないことも確認する。終了は `Ctrl-C`。

トークンを更新した場合は `secrets.env` を編集 → switch → Gateway を再起動する。接続しない場合はトークン、Message Content Intent、招待先チャンネルの権限、許可ユーザー ID を確認する。

## 常駐化 (任意)

手動起動のプロセスを止め、利用するホストの Nix 設定に次を追加して switch する:

```nix
home-manager.users."<ユーザー名>".services.hermes-agent.gateway.enable = true;
```

公式モジュールが macOS のログインユーザー用 launchd agent を作成する。`hermes gateway install` で別のサービスを重ねて登録しない。ログは `~/Library/Logs/hermes-agent.log` と `~/Library/Logs/hermes-agent.err.log`。ログアウト・スリープ中も動作するサーバーではない。

無効化する場合は同オプションを `false` に戻して switch する。常駐時に設定・認証を更新した後は launchd のプロセスも再起動する:

```sh
launchctl kickstart -k "gui/$(id -u)/org.nix-community.home.hermes-agent"
```

## 安全性

危険な操作への承認は `manual`、cron / 無人実行で承認できない操作は `deny`。これはすべてのコマンド・外部送信を必ず確認する設定ではなく、Hermes の承認対象の操作に対する方針。

作業ディレクトリはサンドボックスではない。ローカル実行ではログインユーザーの権限でホストへアクセスできるため、許可ユーザーは自分や信頼できる人だけにする。重要な資格情報のあるホストで無条件に動かさず、必要に応じてコンテナなどの隔離を別途設定する。

## 更新と参考資料

本体は `flake.lock` 経由で更新する。`hermes update` や pip で別の本体を導入しない。

- [公式リポジトリ](https://github.com/NousResearch/hermes-agent)
- [公式 Home Manager モジュール](https://github.com/NousResearch/hermes-agent/blob/main/nix/homeManagerModules.nix)
- [公式 Discord ガイド](https://hermes-agent.nousresearch.com/docs/user-guide/messaging/discord)
