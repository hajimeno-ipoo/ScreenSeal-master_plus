状態: 完了

変更点（仕様変更）
- Follow Cursor が ON の間は、録画対象を Full Display のみに制限。
- ON に切り替えた時点で window/region が選ばれていた場合は自動で display に戻す。

変更点（内部実装）
- WindowManager.followCursorRecording の didSet で非 display ターゲットを display へ戻す。
- beginSystemWindowSelection / beginRecordingRegionSelection に followCursorRecording ガードを追加。
- MenuBarView の Choose Window / Select Region を Follow Cursor ON 中は disabled に変更。
- FOR[hazimeno_ipoo].md に今回の仕様制限を追記。

影響範囲
- 録画メニューの選択肢と録画ターゲット状態のみ。録画処理本体や保存形式には非影響。

検証結果
- xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
- git diff --check -- ScreenSeal/Windows/WindowManager.swift ScreenSeal/Views/MenuBarView.swift FOR[hazimeno_ipoo].md

リスク
- Follow Cursor を ON にした瞬間に選択中ターゲットが display に戻る挙動を実機で見え方確認したい。

ロールバック方法
- followCursorRecording の didSet と各ガード、MenuBarView の disabled 条件を元に戻す。