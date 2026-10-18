# dotfiles

raita の macOS 環境。Nix flake (nix-darwin + home-manager) で管理する。

## 構成

| パス | 内容 |
|---|---|
| `flake.nix` | inputs、`darwinConfigurations."raita-mba"`、外部向けの `darwinModules.default` / `homeModules.default` |
| `nix/modules/darwin/` | 端末ごとの値の定義 (`options.nix`)、macOS のシステム設定 (`system.nix`)、Homebrew (`homebrew.nix`)、home-manager の読み込み (`home-manager.nix`) |
| `nix/hosts/raita-mba.nix` | 個人用 Mac だけの設定 (ユーザー名・ホスト名、個人用の cask と VS Code 拡張機能) |
| `nix/modules/home/` | home-manager: CLI ツール (`packages.nix`)、git、direnv、設定ファイルの symlink (`dotfiles.nix`) |
| `nix/modules/home/programs/claude-code.nix` | Claude Code 本体と設定 (settings.json は switch 時にマージ) |
| `zsh/`, `ghostty/`, `cmux/`, `vscode/`, `claude/`, `agents/` | 設定ファイル本体。ホームへ symlink される (編集は即反映、rebuild 不要) |
| `templates/node/` | プロジェクト用 devShell の雛形 |

| リポジトリ | リンク先 |
|---|---|
| `zsh/zshrc` | `~/.zshrc` |
| `zsh/zprofile` | `~/.zprofile` |
| `ghostty/` | `~/.config/ghostty` |
| `cmux/` | `~/.config/cmux` |
| `vscode/settings.json` | `~/Library/Application Support/Code/User/settings.json` |
| `agents/AGENTS.md` | `~/.claude/CLAUDE.md` |
| `agents/shared/` | `~/.claude/shared` |
| `agents/skills/<name>/` | `~/.claude/skills/<name>` |
| `claude/{commands,agents,output-styles}/` | `~/.claude/{commands,agents,output-styles}` |

## 新しい Mac でのセットアップ

```sh
# 1. Nix をインストール
curl --proto '=https' --tlsv1.2 -sSf -L https://nixos.org/nix/install | sh

# 2. このリポジトリを clone (symlink 先がこのパスなので場所は固定)
git clone <このリポジトリ> ~/Repository/dotfiles
cd ~/Repository/dotfiles

# 3. 適用 (初回は darwin-rebuild が無いので nix run 経由)
sudo nix --extra-experimental-features 'nix-command flakes' run nix-darwin -- switch --flake .#raita-mba
```

VS Code の拡張機能も `homebrew.nix` の `vscode` から switch 時に入る。

入力ソース (ABC + 日本語ローマ字入力) は nix-darwin で設定できないので、システム設定から手動で追加する。

## 日常の操作

```sh
sudo darwin-rebuild switch --flake .                       # 設定を反映
sudo darwin-rebuild build --flake .                        # ビルドだけ (エラー確認)
nix flake update && sudo darwin-rebuild switch --flake .   # パッケージを更新
sudo darwin-rebuild --rollback                             # 1 つ前の世代に戻す
nix fmt                                                    # .nix ファイルを整形
```

新しく追加したファイルは `git add` してから適用する (flake は git 管理下のファイルしか見ない)。

## プロジェクトごとの開発環境

デフォルトでは Node.js 24 / Go 1.27 が入っている。プロジェクトで別のバージョンを使うときは devShell を置く:

```sh
cd ~/Repository/<project>
nix flake init -t ~/Repository/dotfiles#node   # flake.nix と .envrc が置かれる
# flake.nix の nodejs_24 などを編集
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

