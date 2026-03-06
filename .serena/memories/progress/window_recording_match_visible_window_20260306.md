状態: 完了

仕様変更:
- 単一ウィンドウ録画で ignoreShadowsSingleWindow / ignoreGlobalClipSingleWindow を使わず、見えているウィンドウに近い見た目へ戻した。
- 録画前カウントダウンの表示位置をディスプレイ中央ではなく選択ウィンドウ中央へ修正。

内部実装:
- RecordingService.start の window ケースから ignoreShadowsSingleWindow / ignoreGlobalClipSingleWindow を削除。
- ResolvedRecordingTarget.countdownCenterPoint の window ケースを displayFrame.mid から windowFrame.mid へ変更。

影響範囲:
- 単一ウィンドウ録画の見た目、録画前カウントダウン位置。

検証結果:
- xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
- git diff --check -- ScreenSeal/Services/RecordingService.swift ScreenSeal/Windows/WindowManager.swift

リスク:
- なお差が残る場合は ScreenCaptureKit の screenRect を実測基準に使う追加調整が必要。

ロールバック方法:
- RecordingService.start の ignoreShadowsSingleWindow / ignoreGlobalClipSingleWindow を復帰し、ResolvedRecordingTarget.countdownCenterPoint を displayFrame.mid へ戻す。