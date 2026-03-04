変更点（仕様変更）
- 録画ボタン表示を state.isRecording 依存から service存在依存へ変更し、停止導線を確保。

変更点（内部実装）
- RecordingService.stop を堅牢化。removeRecordingOutput が失敗しても stopCapture を継続実行。
- WindowManager で開始/停止失敗時に recordingServiceRef を解放し、操作詰まりを防止。

影響範囲
- メニュー録画操作（Start/Stop切替）
- 録画停止時の異常復帰

検証結果
- 静的確認のみ（実機ビルド/実行はユーザー環境依存）。

リスク
- SCRecordingOutput のOS挙動差により停止完了通知タイミングがぶれる可能性。

ロールバック
- RecordingService/WindowManager/MenuBarView の今回差分を戻せば元に復帰。