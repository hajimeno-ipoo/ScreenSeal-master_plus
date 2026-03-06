状態: 完了

仕様変更:
- Capture Mode を追加し、Record / Screenshot を切り替えられるようにした。
- Screenshot モードでは Full Display / Window / Select Region を使って PNG を `~/Pictures/ScreenSeal/` に保存する。
- Screenshot モードでは Follow Cursor / Cursor Highlight / Click Ring / 色設定を無効化した。

内部実装:
- WindowManager に captureMode、スクリーンショット状態、共通の primary action を追加した。
- ScreenCaptureService.swift に ScreenshotService を追加し、SCScreenshotManager で display/window/region の1枚撮影を実装した。
- AppDelegate と MenuBarView を更新し、右隣ボタンの icon/tooltip とメニューの表示分岐を mode 連動にした。

影響範囲:
- メニューバーUI、常駐ボタン、対象選択の無効条件、ScreenCaptureKit を使う静止画保存。

検証結果:
- xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Release -derivedDataPath /tmp/ScreenSeal-screenshot-build build
- git diff --check -- ScreenSeal/App/AppDelegate.swift ScreenSeal/Views/MenuBarView.swift ScreenSeal/Windows/WindowManager.swift ScreenSeal/Services/ScreenCaptureService.swift README.md README.ja.md FOR[hazimeno_ipoo].md

リスク:
- 実機では権限未許可時の文言と、Window の静止画にモザイク窓が期待通り重なるかを最終確認したい。
- Region スクショ成功後は Full Display に戻して選択枠を解除するよう更新済み。

ロールバック方法:
- captureMode と ScreenshotService 追加分、AppDelegate/MenuBarView の分岐、README/FOR 更新を戻す。