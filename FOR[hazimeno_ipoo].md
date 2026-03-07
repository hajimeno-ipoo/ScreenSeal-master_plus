# FOR[hazimeno_ipoo]

## このプロジェクトは何？
ScreenSeal_plus は、macOS のメニューバーに常駐して、画面の一部をモザイクで隠すアプリです。
録画中や画面共有中に、パスワードや個人情報を見せないために使います。

## 技術アーキテクチャ（全体の仕組み）
1. `ScreenCaptureService` がディスプレイ映像をリアルタイム取得します。
2. `WindowManager` がモザイク用ウィンドウを管理します。
3. `FilterProcessor` が Core Image でぼかし/モザイク処理をします。
4. `OverlayContentView` が加工済み画像を表示します。
5. `ScreenshotService` が静止画を1枚だけ撮り、PNGで保存します。
6. `RecordingService`（macOS 15+）が録画を MP4 に保存します。
7. `WindowManager` が保存後サムネイルの表示と、クリック時のアプリ起動も管理します。
8. `PointerTrackingService` がカーソル位置とクリック状態を追跡し、クリック時ズームに使います。
9. メニューの `Capture Mode` で、録画かスクリーンショットかを切り替えます。
10. 録画メニューから、カーソルのハイライト色とクリックリング色も変えられます。
11. 録画開始前には、対象画面の中央に3秒カウントダウンが出ます。
12. 撮影対象は、全画面・選択ウィンドウ・選択範囲から選べます。
13. 保存後は画面にサムネイルが出て、スクショは Preview/Finder、録画は QuickTime/Finder で開けます。

## コード構造
- `ScreenSeal/App`: 起動、ライフサイクル
- `ScreenSeal/Models`: 設定や状態モデル（モザイク設定、録画状態、ズーム設定）
- `ScreenSeal/Services`: 画面取得、権限、スクリーンショット、録画、ポインタ追跡
- `ScreenSeal/Processing`: 画像フィルター処理
- `ScreenSeal/Windows`: オーバーレイウィンドウとマネージャ
- `ScreenSeal/Views`: メニューバーUI、右クリックメニュー
- 録画メニューでは、カーソル演出の色と透明度も変えられる
- スクリーンショットは `~/Pictures/ScreenSeal_plus/` に PNG で保存する
- 録画は `~/Movies/ScreenSeal_plus/` に MP4 で保存する
- 保存後サムネイルは `WindowManager` の専用オーバーレイで表示する
- 録画サムネイルは `AVAssetImageGenerator` で MP4 から静止画を作る
- 録画開始前は、専用オーバーレイでカウントダウンを出してから録画を始める
- 録画対象がウィンドウや範囲のときは、専用の選択状態を持って録画に渡す

## なぜこの技術を選んだ？
- ScreenCaptureKit: macOS 標準で高性能な画面キャプチャができる
- Core Image: リアルタイムで画像効果をかけやすい
- SwiftUI + AppKit: メニューバーUIと細かなmacOS操作を両立しやすい

## よくあるバグと修正方法
- 症状: 画面が真っ黒/更新されない
  - 原因: Screen Recording 権限不足
  - 修正: システム設定で画面収録権限を許可

- 症状: 録画開始できない
  - 原因: macOS 15 未満、または権限不足
  - 修正: macOS 15+ を使用し、権限を再許可

- 症状: スクリーンショットが保存されない
  - 原因: Screen Recording 権限不足、または保存先の作成失敗
  - 修正: 権限を許可し、`~/Pictures/ScreenSeal_plus/` が作れるか確認する

- 症状: 保存後サムネイルが真っ黒になる
  - 原因: 画像の受け渡し方法が不適切で、プレビュー表示側が正しく描画できていない
  - 修正: `CGImage` をそのまま `CALayer.contents` に渡し、`contentsScale` を設定する

- 症状: 録画後サムネイルが出ない
  - 原因: 録画停止後の保存URLからサムネイル生成ができていない
  - 修正: `AVAssetImageGenerator` で MP4 の中ほどのフレームを生成してから表示する

- 症状: ズームが急に動いて見づらい
  - 原因: 補間時間が短すぎる
  - 修正: `ZoomProfile.easingDuration` を少し長くする

- 症状: `Follow Cursor` をONにすると、範囲選択録画で黒い余白が出る
  - 原因: 切り抜き枠が元画像より大きくなっていた
  - 修正: `RecordingService.applyFollowCursorCamera` で切り抜きサイズを `image.extent` 以内に制限する

- 症状: `Follow Cursor` をONにすると、ウィンドウ選択や範囲選択を使いたくなる
  - 原因: その組み合わせは追従が分かりにくく、仕様と相性が悪い
  - 修正: `Follow Cursor` がONの間は録画対象を全画面だけに制限する

- 症状: モザイク窓の位置がプレビューや録画でズレる
  - 原因: 画面座標とキャプチャ画像座標で、Y座標の向きがそろっていない
  - 修正: `WindowManager.distributeFrame` と録画側の切り抜きで、`screenFrame.maxY - rect.maxY` の形に統一する

- 症状: ウィンドウ選択録画でモザイク窓が映らない
  - 原因: 単一ウィンドウ専用の録画フィルタは、別ウィンドウのモザイク窓を含めない
  - 修正: 対象ディスプレイ上で「選んだウィンドウ + モザイク窓」を含むフィルタに切り替える

- 症状: 録画停止後もメニューバーの緑インジケーターが消えない
  - 原因: モザイク窓のライブ更新用キャプチャが動いたまま
  - 修正: 録画停止が終わったらモザイク窓を閉じて、常時キャプチャも止める

## 落とし穴と回避方法
- 落とし穴: ディスプレイ座標系とキャプチャ座標系のズレ
  - 回避: `screen.frame` と `CIImage.extent` から毎フレーム換算する

- 落とし穴: 単一ウィンドウ録画は、上に重ねた別ウィンドウを自動では含めない
  - 回避: モザイク窓も映したい時は、ディスプレイ録画 + 必要なウィンドウだけ含める形にする

- 落とし穴: 多画面時に別画面カーソルでズーム誤動作
  - 回避: カーソルが対象ディスプレイ内のときだけズームON

- 落とし穴: 録画APIはOSバージョン差がある
  - 回避: `@available(macOS 15.0, *)` とガードで分岐

- 落とし穴: スクリーンショットと録画で対象選択の条件が少し違う
  - 回避: `Capture Mode` ごとの無効条件を `WindowManager` にまとめる

- 落とし穴: 録画ファイルは画像アプリではなく動画アプリで開くべき
  - 回避: スクショは Preview、録画は QuickTime を別設定にする

## ベストプラクティス
- 変更は `WindowManager` を中心に集約し、責務を混ぜない
- 画像処理は `FilterProcessor` にまとめ、UIから分離する
- 録画失敗とキャプチャ失敗は状態を分けて表示する
- 録画用の見た目設定は `UserDefaults` に保存し、次回起動でも同じ状態にする
- パフォーマンス問題は「解像度、FPS、queueDepth」から先に見る

## 実行・ビルド
- ビルド:
  - `xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Release build`
