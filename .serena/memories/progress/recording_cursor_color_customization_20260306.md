状態: 完了

仕様変更:
- 録画メニューに Cursor Highlight Color / Click Ring Color を追加。
- 色と透明度を UserDefaults に保存し、次回起動後も保持する。

内部実装:
- WindowManager に録画用色設定と NSColor Data 永続化を追加。
- RecordingService が録画開始時に色を受け取り、既存描画へ反映するよう変更。

影響範囲:
- 録画メニューUI、録画開始時の設定引き渡し、録画時のカーソル演出描画。

検証結果:
- xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Release build

リスク:
- ColorPicker の実機メニュー上の見え方は macOS バージョン差の影響を受ける可能性がある。

ロールバック方法:
- 追加した色設定プロパティと ColorPicker、RecordingService の引数追加を元に戻す。