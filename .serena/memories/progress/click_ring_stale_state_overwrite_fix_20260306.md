変更点（仕様変更）
- クリックリング座標の元データを、タイマー更新で上書きしないように変更。
- クリック時のズーム状態を即時反映するように変更。

変更点（内部実装）
- PointerTrackingService.start() の stateQueue 更新を async→sync に変更。
- タイマー更新から lastClickEventIDState/lastClickLocationState の書き込みを削除。
- handleMouseDown() の stateQueue 同期更新に zoomAnchorLocationState/isZoomActiveState を追加。

影響範囲
- PointerTrackingService のスナップショット整合性のみ。
- RecordingService 側のリング描画ロジック・録画保存処理には直接変更なし。

検証結果
- xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO

リスク
- stateQueue.sync 化でごく短い同期待ちが増える。

ロールバック
- PointerTrackingService.swift の該当差分（async化復帰・クリック状態更新復帰）を戻す。