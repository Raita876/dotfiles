# dotfiles

raita の macOS 環境。Nix flake (nix-darwin + home-manager) で管理する。

- 設計とその理由: [docs/plan.md](docs/plan.md)
- 他の人の dotfiles の調査: [docs/survey.md](docs/survey.md)

## 構成

| パス | 内容 |
|---|---|
| `flake.nix` | inputs と `darwinConfigurations."raita-mba"` |
| `nix/modules/darwin/` | macOS のシステム設定 (`system.nix`)、Homebrew (`homebrew.nix`) |
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

# 4. VS Code の拡張機能を入れる
xargs -n1 code --install-extension < vscode/extensions.txt
```

入力ソース (ABC + 日本語ローマ字入力) は nix-darwin で設定できないので、システム設定から手動で追加する。

## 日常の操作

```sh
sudo darwin-rebuild switch --flake .                       # 設定を反映
sudo darwin-rebuild build --flake .                        # ビルドだけ (エラー確認)
nix flake update && sudo darwin-rebuild switch --flake .   # パッケージを更新
sudo darwin-rebuild --rollback                             # 1 つ前の世代に戻す
nix fmt                                                    # .nix ファイルを整形
code --list-extensions > vscode/extensions.txt             # VS Code 拡張機能の一覧を更新
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
