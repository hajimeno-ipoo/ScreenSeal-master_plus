変更点（仕様変更）
- メニューバーに録画開始/停止を追加。
- 単一ディスプレイ録画（mp4）とクリック時ズーム（1.8x）を追加。
- 録画状態をUI表示（開始中/録画中/停止中/失敗）。

変更点（内部実装）
- RecordingService, PointerTrackingService, RecordingState, ZoomProfile を追加。
- WindowManager に録画制御とズームROI計算を統合。
- プロジェクト設定（pbxproj）へ新規ファイル登録。

影響範囲
- 呼び出し元: MenuBarView -> WindowManager。
- I/O: ~/Movies/ScreenSeal/*.mp4 を出力。
- 例外: 録画失敗時は recordingState.failed に集約。

検証結果
- 実行コマンド: xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Release build
- 結果: Xcode license 未同意でビルド未実施（code 69）。

リスク
- macOS/Xcode環境差でSCRecordingOutput API差異の可能性。

ロールバック
- 追加ファイルと WindowManager/MenuBarView の差分を戻せば元動作に復帰可能。