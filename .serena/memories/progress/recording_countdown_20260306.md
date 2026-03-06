状態: 完了

仕様変更:
- 録画開始前に3秒カウントダウンを追加。
- カウント中は Cancel Countdown を表示し、録画設定変更を無効化。

内部実装:
- WindowManager に countdown 状態管理、キャンセル、中央表示オーバーレイを追加。
- RecordingState に countdown(secondsRemaining:) を追加し、状態表示文言を拡張。

影響範囲:
- 録画開始フロー、メニューバーUI、アプリ終了時の後始末。

検証結果:
- xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Release -derivedDataPath /tmp/ScreenSeal-countdown-build build
- git diff --check -- ScreenSeal/Models/RecordingState.swift ScreenSeal/Windows/WindowManager.swift ScreenSeal/Views/MenuBarView.swift ScreenSeal/App/AppDelegate.swift README.md FOR[hazimeno_ipoo].md

リスク:
- 画面中央オーバーレイの見え方は実機のSpaces/フルスクリーン状態で最終確認が必要。

ロールバック方法:
- countdown 状態と WindowManager のカウントダウン管理、メニューの Cancel Countdown 分岐を戻す。