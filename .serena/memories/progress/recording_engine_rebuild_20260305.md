変更点（仕様変更）
- 録画エンジンを SCRecordingOutput から SCStreamOutput + AVAssetWriter に切替。
- クリックズームは録画出力にのみ適用、モザイクウィンドウ表示は固定に維持。

変更点（内部実装）
- RecordingService に screen/audio サンプル処理、ズームROI適用、finishWriting 確定処理を実装。
- 停止経路を統合し、アプリ停止/システム停止のどちらでも finalizeRecording で後始末。
- WindowManager の canStopRecording を recordingState 基準に変更し、failed/idle で service参照を解除。

影響範囲
- 録画開始/停止、録画中のメニュー状態、録画ファイル生成処理に影響。
- 既存モザイク表示フローはズーム非適用のまま維持。

検証結果
- xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
- xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | rg -n "RecordingService.swift:|warning:"

リスク
- 実機での長時間録画とシステム停止ボタン経由停止の挙動は未確認。

ロールバック
- RecordingService.swift / WindowManager.swift の今回差分を戻すと旧挙動に復帰可能。