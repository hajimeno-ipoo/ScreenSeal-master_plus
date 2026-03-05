変更点（仕様変更）
- 録画ズーム中の中心点を固定アンカーからカーソル追従へ変更。
- 拡大/縮小補間を smoothstep に変更し、急な変化を軽減。

変更点（内部実装）
- ZoomProfile に cursorFollowDuration を追加（標準0.12s）。
- RecordingService に currentZoomCenter を追加し、毎フレームで補間追従。
- cleanup/start 時にズーム中心・倍率を初期化。

影響範囲
- 録画時ズームの見た目のみ。クリック判定やモザイク処理には非影響。

検証結果
- xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO

リスク
- 追従速度が速すぎ/遅すぎと感じる可能性。

ロールバック方法
- RecordingService.applyRecordingZoom の currentZoomCenter 補間を削除し、anchorLocation固定へ戻す。