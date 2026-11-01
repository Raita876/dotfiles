import { View, div } from "gpui-kit";
import { closeOverlay, props, run } from "herdr";

export default class PiSpace extends View {
  init(_props, cx) {
    // オーバーレイの登録後に閉じられるよう、次のイベントループで実行する。
    cx.timer.after(0, () => {
      run("space.new", { argv: ["pi"] });
      closeOverlay(props().overlay);
    });
  }

  render() {
    return div();
  }
}
