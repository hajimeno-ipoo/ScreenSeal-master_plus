変更点（仕様変更）
- メニューバー上のクリックをズーム対象外にした。
- メニュー関連AXロール（AXMenuBar/AXMenuBarItem/AXMenu/AXMenuItem）を対象外にした。
- AXサブロール AXMenuExtra / AXSystemDialog も対象外にした。

変更点（内部実装）
- PointerTrackingService.shouldTriggerZoom(at:) で isMenuBarInteraction(...) を先行判定。
- 画面上部のメニューバー帯を NSStatusBar.system.thickness で判定。
- 祖先要素を辿ってメニュー系ロールを検出する関数を追加。

影響範囲
- クリックズームの発火条件のみ。録画/停止処理、モザイク処理、保存処理には影響なし。

検証結果
- xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO

リスク
- メニューバー帯付近の一部UIクリックが非対象になる可能性。

ロールバック方法
- PointerTrackingService.swift の isMenuBarInteraction(...) 呼び出しと関連関数を削除して戻す。