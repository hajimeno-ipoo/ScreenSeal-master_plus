状態: 完了

仕様変更:
- 録画対象に Full Display / Window / Region を追加。
- 録画前カウントダウンと既存カーソル演出を各モードで継続。

内部実装:
- WindowManager に RecordingTarget 系モデル、ウィンドウ候補取得、範囲選択オーバーレイを追加。
- RecordingService を start(target:) に変更し、display/window/region ごとに SCContentFilter と sourceRect を切り替えるよう更新。

影響範囲:
- 録画開始フロー、メニューバーの録画UI、選択範囲入力、録画座標変換。

検証結果:
- xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Release -derivedDataPath /tmp/ScreenSeal-target-modes-build build
- git diff --check -- ScreenSeal/Windows/WindowManager.swift ScreenSeal/Services/RecordingService.swift ScreenSeal/Views/MenuBarView.swift ScreenSeal/App/AppDelegate.swift README.md FOR[hazimeno_ipoo].md

リスク:
- 実機ではウィンドウ移動直後のカウントダウン位置と複数画面の範囲選択見え方を確認したい。

ロールバック方法:
- RecordingTarget 系追加、MenuBarView の Recording Target メニュー、RecordingService.start(target:) 変更を元へ戻す。