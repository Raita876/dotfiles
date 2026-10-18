{ config, dotfilesDir, ... }:
let
  # リポジトリ内のファイルへ直接 symlink する (編集が即反映され、rebuild 不要)
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/${path}";
in
{
  home.file = {
    ".zshrc".source = link "zsh/zshrc";
    ".zprofile".source = link "zsh/zprofile";
    # VS Code は User/ 以下に履歴やキャッシュがあるので settings.json だけをリンクする
    "Library/Application Support/Code/User/settings.json".source = link "vscode/settings.json";
    # ~/.claude には履歴やセッションもあるので、自分で管理するものだけをリンクする
    ".claude/settings.json".source = link "claude/settings.json";
    ".claude/skills/fu-calculation".source = link "claude/skills/fu-calculation";
    ".claude/skills/fu-calculation-quiz".source = link "claude/skills/fu-calculation-quiz";
  };

  # アプリが「一時ファイルに書いてから置き換える」方式で保存してもリンクが切れないよう、
  # ディレクトリごとリンクする
  xdg.configFile = {
    "ghostty".source = link "ghostty";
    "cmux".source = link "cmux";
  };
}
