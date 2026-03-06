状態: 完了

変更点（仕様変更）
- ウィンドウ選択録画でも Follow Cursor を ON にした時は、待機中からカーソル追従するようにした。
- Follow Cursor OFF の時は、従来どおり待機中は固定表示のまま。

変更点（内部実装）
- RecordingService.applyRecordingTransform の window 向け早期 return 条件に !followCursorCameraEnabled を追加。
- ON 時は applyFollowCursorCamera に流し、OFF 時だけ元画像を返すようにした。

影響範囲
- ウィンドウ選択録画の Follow Cursor 挙動のみ。保存形式や設定保存には非影響。

検証結果
- xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
- git diff --check -- ScreenSeal/Services/RecordingService.swift

リスク
- 実機でウィンドウ録画の待機時追従とクリック中ズームの見え方を確認したい。

ロールバック方法
- RecordingService.applyRecordingTransform の !followCursorCameraEnabled 条件を削除して元に戻す。