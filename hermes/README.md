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

記憶・履歴・`auth.json` はリポジトリに取り込まない。既定のプロバイダーは `openai-codex`、モデルは `gpt-6.1-sol` とし、Nix で管理する。ChatGPT アカウントでの OAuth 認証はローカルで行う。Gateway の自動起動は共通設定では無効にし、個人ホスト `raita-mba` だけで有効にしている。switch 後はログインユーザー用の launchd agent として起動する。

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

`raita-mba` では switch 時に Gateway も自動起動する。既に認証・秘密情報の設定が済んでいればそのまま適用してよい。未認証の初回セットアップでは、先に `nix/hosts/raita-mba.nix` の `gateway.enable` を一時的に `false` にし、手動での動作確認後に `true` へ戻す。

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

Home Manager 管理下では `hermes model` からモデル設定を保存できない。プロバイダー・モデルを変更する場合は、ホスト設定やこの flake を読み込む側から `dotfiles.hermes.model` を上書きして switch する。この型付きオプションの既定値は各項目に `lib.mkDefault` を指定しているため、通常の値の指定で上書きでき、`lib.mkForce` は不要。上流の `services.hermes-agent.settings` は独自のマージ処理でネストした優先度指定を解釈しないため、`mkDefault` は直接埋め込まず、このオプションで解決した値を渡す。API キー方式のプロバイダーを使う場合、API の利用料金は通常のチャットの月額契約とは別途発生する。

### 4. Discord の接続を確認する

`raita-mba` で常駐化が有効なら、switch で起動した Bot にそのまま送信して確認する。`hermes gateway` を重ねて起動しない。ログ・再起動の操作は後述の「常駐化」を参照する。

初回セットアップなどで常駐化を無効にしている場合だけ、手動で起動する:

```sh
hermes gateway
```

許可したユーザーから Bot に DM、またはサーバー内で `@Bot` を送る。サーバーではメンション必須、他 Bot からの入力は無効、共有チャンネルのセッションはユーザー別にしている。

まずツールを使わない簡単な会話を試す。許可していないユーザーが利用できないことも確認する。手動起動した場合の終了は `Ctrl-C`。

トークンを更新した場合は `secrets.env` を編集 → switch → Gateway を再起動する。接続しない場合はトークン、Message Content Intent、招待先チャンネルの権限、許可ユーザー ID を確認する。

## 外部からモデルを変更する (LiteLLM Proxy の例)

利用するホストの Nix 設定 (個人 Mac なら `nix/hosts/raita-mba.nix`) や、この flake を読み込む側のモジュールに追加する:

```nix
home-manager.users."<ユーザー名>".dotfiles.hermes.model = {
  provider = "custom";
  default = "hermes-default";
  base_url = "http://127.0.0.1:4000/v1";
  api_mode = "chat_completions";
};
```

`default` は LiteLLM 側で公開したモデル名・エイリアスに合わせ、`base_url` は利用する Proxy の URL に置き換える。プロバイダーを変える場合は接続先も合わせて上書きし、Codex 用の URL を残さない。リモートの Proxy には HTTPS を使う。

Proxy が API キーを要求する場合は、`~/.config/hermes/secrets.env` に以下を追加する。ここで使うのは LiteLLM Proxy のキーであり、ChatGPT の OAuth トークンやモデル提供元の API キーではない。

```dotenv
OPENAI_BASE_URL=http://127.0.0.1:4000/v1
OPENAI_API_KEY=<LiteLLM Proxy のキー>
```

`OPENAI_BASE_URL` は Nix の `base_url` と同じ URL にする。Hermes はキーの意図しない送信を防ぐため接続先との対応を確認するので、キーだけを追加しない。秘密情報は Nix に書かない。

switch 後に `hermes config get model` で接続先とモデル名を確認し、`hermes` で会話を試す。Gateway を常駐させている場合は再起動する。LiteLLM 側で `hermes-default` の接続先モデルを切り替える運用なら、Hermes 側のモデル名を変える必要はない。LiteLLM Proxy の導入・設定はこのリポジトリの管理対象外で、実接続は未検証。

## 常駐化

`nix/hosts/raita-mba.nix` では以下を設定済み。共通モジュールでは無効のままなので、ほかのホストで利用する場合は明示的に有効化する。手動起動の Gateway があれば `Ctrl-C` で止めてから switch し、二重起動を避ける:

```nix
home-manager.users."<ユーザー名>".services.hermes-agent.gateway.enable = true;
```

公式モジュールが macOS のログインユーザー用 launchd agent を作成する。`hermes gateway install` で別のサービスを重ねて登録しない。ログは `~/Library/Logs/hermes-agent.log` と `~/Library/Logs/hermes-agent.err.log`。ログアウト・スリープ中も動作するサーバーではない。

ログを確認する:

```sh
tail -f ~/Library/Logs/hermes-agent.log \
        ~/Library/Logs/hermes-agent.err.log
```

無効化する場合はホスト設定の同オプションを `false` に変更して switch する。常駐時に設定・認証を更新した後は launchd のプロセスも再起動する:

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
