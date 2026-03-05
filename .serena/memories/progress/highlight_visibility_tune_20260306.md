変更点（仕様変更）
- 水色ハイライトの視認性を上げた。
- クリックリング表示中でもハイライトを薄くしないようにした。

変更点（内部実装）
- RecordingService.highlightColor の alpha を 0.18→0.35 に変更。
- applyCursorEffects の highlightAlphaMultiplier を常時 1.0 に変更。

影響範囲
- 録画中のカーソル周辺ハイライト見た目のみ。
- クリックリング位置計算や録画保存処理には影響なし。

検証結果
- xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO

リスク
- 背景が明るい場面でやや強調しすぎる可能性。

ロールバック
- alpha を 0.18 に戻し、highlightAlphaMultiplier を isRingActive 分岐へ戻す。