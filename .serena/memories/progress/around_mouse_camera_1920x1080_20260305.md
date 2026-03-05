変更点（仕様変更）
- 録画出力を常時 1920x1080 の追従カメラ方式に変更。
- 未クリック時もカーソル中心でパン（等倍）。
- クリック時のみ既存ルールでズーム（1.8x/保持0.9秒）を維持。

変更点（内部実装）
- RecordingService に outputResolution(1920x1080) を追加し writer 出力解像度を固定化。
- applyRecordingZoom を outputSize受け取りに変更し、常時ROI切り出し+補間追従へ変更。
- 画面座標→画像座標変換とベースカメラサイズ算出ヘルパーを追加。

影響範囲
- 録画映像のフレーミング処理のみ。モザイク窓表示、録画開始停止状態管理には非影響。

検証結果
- xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO

リスク
- 低解像度ディスプレイでベース切り出し領域が狭くなり、体感が変わる可能性。

ロールバック方法
- RecordingService の writer サイズを displayサイズに戻し、applyRecordingZoom を全画面ベースへ戻す。