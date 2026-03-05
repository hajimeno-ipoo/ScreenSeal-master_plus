変更点（仕様変更）
- クリック時と追跡時の座標取得を同じ基準に統一。

変更点（内部実装）
- PointerTrackingService.screenLocation(from:) で cgEvent.location 経路を削除。
- NSEvent.mouseLocation のみ返すよう変更。

影響範囲
- クリック座標取得ロジックのみ。
- 録画保存・描画効果パラメータには影響なし。

検証結果
- xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO

リスク
- 特定イベントで mouseLocation 取得タイミング差が残る可能性。

ロールバック
- screenLocation(from:) に cgEvent.location 優先ロジックを戻す。