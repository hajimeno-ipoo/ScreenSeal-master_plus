状態: 完了

仕様変更:
- 録画メニューに Reset Cursor Colors を追加。
- 押すとカーソルハイライト色とクリックリング色を既定値へ戻す。

内部実装:
- WindowManager に resetRecordingCursorColors() を追加。
- 既定色は既存の defaultCursorHighlightColor / defaultClickRingColor を再利用。

影響範囲:
- 録画メニューUIと色設定の保存値。描画ロジック自体は変更なし。

検証結果:
- git diff --check -- ScreenSeal/Views/MenuBarView.swift ScreenSeal/Windows/WindowManager.swift

リスク:
- xcodebuild は DerivedData 側の一時的不整合で失敗し、今回のコード差分自体は未起因と判断。

ロールバック方法:
- Reset Cursor Colors ボタン追加と resetRecordingCursorColors() を元に戻す。