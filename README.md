# dotfiles

raita の macOS 環境。Nix flake (nix-darwin + home-manager) で管理する。

## 構成

| パス | 内容 |
|---|---|
| `flake.nix` | inputs、`darwinConfigurations."raita-mba"`、外部向けの `darwinModules.default` / `homeModules.default` |
| `nix/modules/darwin/` | 端末ごとの値の定義 (`options.nix`)、macOS のシステム設定 (`system.nix`)、Homebrew の共通設定と単体の cask (`homebrew.nix`)、home-manager の読み込み (`home-manager.nix`) |
| `nix/modules/darwin/programs/<tool>.nix` | cask と設定ファイルの両方を持つツール (VS Code、cmux)。cask、拡張機能、symlink を 1 ファイルにまとめる |
| `nix/hosts/raita-mba.nix` | 個人用 Mac だけの設定 (ユーザー名・ホスト名、個人用の cask と VS Code 拡張機能) |
| `nix/modules/home/` | home-manager: 設定を持たない CLI ツール (`packages.nix`) |
| `nix/modules/home/programs/<tool>.nix` | 設定を持つツール (zsh、starship、git、gh、direnv、Claude Code、Codex、pi)。パッケージ、symlink、設定を 1 ファイルにまとめる |
| `zsh/`, `starship/`, `cmux/`, `vscode/`, `claude/`, `agents/` | 設定ファイル本体。ホームへ symlink される (編集は即反映、rebuild 不要) |
| `nix/apps.nix` | `nix run .#switch` などの操作 |
| `templates/node/` | プロジェクト用 devShell の雛形 |

| リポジトリ | リンク先 |
|---|---|
| `zsh/zshrc` | `~/.zshrc` |
| `zsh/zprofile` | `~/.zprofile` |
| `starship/starship.toml` | `~/.config/starship.toml` |
| `cmux/` | `~/.config/cmux` |
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
| 端末ごとの値 | `dotfiles.username` / `hostname` (必須)、`homedir`、`dir`、`dock.apps` / `dock.others` | そのまま書く。Dock は指定すると丸ごと置き換わる |
| 初期値 (mkDefault) | `homebrew.onActivation.*`、`nix.gc.*`、`nix.package`、`networking.*Name`、`security.pam.services.sudo_local.touchIdAuth`、`system.defaults.*`、git の `user.name` / `user.email`、gh の `git_protocol`、`dotfiles.claudeCode.settings.*` | そのまま書けば上書きされる |
| リスト | `home.packages`、`homebrew.brews` / `casks` / `vscode`、`dotfiles.claudeCode.plugins`、`dotfiles.claudeCode.extraSkills` (名前 → ディレクトリ)、`nix.settings.trusted-users` など | 書いた分が追加される。外すには `lib.mkForce` でリストを丸ごと指定する |
| 構成の前提 | `system.stateVersion`、`home.stateVersion`、`home-manager.useGlobalPkgs` / `useUserPackages`、`programs.zsh.enable` など | 違う値を書くとエラーになる。変えるなら `lib.mkForce` (基本は変えない) |
| 共通のファイル | zshrc、zprofile、starship、cmux、VS Code の settings.json、CLAUDE.md、skills (このリポジトリへの symlink) | zsh は `~/.zshrc.local` に追記する。丸ごと差し替えるなら `home.file."<パス>".source` を `lib.mkForce` |

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

