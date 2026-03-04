変更点（仕様変更）
- リンククリック時にズームが発火しない問題を修正。
- MenuBarExtraラベルをテキスト無しアイコン表示に変更し、録画中の押し出し軽減を実施。

変更点（内部実装）
- PointerTrackingServiceでAX要素の親チェーンを最大8段たどり、role/subrole/actionで対話要素判定。
- 押下エッジ依存を緩和し、押下中に未確定なら都度トリガー判定するよう調整。
- ScreenSealAppでMenuBarExtraをimage-only label + .menu styleへ変更。

影響範囲
- 録画中ズーム発火条件（リンク/ボタン検出）とメニューバー表示挙動に影響。

検証結果
- xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO

リスク
- 一部アプリの独自UIはAXロールが特殊で未検出の可能性あり。

ロールバック
- PointerTrackingService.swift と ScreenSealApp.swift の差分を戻す。