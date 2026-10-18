# dotfiles 構築プラン

作成日: 2026-10-14 / 更新: 2026-10-18 (Phase 1 実装済み。適用は未実施)
参考: [ryoppippi/dotfiles](https://github.com/ryoppippi/dotfiles), [babarot/dotfiles](https://github.com/babarot/dotfiles) (調査結果は [survey.md](./survey.md))

## ゴール

- この Mac (Apple Silicon / macOS) の環境を Nix flake で宣言的に管理する
- `git clone` → 1 コマンドで同じ環境を再現できる状態にする
- Homebrew を整理し、CLI は Nix、GUI アプリは cask に寄せる
- Node などの言語ランタイムは、プロジェクトごとに devShell + direnv で管理する
- 最初は **最小構成** で動かし、段階的に育てる

## 現状 (調査結果)

| 項目 | 状態 |
|---|---|
| マシン | MacBook Air (Mac15,12 / M3), aarch64-darwin, ユーザー `raita` |
| ホスト名 | `raitanonotobukkukonpyuta` (コンピュータ名: 「raitaのノートブックコンピュータ」) |
| Nix | 2.35.3 (公式インストーラ、`nix-daemon` launchd 管理)。`~/.config/nix/nix.conf` で flakes 有効 |
| nix-darwin / home-manager / direnv | 未導入 |
| シェル | zsh。`~/.zprofile` (brew shellenv, go / node@20 の PATH, Composio)、`~/.zshrc` (history, compinit, eza alias, nodenv, starship) |
| git | `~/.gitconfig` (user.name / user.email のみ) |
| Node | nodenv (global 24.21.0, ほかに 22.17.0 / 24.3.0 / 24.14.0)、brew の node / node@20 も併存。npm で全体に入っているもの: Claude Code (nodenv 24.21.0 / 22.17.0)、pnpm・@nestjs/cli (nodenv 22.17.0)、wscat (brew の node) |
| Go | brew の go (1.27.2, PATH 上で優先) と `/usr/local/go` (公式 pkg, 1.23.2) が併存 |
| Homebrew | formula 約 35 個、cask: ghostty, herdr-gpui。サービスは colima のみ起動中 (mysql / postgresql@14 は停止中) |
| brew 管理外の CLI | starship (`/usr/local/bin/starship`、インストールスクリプトで導入) |
| brew 管理外の GUI アプリ | Google Chrome, Discord, Notion, Visual Studio Code, cmux (Dock に並んでいる) |
| リポジトリ置き場 | `~/Repository/` (ghq は未使用) |

## 方針

ryoppippi さんの構成のうち、**骨格だけ** を真似る。

| 観点 | ryoppippi さん | 本プラン (Phase 1) | 理由 |
|---|---|---|---|
| システム管理 | nix-darwin + home-manager (darwin module) | **同じ** | macOS 設定・Homebrew・ユーザー環境を 1 コマンドで適用できる |
| flake の組み立て | flake-parts でモジュール分割 | **素の flake** | 最初は概念を減らす。ファイルが増えたら flake-parts へ移行 |
| ディレクトリ構成 | `nix/modules/{darwin,home}/` | **同じ** | 後で参考リポジトリと見比べやすい |
| シェル | fish | **zsh のまま** | 今の設定を活かす |
| 設定ファイルの配置 | リポジトリへの直接 symlink (`link_force`) | `mkOutOfStoreSymlink` でリポジトリへ symlink | 編集が即反映され、rebuild 不要。仕組みは同じで標準 API |
| CLI ツール | nixpkgs (`home.packages`) | **同じ** | |
| GUI アプリ | `homebrew.casks` | **同じ** | アプリ自身の自動更新が使え、`/Applications` に普通に入る |
| Homebrew 本体 | nix-homebrew で管理 | **既存の brew をそのまま使う** | nix-homebrew は後回し |
| 言語ランタイム | devShell / direnv | **同じ** (nodenv は廃止) | プロジェクトごとにバージョンを固定できる |
| Linux 対応 / CI / overlay / agent skills | あり | **なし** | 必要になったら追加 |

## 決定事項

| # | 項目 | 決定 |
|---|---|---|
| 1 | ホスト名 | **`raita-mba`** に付け直す (下記「ホスト名の候補」) |
| 2 | Node / Go | **nodenv は使わない**。プロジェクトは `flake.nix` の devShell + direnv、指定がないときのデフォルトは **Node.js 24 (`nodejs_24`)** と **Go 1.27 (`go_1_27`)** |
| 3 | macOS 設定 | 現在の設定 (初期値から変更されているもの) をそのまま移植 |
| 4 | Homebrew | **整理する**。宣言していない formula / cask は自動でアンインストール (`cleanup = "uninstall"`) |
| 5 | GUI アプリ | Chrome / Discord / Notion / VS Code / cmux を **`homebrew.casks` に追加** |
| 6 | npm で全体に入れていたツール | **Claude Code と pnpm は nixpkgs で入れる**。@nestjs/cli と wscat は入れない (必要なら npx かプロジェクトの devShell) |

### ホスト名の候補

ホスト名は `darwin-rebuild switch --flake .` で使う構成名と一致させる。

| 候補 | 意味 | 評価 |
|---|---|---|
| **`raita-mba`** (推奨) | raita の **M**ac**B**ook **A**ir | 短く、機種が分かる。Mac が増えたとき (`raita-mbp`, `raita-mini`) と並べやすい |
| `raita-air` | 同上 | 読みやすいが、同じ機種を 2 台持つと区別できない |
| `raita-m3` | チップ名 | 買い替え時に名前と中身がずれやすい |

nix-darwin で次のように設定する:

```nix
networking = {
  hostName = "raita-mba";
  localHostName = "raita-mba";
  computerName = "raita-mba";   # Finder / AirDrop に表示される名前。日本語名のままにしたい場合は外す
};
```

### デフォルトの Node.js バージョン

- `nodejs_24` を選ぶ理由: いま nodenv の global が 24.21.0 で、nixpkgs (unstable) の `nodejs_24` も **24.21.0** と一致する。24 系は LTS
- Node 26 (nixpkgs では 26.11.1) は 2026 年 10 月下旬に LTS 入りする予定。LTS 化後に `nodejs_26` へ上げるかは別途検討
- 優先順位: direnv が devShell を読み込むと、プロジェクト側の node が PATH の先頭に来る。**devShell がないディレクトリではデフォルトの node 24 が使われる**

### デフォルトの Go バージョン

- `go_1_27` (1.27.2) を選ぶ理由: いま PATH 上で使われている brew の go が **1.27.2** で、nixpkgs の `go_1_27` と一致する
- nixpkgs の `go` (バージョン指定なし) は 1.26.8 で、今より古くなるため使わない
- 既存プロジェクトの `go.mod` は `go 1.18` 〜 `go 1.25.1`。`go.mod` の `go` 行は「最低限必要なバージョン」なので、1.27 でそのままビルドできる
- 特定のバージョンに固定したいプロジェクトは、Node と同じく devShell で指定する (direnv が読み込むと、プロジェクト側の go が優先される)

## Phase 1 で作るファイル

```
dotfiles/
├── flake.nix                     # inputs と darwinConfigurations."raita-mba"
├── flake.lock                    # (自動生成)
├── .gitignore                    # result, cmux/*.bak など
├── README.md                     # セットアップ・日常運用の手順
├── docs/
│   ├── plan.md                   # このファイル
│   └── survey.md                 # dotfiles 構成の調査
├── nix/
│   └── modules/
│       ├── darwin/
│       │   ├── default.nix       # nix 設定, primaryUser, ホスト名, zsh 有効化, Touch ID sudo
│       │   ├── system.nix        # macOS defaults (現在の設定を移植)
│       │   └── homebrew.nix      # casks / brew に残す formula / cleanup
│       └── home/
│           ├── default.nix       # home.stateVersion, imports
│           ├── packages.nix      # CLI ツール + デフォルトの Node / Go
│           ├── git.nix           # programs.git (今の ~/.gitconfig を移植)
│           ├── gh.nix            # programs.gh (git の GitHub 認証を gh に任せる)
│           ├── direnv.nix        # direnv + nix-direnv
│           ├── dotfiles.nix      # zsh/ ghostty/ cmux/ vscode/ をホームへ symlink
│           └── programs/
│               └── claude-code.nix  # Claude Code 本体・settings.json のマージ・~/.claude へのリンク
├── zsh/
│   ├── zprofile                  # 今の ~/.zprofile を整理して移植
│   └── zshrc                     # 今の ~/.zshrc を整理して移植
├── ghostty/
│   └── config                    # 今の Ghostty 設定を移植
├── cmux/
│   └── cmux.json                 # 今の cmux 設定を移植 (コメント付き JSON のまま)
├── vscode/
│   ├── settings.json             # 今の VS Code 設定を移植
│   └── extensions.txt            # 拡張機能の一覧 (code --list-extensions の出力)
├── .claude/
│   └── settings.json             # このリポジトリ用の設定 (編集後に nix fmt を実行するフック)
├── agents/
│   ├── AGENTS.md                 # 全体向けの指示 (~/.claude/CLAUDE.md としてリンク)
│   ├── shared/                   # AGENTS.md から @ で読み込む細かいルール (今は空)
│   └── skills/                   # 自作スキル (fu-calculation, fu-calculation-quiz)
├── claude/
│   ├── commands/                 # カスタムスラッシュコマンド (今は空)
│   ├── agents/                   # サブエージェント (今は空)
│   └── output-styles/            # 出力スタイル (今は空)
└── templates/
    └── node/
        └── flake.nix             # プロジェクト用 devShell の雛形 (Node)
```

### 各ファイルの中身 (概要)

**flake.nix**
- inputs: `nixpkgs` (nixpkgs-unstable), `nix-darwin`, `home-manager` (どちらも `inputs.nixpkgs.follows = "nixpkgs"`)
- outputs:
  - `darwinConfigurations."raita-mba"`
    - modules: `./nix/modules/darwin`, `home-manager.darwinModules.home-manager`
    - `home-manager.users.raita = ./nix/modules/home;`
    - `home-manager.useGlobalPkgs = true; useUserPackages = true;`
    - `home-manager.backupFileExtension = "before-nix";` (既存の `~/.zshrc` 等と衝突したら退避)
  - `templates.node` (`nix flake init -t ~/Repository/dotfiles#node` でプロジェクトに雛形を置ける)
  - `formatter.aarch64-darwin = nixfmt`

**nix/modules/darwin/default.nix**
- `nix.settings.experimental-features = [ "nix-command" "flakes" ]`, `trusted-users = [ "root" "raita" ]`
- `system.primaryUser = "raita"`, `system.stateVersion = 6`
- `networking.{hostName,localHostName,computerName} = "raita-mba"`
- `programs.zsh.enable = true`
- `nixpkgs.config.allowUnfree = true`
- `security.pam.services.sudo_local.touchIdAuth = true` (sudo を Touch ID で)

**nix/modules/darwin/system.nix**
- `system.defaults.*` で、**この Mac で初期値から変更されている設定をそのまま移植** する (2026-10-15 に `defaults read` で確認)

```nix
system.defaults = {
  NSGlobalDomain = {
    AppleInterfaceStyle = "Dark";                 # ダークモード
    "com.apple.swipescrolldirection" = false;     # ナチュラルスクロール オフ
  };
  finder.FXPreferredViewStyle = "Nlsv";           # Finder をリスト表示
  trackpad = {
    Clicking = true;                              # タップでクリック
    TrackpadRightClick = false;                   # 2 本指クリックで右クリック オフ
    TrackpadCornerSecondaryClick = 2;             # 右下隅のクリックで右クリック
  };
  dock = {
    persistent-apps = [
      "/System/Applications/Apps.app"
      "/Applications/Google Chrome.app"
      "/System/Applications/System Settings.app"
      "/Applications/Discord.app"
      "/Applications/Notion.app"
      "/Applications/Visual Studio Code.app"
      "/Applications/cmux.app"
    ];
    persistent-others = [ "/Users/raita/Downloads" ];
  };
};
```

移植しないもの:
- 初期値のままの項目 (Dock の自動非表示、キーリピート、メニューバーの時計など)。書かなくても結果は同じ
- 入力ソース (ABC + 日本語ローマ字入力)。nix-darwin に対応する設定項目が無いため、新しい Mac では手動で設定する
- ウィンドウ位置・最近使った項目などの、アプリが自動で保存する状態

**nix/modules/darwin/homebrew.nix**

```nix
homebrew = {
  enable = true;
  onActivation = {
    cleanup = "uninstall";   # 宣言していない formula / cask をアンインストール
    autoUpdate = false;      # switch のたびに brew update しない (速度優先)
    upgrade = false;         # 勝手にアップグレードしない (cask は各アプリの自動更新に任せる)
  };
  brews = [
    "colima" "docker" "docker-buildx" "docker-compose" "docker-completion"
  ];
  casks = [
    "ghostty"
    "google-chrome" "discord" "notion" "visual-studio-code" "cmux"
  ];
};
```

- `cleanup` は `"zap"` (アプリの設定データまで消す) ではなく `"uninstall"` にする。うっかり宣言から外したアプリの設定が消える事故を防ぐため
- ただし **初回適用は `"none"` で行い、Nix 版の動作確認後に `"uninstall"` へ切り替える** (下記「適用手順」)

**nix/modules/home/packages.nix**
- `home.packages`:
  - brew から移す CLI: eza, starship, jq, tree, gitleaks, git-secrets, go-task, awscli2, terraform
  - npm から移すもの: `claude-code` (nixpkgs 版は自動更新が無効化されている。更新は `nix flake update`)
  - VS Code の Nix 拡張 (`jnoortheen.nix-ide`) 用: `nixd` (言語サーバー), `nixfmt` (フォーマッタ)。`vscode/settings.json` から dotfiles の flake を読み込み、nix-darwin / home-manager のオプションを補完できるようにしている
  - **デフォルトの言語ランタイム**: `nodejs_24`, `pnpm`, `go_1_27` (Python はデフォルトでは入れず、必要なプロジェクトの devShell で用意する)
- すべて nixpkgs (aarch64-darwin) に存在することを確認済み

**nix/modules/home/git.nix**
- `programs.git` で name / email を設定 (今の `~/.gitconfig` と同じ内容)
- Nix 版 git は macOS のコマンドラインツールの gitconfig (`credential.helper=osxkeychain`) を読まないため、`gh.nix` の `programs.gh.gitCredentialHelper` で GitHub の認証を `gh auth git-credential` に任せる。`~/.config/gh/config.yml` も home-manager 管理になる (ログイン情報の `hosts.yml` はそのまま)
- home-manager は `~/.config/git/config` に書き出す。`~/.gitconfig` が残っているとそちらも読まれるため、適用後に削除する

**nix/modules/home/direnv.nix**
- `programs.direnv.enable = true;`
- `programs.direnv.nix-direnv.enable = true;` (devShell をキャッシュし、`cd` のたびに再評価しない)
- 注意: zshrc を home-manager の `programs.zsh` ではなく symlink で管理するため、`enableZshIntegration` は効かない。**`eval "$(direnv hook zsh)"` を zshrc に自分で書く**

**nix/modules/home/dotfiles.nix**
- `dotfilesDir = "/Users/raita/Repository/dotfiles"` として、すべて `config.lib.file.mkOutOfStoreSymlink` でリポジトリへ symlink する

| リポジトリ | リンク先 | 単位 |
|---|---|---|
| `zsh/zshrc` | `~/.zshrc` | ファイル |
| `zsh/zprofile` | `~/.zprofile` | ファイル |
| `ghostty/` | `~/.config/ghostty` | **ディレクトリ** |
| `cmux/` | `~/.config/cmux` | **ディレクトリ** |
| `vscode/settings.json` | `~/Library/Application Support/Code/User/settings.json` | ファイル |

- ghostty / cmux を **ディレクトリごと** リンクする理由: アプリが設定を保存するとき「一時ファイルに書いてから置き換える」方式だと、ファイル単位の symlink は普通のファイルに置き換わってリンクが切れる。ディレクトリごとリンクすれば、置き換えもリポジトリ内で起きるので切れない
  - cmux は設定変更時に `cmux.json.<日時>.bak` を作るため、`.gitignore` に `cmux/*.bak` を追加する
- VS Code は `User/` 以下に履歴やキャッシュ (`globalStorage`, `History`, `workspaceStorage`) があるため、ディレクトリではなく `settings.json` だけをリンクする (VS Code は symlink 先をそのまま書き換えるので問題ない)
- Ghostty は今 `~/Library/Application Support/com.mitchellh.ghostty/config` を使っているが、`~/.config/ghostty/config` に移す (他の設定と `~/.config` 以下に揃えるため。Ghostty は両方を読む)
- 各アプリの画面から設定を変えると、リポジトリのファイルが直接書き換わる。変更は `git diff` で確認できる
- Claude Code のリンクは `programs/claude-code.nix` で行う (下記)

**nix/modules/home/programs/claude-code.nix** (ryoppippi さんの `nix/modules/home/programs/claude-code/` と同じ構成)
- 設定フォルダは `~/.claude` のまま (`CLAUDE_CONFIG_DIR` で `~/.config/claude` へは移さない)
- `home.packages` に `claude-code` (nixpkgs 版)
- **settings.json はリンクではなくマージ**: Nix に書いた設定 (`permissions.defaultMode`, `skipDangerousModePermissionPrompt`, `theme`) を、switch のたびに jq で `~/.claude/settings.json` へマージする
  - Nix に書いたキーは Nix の値で上書きされ、`/config` や `/permissions`、プラグインの操作で Claude Code が書いたキーはそのまま残る
  - リンクにしないので、Claude Code がファイルを置き換えてもリンクが切れる心配がない
  - マージ後に JSON スキーマで検証する (失敗しても switch は止めない)
- リンク:

| リポジトリ | リンク先 |
|---|---|
| `agents/AGENTS.md` | `~/.claude/CLAUDE.md` |
| `agents/shared/` | `~/.claude/shared` |
| `agents/skills/<name>/` | `~/.claude/skills/<name>` (ディレクトリを追加すると自動でリンク対象になる) |
| `claude/commands/` | `~/.claude/commands` |
| `claude/agents/` | `~/.claude/agents` |
| `claude/output-styles/` | `~/.claude/output-styles` |

- 管理しないもの: `skills/synced/` (claude.ai から同期)、`projects/` (会話とメモリ)、`history.jsonl` などの履歴・キャッシュ、`~/.claude.json` (ログイン状態などアカウント情報を含む)
- 外部のスキルは取り込まない。ryoppippi さんが使っている agent-skills-nix は入れず、自作スキルはリンクで配置する
- `.claude/settings.json` (リポジトリ直下): このリポジトリで Claude Code がファイルを編集したら `nix fmt` を実行するフック

**vscode/extensions.txt**
- 拡張機能 (現在 21 個) の一覧。Nix では管理せず、一覧ファイルとして持つ
- 書き出し: `code --list-extensions > vscode/extensions.txt`
- 新しい Mac での導入: `xargs -n1 code --install-extension < vscode/extensions.txt` (README に記載)
- home-manager の `programs.vscode` は VS Code 本体も Nix で入れる前提のため使わない (本体は cask)

**zsh/zprofile** (今の `~/.zprofile` から変更する点)
- `path+=(/opt/homebrew/opt/go/bin)` と `path+=(/opt/homebrew/opt/node@20/bin)` を削除 (Nix 版を使う)
- `brew shellenv` は残すが、**Nix のパスより後ろ** に Homebrew を置く。今のままだと `/opt/homebrew/bin` が先頭に来て、移行期間中に brew 版が優先されてしまうため

**zsh/zshrc** (今の `~/.zshrc` から変更する点)
- `eval "$(nodenv init - zsh)"` を削除
- `eval "$(direnv hook zsh)"` を追加
- `fpath=(/opt/homebrew/share/zsh/site-functions ...)` は docker 系の補完のために残し、Nix 由来の補完 (`/etc/profiles/per-user/raita/share/zsh/site-functions`) も追加
- それ以外 (history, eza alias, starship) はそのまま

**templates/node/flake.nix**
- 各プロジェクトに置く devShell の雛形。プロジェクト側で使うときは `.envrc` に `use flake` と書く

```nix
devShells.default = pkgs.mkShell {
  packages = [ pkgs.nodejs_22 pkgs.pnpm ];   # プロジェクトに合わせて変える
};
```

## 適用手順

### 0. 事前準備 (手動)

```sh
# brew 管理外の GUI アプリを Homebrew に引き取らせる (再インストールせずに管理下へ入れる)
brew install --cask --adopt google-chrome discord notion visual-studio-code cmux
```

今の設定ファイルをリポジトリへコピーする (ファイル作成時に実施。symlink 先が空にならないように、初回適用より前に済ませる):

```sh
cd ~/Repository/dotfiles
cp ~/.zshrc zsh/zshrc && cp ~/.zprofile zsh/zprofile          # その後、上記の変更点を反映
cp ~/Library/Application\ Support/com.mitchellh.ghostty/config ghostty/config
cp ~/.config/cmux/cmux.json cmux/
cp ~/Library/Application\ Support/Code/User/settings.json vscode/
cp -R ~/.claude/skills/fu-calculation ~/.claude/skills/fu-calculation-quiz agents/skills/
code --list-extensions > vscode/extensions.txt
```

### 1. 初回適用 (`cleanup = "none"` の状態で)

```sh
cd ~/Repository/dotfiles
git add -A   # flake は git 管理下のファイルしか見ないため必須

# darwin-rebuild がまだ無いので nix run 経由
sudo nix run nix-darwin -- switch --flake .#raita-mba
```

初回適用で起きること:
- ホスト名が `raita-mba` に変わる
- `/etc/nix/nix.conf`, `/etc/zshrc` などが nix-darwin 管理になる (既存ファイルは `*.before-nix-darwin` に退避される)
- `~/.zshrc`, `~/.zprofile`, `~/.gitconfig`, `~/.config/cmux`, VS Code の `settings.json`, `~/.claude/skills/fu-calculation*` は home-manager 管理の symlink に置き換わる (既存は `*.before-nix` に退避)
- `~/.claude/settings.json` は普通のファイルのまま、Nix の設定がマージされる
- 適用後、古い Ghostty 設定 `~/Library/Application Support/com.mitchellh.ghostty/config` を削除する (残すと `~/.config/ghostty/config` と二重に読まれる)
- `~/.config/cmux/*.bak` の古いバックアップは、退避先 (`~/.config/cmux.before-nix`) ごと確認して削除してよい
- `~/.config/nix/nix.conf` は `/etc/nix/nix.conf` 側と重複するので、適用後に削除してよい

### 2. 動作確認

新しいターミナルを開いて確認する:

```sh
which jq node go claude starship   # /etc/profiles/per-user/raita/bin/... になっていれば OK
node --version                     # v24.21.0
go version                         # go1.27.2
claude --version                   # 2.1.300 (Claude Code)
```

Claude Code の設定を確認する:

```sh
ls -la ~/.claude/CLAUDE.md ~/.claude/skills   # dotfiles/agents/ へのリンクになっているか
cat ~/.claude/settings.json                  # "$schema" が追加され、enabledPlugins などは残っているか
```

### 3. Homebrew の整理

1. `homebrew.nix` の `cleanup` を `"uninstall"` に変更して `sudo darwin-rebuild switch --flake .`
   - 宣言していない formula (下記「削除するもの」) が一括でアンインストールされる
2. nodenv の残骸を削除: `rm -rf ~/.nodenv`
   - **先に `which claude` が `/etc/profiles/per-user/raita/bin/claude` (Nix 版) になっていることを確認する**。今の Claude Code は nodenv の中に入っているため
3. 公式 pkg で入れた Go を削除: `sudo rm -rf /usr/local/go` (Nix 版の `go_1_27` に一本化)
4. Homebrew のアンインストールでは消えない残りを削除:
   - DB のデータ: `rm -rf /opt/homebrew/var/mysql /opt/homebrew/var/postgresql@14` (残したいデータは無いことを確認済み)
   - herdr の設定: `~/.config/herdr`
   - git の旧設定: `~/.gitconfig` (内容は `~/.config/git/config` に移行済み)
   - インストールスクリプトで入れた starship: `sudo rm /usr/local/bin/starship` (Nix 版に一本化)
   - uv の残り: `~/.local/share/uv` (uv で入れた Python, 約 50MB)、`~/.cache/uv`、`~/.local/bin/python3.12` (uv tool で入れたツールは無し)

### 4. 既存プロジェクトの Node 移行

nodenv を消すと、`.node-version` で版を指定していたプロジェクトは nodenv が効かなくなり、デフォルトの node 24 で動く。node 24 以外を使うプロジェクトは、使うときに順次 devShell を用意する:

```sh
cd ~/Repository/<project>
nix flake init -t ~/Repository/dotfiles#node   # 雛形を置いてバージョンを編集
echo "use flake" > .envrc && direnv allow
```

### 以後の運用

```sh
sudo darwin-rebuild switch --flake .                         # 設定を反映
nix flake update && sudo darwin-rebuild switch --flake .     # パッケージ更新
```

## Homebrew の整理内容

| 区分 | 対象 | 扱い |
|---|---|---|
| Nix へ移す | eza, starship, gh (programs.gh), jq, tree, gitleaks, git-secrets, go-task, awscli, terraform, go | `home.packages` へ。cleanup で brew 版は削除 |
| brew に残す | docker, docker-buildx, docker-compose, docker-completion, colima | `homebrew.brews` で宣言 |
| cask | ghostty, google-chrome, discord, notion, visual-studio-code, cmux | `homebrew.casks` で宣言 |
| 削除する | node, node@20, nodenv | Node はデフォルト `nodejs_24` + devShell に置き換え |
| 削除する | uv, python@3.12 | Python はグローバルに入れない。必要なプロジェクトの devShell で用意する (macOS 標準の `/usr/bin/python3` は残る) |
| 削除する | sqlc, golangci-lint, gotests | Go の開発ツール。必要になったらプロジェクトの devShell に入れる |
| 削除する | wget, shellcheck, duckdb, aspell | 使っていない |
| 削除する | mysql, postgresql@14 | DB は必要なら docker (colima) で立てる |
| 削除する | herdr, herdr-gpui | 使っていない |
| 削除する | php, rtmpdump, cryptography, icu4c@75, icu4c@77, zlib | 他から依存されていない formula |

補足:
- mysql / postgresql@14 をアンインストールしても、データ (`/opt/homebrew/var/mysql`, `/opt/homebrew/var/postgresql@14`) は残るため、手順 3-4 で削除する
- `brew` 本体は残る (nix-homebrew で本体ごと Nix 管理にするのは Phase 2 以降)

## Phase 2 以降の候補

- starship の設定ファイルもリポジトリで管理 (今は `~/.config/starship.toml` が無く、初期設定のまま)
- Node 26 の LTS 入り後、デフォルトを `nodejs_26` に上げるか検討
- Go / Python など、Node 以外の devShell テンプレート (Python はグローバルから外したため、使うときに優先して用意する)
- `nix run .#switch` などの apps (ryoppippi さんの `nix/flake/apps/`)
- flake-parts への移行、treefmt-nix によるフォーマット
- nix-homebrew で Homebrew 本体も Nix 管理に
- GitHub Actions で `nix flake check` / 定期的な `flake update`
- Neovim 設定 (使うなら)

## 実装メモ (2026-10-18)

- `sudo` を使わない `nix build .#darwinConfigurations.raita-mba.system` でビルドが通ることを確認済み (警告なし)。`nix fmt` も差分なし
- 入る主なバージョン: node 24.21.0 / go 1.27.2 / Claude Code 2.1.300 (nixpkgs 2026-10-16 時点)
- `home.stateVersion = "26.11"` (home-manager の現行リリース)
- `homebrew.onActivation.cleanup` は初回適用用に `"none"` にしてある。手順 3 で `"uninstall"` に変える
- zsh の PATH は `/etc/profiles/per-user/raita/bin` (Nix) → … → `/usr/bin` → `/opt/homebrew/bin` の順になる (zprofile で Homebrew を末尾へ移動)
- `cmux/disabled/` (cmux 0.65.1 の ⌘N 不具合への旧回避策。automation ルールと起動スクリプト) は使われていないため削除した。`cmux.json` の `"shortcut": "cmd+n"` による回避策に置き換え済み。中身はコミット `c8776cd` に残っている
