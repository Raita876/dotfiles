# dotfiles

raita の macOS 環境。Nix flake (nix-darwin + home-manager) で管理する。

## 構成

| パス | 内容 |
|---|---|
| `flake.nix` | inputs、`darwinConfigurations."raita-mba"`、外部向けの `darwinModules.default` / `homeModules.default` |
| `nix/modules/darwin/` | 端末ごとの値の定義 (`options.nix`)、macOS のシステム設定 (`system.nix`)、Homebrew の共通設定と単体の cask (`homebrew.nix`)、home-manager の読み込み (`home-manager.nix`) |
| `nix/modules/darwin/programs/<tool>.nix` | cask と設定ファイルの両方を持つツール (VS Code、cmux、Herdr)。cask、拡張機能、symlink を 1 ファイルにまとめる |
| `nix/hosts/raita-mba.nix` | 個人用 Mac だけの設定 (ユーザー名・ホスト名、個人用の cask と VS Code 拡張機能) |
| `nix/modules/home/` | home-manager: 設定を持たない CLI ツール (`packages.nix`) |
| `nix/modules/home/programs/<tool>.nix` | 設定を持つツール (zsh、starship、git、gh、direnv、Claude Code、Codex、pi)。パッケージ、symlink、設定を 1 ファイルにまとめる |
| `zsh/`, `starship/`, `cmux/`, `herdr/`, `vscode/`, `claude/`, `agents/`, `pi/` | 設定ファイル本体。ホームへ symlink される (編集は即反映、rebuild 不要) |
| `nix/apps.nix` | `nix run .#switch` などの操作 |
| `templates/node/` | プロジェクト用 devShell の雛形 |

| リポジトリ | リンク先 |
|---|---|
| `zsh/zshrc` | `~/.zshrc` |
| `zsh/zprofile` | `~/.zprofile` |
| `starship/starship.toml` | `~/.config/starship.toml` |
| `cmux/` | `~/.config/cmux` |
| `herdr/keys.json` | `~/.config/herdr-app/keys.json` |
| `herdr/mods/pi-space/` | `~/.config/herdr-app/mods/pi-space/` |
| `vscode/settings.json` | `~/Library/Application Support/Code/User/settings.json` |
| `agents/AGENTS.md` | `~/.claude/CLAUDE.md`、`~/.codex/AGENTS.md`、`~/.pi/agent/AGENTS.md` |
| `agents/shared/` | `~/.claude/shared` |
| `agents/skills/<name>/` | `~/.claude/skills/<name>`、`~/.agents/skills/<name>` (Codex と pi が読む) |
| `claude/{commands,agents,output-styles}/` | `~/.claude/{commands,agents,output-styles}` |

## 新しい Mac でのセットアップ

```sh
# 1. Nix をインストール
curl --proto '=https' --tlsv1.2 -sSf -L https://nixos.org/nix/install | sh

# 2. このリポジトリを clone (symlink 先がこのパスなので場所は固定)
git clone <このリポジトリ> ~/Repository/dotfiles
cd ~/Repository/dotfiles

# 3. 適用 (初回は flakes がまだ有効でないのでオプションを付ける)
nix --extra-experimental-features 'nix-command flakes' run .#switch
```

VS Code の拡張機能も `homebrew.nix` の `vscode` から switch 時に入る。

入力ソース (ABC + 日本語ローマ字入力) は nix-darwin で設定できないので、システム設定から手動で追加する。

## 日常の操作

```sh
nix run .#switch                  # 設定を反映
nix run .#build                   # ビルドだけ (エラー確認)
nix run .#update                  # flake.lock を更新してビルドを確認 (反映は switch)
sudo darwin-rebuild --rollback    # 1 つ前の世代に戻す
nix fmt                           # .nix ファイルを整形
```

`nix run ~/Repository/dotfiles#switch` のように指定すれば、どのディレクトリからでも実行できる。

新しく追加したファイルは `git add` してから適用する (flake は git 管理下のファイルしか見ない)。

switch するとこのリポジトリに pre-commit フックが入る (`nix/modules/home/git-hooks.nix`)。コミット時に gitleaks で秘密情報を検査し、整形されていない .nix ファイルがあれば止める。

### Herdr のショートカット

Herdr の macOS アプリ版のキー設定を `herdr/keys.json` で管理する。`⌘N` は `herdr/mods/pi-space/` を介して Pi 入りのスペースを作成する。cmux との対応と差分は [herdr/README.md](herdr/README.md) を参照。
セッション・レイアウト・配布済み mods は共有しない。

PR のマージ後、通常の `~/Repository/dotfiles` で `nix run .#switch` を実行する。既存の `~/.config/herdr-app/keys.json` は、既定では Home Manager が `keys.json.before-nix` に自動退避する。安全のため事前の手動バックアップを推奨する。自動退避先が既に存在する場合は、別名に移してから実行する。
以後キー設定の編集は即反映される。Herdr の設定リセットで symlink が置き換わった場合も、退避先の重複に注意して再度 `switch` する。

## Oh My Pi

Oh My Pi (`omp`) は公式 flake の Home Manager モジュールで導入する。既存の `pi` は残し、cmux の既定エージェントも変更しない。

設定は `~/.omp/agent/config.yml` で管理し、pi の設定・拡張とは分ける。現時点では `programs.omp.settings` を宣言せず、OMP 側の設定変更を保持する。今後このオプションを指定する場合、Home Manager の適用時に設定ファイル全体が宣言内容で上書きされる。

本体の更新は `flake.lock` 経由で行う。

## プロジェクトごとの開発環境

デフォルトでは Node.js 26 / Go 1.27 が入っている。プロジェクトで別のバージョンを使うときは devShell を置く:

```sh
cd ~/Repository/<project>
nix flake init -t ~/Repository/dotfiles#node   # flake.nix と .envrc が置かれる
# flake.nix の nodejs_26 などを編集
direnv allow                                   # 以後 cd するだけで読み込まれる
```

## 職場など別の Mac で使う

`darwinModules.default` を別の flake (職場用の非公開リポジトリなど) から読み込み、端末ごとの値を設定する。
社内ツール名や会社のメールアドレスは読み込む側に書くので、このリポジトリには載らない。

```nix
{
  inputs = {
    dotfiles.url = "github:Raita876/dotfiles";
    nixpkgs.follows = "dotfiles/nixpkgs";
    nix-darwin.follows = "dotfiles/nix-darwin";
  };

  outputs = { nix-darwin, dotfiles, ... }: {
    darwinConfigurations.work-mac = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        dotfiles.darwinModules.default
        {
          dotfiles = {
            username = "<ユーザー名>";
            hostname = "work-mac";
          };

          # リスト (casks / brews / vscode など) は共通分に追加される
          homebrew.casks = [ "slack" ];
          # 1 つしか値を持てない設定は mkDefault にしてあるので、普通に書けば上書きできる
          homebrew.onActivation.cleanup = "none";
          home-manager.users."<ユーザー名>".programs.git.settings.user.email = "<会社のメールアドレス>";
        }
      ];
    };
  };
}
```

- zshrc などはこのリポジトリへの symlink なので、読み込む側の Mac にもこのリポジトリを `dotfiles.dir` (既定は `~/Repository/dotfiles`) に clone しておく
- 設定できる値は `nix/modules/darwin/options.nix` を参照
- 共通で入るのは `nix/modules/` の分だけ。個人用の cask や VS Code 拡張機能は `nix/hosts/raita-mba.nix` にあるので、職場の Mac には入らない

### 読み込む側から変えられる値

| 種類 | 値 | 変え方 |
|---|---|---|
| 端末ごとの値 | `dotfiles.username` / `hostname` (必須)、`homedir`、`dir`、`dock.apps` / `dock.others`、`cmux.agent` (cmux で起動するエージェント。`"pi"` (既定)、`"claude"`、`"codex"`) | そのまま書く。Dock は指定すると丸ごと置き換わる |
| 初期値 (mkDefault) | `homebrew.onActivation.*`、`nix.gc.*`、`nix.package`、`networking.*Name`、`security.pam.services.sudo_local.touchIdAuth`、`system.defaults.*`、git の `user.name` / `user.email`、gh の `git_protocol`、`dotfiles.claudeCode.settings.*` | そのまま書けば上書きされる |
| リスト | `home.packages`、`homebrew.brews` / `casks` / `vscode`、`dotfiles.claudeCode.plugins`、`dotfiles.claudeCode.extraSkills` (名前 → ディレクトリ)、`nix.settings.trusted-users` など | 書いた分が追加される。外すには `lib.mkForce` でリストを丸ごと指定する |
| 構成の前提 | `system.stateVersion`、`home.stateVersion`、`home-manager.useGlobalPkgs` / `useUserPackages`、`programs.zsh.enable` など | 違う値を書くとエラーになる。変えるなら `lib.mkForce` (基本は変えない) |
| 共通のファイル | zshrc、zprofile、starship、cmux、Herdr の keys.json、VS Code の settings.json、CLAUDE.md、skills (このリポジトリへの symlink) | zsh は `~/.zshrc.local` に追記する。丸ごと差し替えるなら `home.file."<パス>".source` を `lib.mkForce` |

home-manager 側の値は `home-manager.users."<ユーザー名>"` の下に書く。例えば Claude Code の権限モードを変えるなら:

```nix
home-manager.users."<ユーザー名>".dotfiles.claudeCode.settings.permissions.defaultMode = "default";
```

職場用のプラグインやスキルを足すなら:

```nix
home-manager.users."<ユーザー名>".dotfiles.claudeCode = {
  marketplaces.company-plugins = "<org>/<repo>";
  plugins = [ "some-tool@company-plugins" ];
  extraSkills.internal-deploy = ./skills/internal-deploy;   # ~/.claude/skills/internal-deploy になる
};
```

`dotfiles.claudeCode.settings` は switch のたびに `~/.claude/settings.json` へマージされる。ここに書いたキーが優先され、書いていないキーは Claude Code 側で変えた値のまま残る。

### Pi の拡張パッケージの更新

Pi の設定は書き込み可能なまま維持する。`switch` 時に Home Manager が設定をマージした後、Nix 管理の `pi-extensions-node-modules` の旧 store パスを除去する。拡張の更新で store パスが変わっても二重ロードされず、すでに旧パスが残っている環境も次回の `switch` で解消される。

手動追加した npm / git / ローカルパッケージや、それ以外の Pi の設定は保持される。適用中の設定の書き戻しを避けるため、**`switch` の前に Pi を終了する**。

### Codex のレビュー用プラグイン

`dotfiles.codex.plugins` に指定したプラグインは、`switch` 時に未インストールなら追加される。初回は Codex へのログインとネットワーク接続が必要。失敗した場合は次の `switch` で再試行する。インストール済みのものの更新・削除は行わない。

| プラグイン | 用途 |
|---|---|
| `codex-security@openai-curated-remote` | 脆弱性の調査と修正方針の確認 |
| `engineering-suite-review@openai-curated-remote`（表示名: Review、作者: Saul Martí） | 正しさ・可読性・設計・セキュリティ・性能のレビュー |

インストール後は新しいチャットを開始する。普段のレビューでは Review の `code-review-and-quality` スキルを選び、例えば次のように依頼する。

```text
engineering-suite-review の code-review-and-quality を使って、
main との差分をレビューしてください。コードは変更せず、
バグ・テストの不足・エラー処理を優先し、根拠のファイルと行番号を示してください。
```

Review 2.0.0 の `code-review` は仕様と規約を並列に照合する別スキルで、`docs/agents/issue-tracker.md` と仕様の所在を前提にする。通常の品質レビューは上記の `code-review-and-quality` を使う。ブラウザ検証スキルには別途 Chrome DevTools MCP が必要だが、通常のコードレビューには不要。

候補を比較した結果、論文・調査資料向けの `ai-review-skills` と、既存のレビュー bot の指摘を修正・push する `gh-review-loop` は採用していない。ローカル差分を手軽に確認する場合は、標準の `/review` も使える。

### 共通の PR レビュー

`agents/skills/pr-review/` は Claude Code・Codex・Pi 共通の skill。既存の skill 配置規則により、Claude Code には `~/.claude/skills/pr-review`、Codex と Pi には `~/.agents/skills/pr-review` として配置する。レビュー指示は独自に記述しており、他の環境でもこの skill ディレクトリをコピーすれば使える。git と、PR モードでは認証済みの gh が必要。

各エージェントで `pr-review` skill を選択するか、次のように依頼する。skill の呼び出し UI・構文は各 CLI に従う。

```text
pr-review skill を使って、main との差分を tests と errors の観点でレビューしてください。
```

レビュー観点・範囲・報告形式は共通にし、実行方式だけを `references/execution.md` に分離している。

| 利用可能な機能 | 実行方式 |
|---|---|
| サブエージェントへの委譲ツールあり | 現在公開されているツールの説明とスキーマに従って観点別に委譲。読み取り専用の reviewer があれば優先 |
| 委譲ツールなし | 単独で観点別に逐次レビューすることを明示。並列・独立した検証を明示要求された場合は切り替え前に確認 |

新しいサブエージェント拡張や名前付き agent 定義は追加しない。CLI 名だけで委譲機能の有効・無効を決めず、実際に使えるツールを確認する。単独実行を独立した複数 agent の検証として扱わない。

Pi では標準の skill 呼び出しを使う。

```text
/skill:pr-review code tests --base main
```

| 指定 | 対象 |
|---|---|
| 範囲の省略 | ステージ済み・未ステージ・未追跡を含む作業ツリーの最終状態 |
| `--base <ref>` | merge-base から HEAD のコミット済み差分。ローカル変更は除外 |
| `--pr <number>` | `gh` で取得した PR 差分。checkout や投稿はしない。認証済みの `gh` が必要 |
| `code` / `tests` / `errors` / `comments` / `types` | 指定観点でレビュー。省略または `all` はこの5観点から該当するものを選択 |
| `simplify` | 明示指定時のみ、振る舞いを保つ簡素化を提案。編集はしない |
| `parallel` / `sequential` | 委譲可能な環境では最大3件ずつの並列（既定）/ 1件ずつの逐次実行。委譲不可時の扱いは上記のとおり |

対象 SHA と差分を固定し、指摘をメイン agent が検証・重複排除して日本語で報告する。失敗した観点や未検証部分は別記する。コード編集、テスト実行、GitHub への投稿は行わない。実行が必要なら別途依頼する。これも指示による運用であり、読み取り専用の OS サンドボックスではない。

### 端末固有のシェル設定と秘密情報

`zsh/zshrc` は最後に `~/.zshrc.local` を読み込む。職場のツールの初期化 (gcloud の補完、nodenv など) はそこに書く。
API キーなどの秘密情報は、このリポジトリにも職場用のリポジトリにも入れず、さらに別のファイルに分ける。

```sh
# ~/.zshrc.local (どのリポジトリにも入れない)
[[ -f ~/.zshenv.secrets ]] && source ~/.zshenv.secrets
# 以下、職場のツールの初期化など

# ~/.zshenv.secrets (chmod 600 にする)
export SOME_API_KEY=...
```

