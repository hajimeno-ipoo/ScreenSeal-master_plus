状態: 完了

仕様変更:
- 単一ウィンドウ録画で、SCStreamFrameInfo.contentRect をそのまま使わず scaleFactor を掛けたピクセル座標で切り抜くよう修正。
- これにより Retina 環境で録画内容が半分サイズになり黒背景が残る症状を抑制。

内部実装:
- RecordingService.normalizedSourceImage が contentRect と scaleFactor から pixelContentRect を作成して crop する形へ変更。
- 先に入れていた contentScale 拡大は撤回し、切り抜き矩形の解釈だけを最小修正。

影響範囲:
- 単一ウィンドウ録画のフレーム正規化処理にのみ影響。

検証結果:
- ffprobe /Users/apple/Movies/ScreenSeal/ScreenSeal-20260306-204947.mp4
- ffmpeg -i /Users/apple/Movies/ScreenSeal/ScreenSeal-20260306-204947.mp4 -vf cropdetect=24:16:0 -frames:v 80 -f null -
- xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
- git diff --check -- ScreenSeal/Services/RecordingService.swift

リスク:
- 非Retina や録画中のウィンドウサイズ変更ケースは実機で追加確認したい。

ロールバック方法:
- RecordingService.normalizedSourceImage を pixelContentRect 導入前の実装へ戻す。