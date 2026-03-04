変更点（仕様変更）
- クリックズームを条件付きに変更。ボタン/リンククリックのみ拡大対象。
- クリック解除後すぐ縮小せず、2秒ホールド後に縮小する仕様を追加。

変更点（内部実装）
- PointerTrackingService に有効クリック判定（AXロール判定）とズーム状態機械を実装。
- 除外条件: 自アプリ要素、非前面アプリ要素、ボタン/リンク以外をズーム無効化。
- RecordingService は pointer snapshot の isZoomActive + zoomAnchorLocation を使うよう変更。

影響範囲
- 録画中ズームの発火条件とズーム中心座標の決定ロジックに影響。
- モザイクウィンドウ表示側には影響なし。

検証結果
- xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO

リスク
- AX許可がない環境では有効クリック判定がfalseになり、ズームが発火しない。

ロールバック
- PointerTrackingService.swift / RecordingService.swift の本差分を戻せば従来のクリック中ズームに復帰。