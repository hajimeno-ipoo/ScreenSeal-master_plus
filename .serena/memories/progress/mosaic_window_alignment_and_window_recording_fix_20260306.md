状態: 完了

変更点（仕様変更）
- モザイク窓のプレビュー切り出し座標を録画側と同じ向きに統一した。
- ウィンドウ選択録画でも、選択ウィンドウに重なるモザイク窓が録画へ入るようにした。

変更点（内部実装）
- WindowManager.distributeFrame の Y 座標を screenFrame.maxY - windowRect.maxY に修正した。
- ResolvedRecordingTarget.window に displayID を追加し、RecordingService.start の window ケースを display + including windows + sourceRect に切り替えた。
- 録画開始時に overlayWindowIDs を渡し、対象ウィンドウとモザイク窓を同じ録画フィルタへ含めるようにした。
- FOR[hazimeno_ipoo].md に今回の座標系と単一ウィンドウ録画の注意点を追記した。

影響範囲
- モザイク窓プレビュー、全画面/範囲/ウィンドウ録画の座標合わせ、単一ウィンドウ録画の内容。

検証結果
- xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
- git diff --check -- ScreenSeal/Windows/WindowManager.swift ScreenSeal/Services/RecordingService.swift FOR[hazimeno_ipoo].md

リスク
- 実機では、選択ウィンドウの外に置いた別のモザイク窓が sourceRect 外で正しく切り捨てられるかを確認したい。

ロールバック方法
- RecordingService.start の window ケースを desktopIndependentWindow に戻し、WindowManager.distributeFrame の localY を旧式へ戻す。