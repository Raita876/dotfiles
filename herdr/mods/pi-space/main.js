import { View, div } from "gpui-kit";
import { closeOverlay, home, props, run } from "herdr";

export default class PiSpace extends View {
  init(_props, cx) {
    // オーバーレイの登録後に閉じられるよう、次のイベントループで実行する。
    cx.timer.after(0, () => {
      run("space.new", { argv: ["pi"], folder: home() });
      closeOverlay(props().overlay);
    });
  }

  render() {
    return div();
  }
}
