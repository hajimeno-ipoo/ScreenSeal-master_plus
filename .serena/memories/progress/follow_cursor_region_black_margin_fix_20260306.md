状態: 完了

変更点（仕様変更）
- Follow Cursor を ON にした全画面録画の常時追従仕様は維持。
- 範囲選択録画で黒い余白が出る不具合のみを修正。

変更点（内部実装）
- RecordingService.applyFollowCursorCamera で切り抜きサイズを image.extent 以内に制限。
- 画像全体と同じサイズになった軸は extent の中央を使うようにし、片寄りと黒余白を防止。
- FOR[hazimeno_ipoo].md に今回の不具合と修正方法を追記。

影響範囲
- 録画時の Follow Cursor カメラ計算のみ。設定保存やUI文言には非影響。

検証結果
- xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
- git diff --check -- ScreenSeal/Services/RecordingService.swift FOR[hazimeno_ipoo].md

リスク
- 実機で範囲選択の待機時カメラとクリック中ズームの見え方を最終確認したい。

ロールバック方法
- RecordingService.applyFollowCursorCamera の切り抜き上限と中央固定を元に戻す。