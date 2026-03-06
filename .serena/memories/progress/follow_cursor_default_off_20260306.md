状態: 完了

変更点（仕様変更）
- Follow Cursor の初期値を ON から OFF に変更。
- ON/OFF 切替時の既存挙動は維持。

変更点（内部実装）
- WindowManager.followCursorRecording の初期値を false に変更。

影響範囲
- アプリ起動直後の録画メニュー初期状態のみ。録画ロジック本体には非影響。

検証結果
- xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
- git diff --check -- ScreenSeal/Windows/WindowManager.swift

リスク
- 既存ユーザーの期待値がON前提なら、起動直後の見え方だけ変わる。

ロールバック方法
- WindowManager.followCursorRecording の初期値を true に戻す。