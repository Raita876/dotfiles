{ config, ... }:
let
  # リポジトリ内のファイルへ直接 symlink する (編集が即反映され、rebuild 不要)
  link = path: config.lib.file.mkOutOfStoreSymlink "${config.dotfiles.dir}/${path}";
in
{
  home.file = {
    ".zshrc".source = link "zsh/zshrc";
    ".zprofile".source = link "zsh/zprofile";
    # VS Code は User/ 以下に履歴やキャッシュがあるので settings.json だけをリンクする
    "Library/Application Support/Code/User/settings.json".source = link "vscode/settings.json";
  };

  # アプリが「一時ファイルに書いてから置き換える」方式で保存してもリンクが切れないよう、
  # ディレクトリごとリンクする
  xdg.configFile = {
    "ghostty".source = link "ghostty";
    "cmux".source = link "cmux";
  };
}
