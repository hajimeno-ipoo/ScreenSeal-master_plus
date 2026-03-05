変更点（仕様変更）
- クリックリングの固定位置を「クリック時の出力座標」に変更。
- 表示中にパン/ズームが動いても、リングは画面上の同じ位置に残る。

変更点（内部実装）
- RecordingService の lastClickScreenLocation を lastClickOutputPoint に置換。
- applyCursorEffects で新規クリック検知時に clickPoint/cursorPoint を保存し、再投影計算を廃止。
- sourceRect/imageExtent 依存を applyCursorEffects から外し、座標再計算経路を削除。

影響範囲
- 録画中のクリックリング位置決定ロジックのみ。
- 録画開始/停止、音声、モザイク、ズーム条件判定には影響なし。

検証結果
- xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO

リスク
- クリック検知フレームで clickPoint と cursorPoint が両方 nil の場合、リングがそのクリックで出ない可能性。

ロールバック
- RecordingService の lastClickOutputPoint 関連差分を戻し、lastClickScreenLocation 再投影方式に戻す。