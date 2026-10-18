{ homedir, ... }:
{
  # 2026-10-15 時点でこの Mac の初期値から変更されていた設定 (defaults read で確認)
  system.defaults = {
    NSGlobalDomain = {
      # ダークモード
      AppleInterfaceStyle = "Dark";
      # ナチュラルスクロール オフ
      "com.apple.swipescrolldirection" = false;
    };

    # Finder をリスト表示
    finder.FXPreferredViewStyle = "Nlsv";

    trackpad = {
      # タップでクリック
      Clicking = true;
      # 2 本指クリックでの右クリックはオフにして、右下隅のクリックで右クリック
      TrackpadRightClick = false;
      TrackpadCornerSecondaryClick = 2;
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
      persistent-others = [ "${homedir}/Downloads" ];
    };
  };
}
