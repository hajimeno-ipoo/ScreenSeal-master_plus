<img src="ScreenSeal/Resources/Assets.xcassets/icon.appiconset/icon_256x256.png" width="128" alt="ScreenSeal Icon">

# ScreenSeal_plus

画面上の機密情報をモザイクで隠すための macOS メニューバーアプリ。

画面収録やスクリーンショット撮影時に、ScreenSeal のモザイクウィンドウを配置することで、パスワードや個人情報などを安全に隠せます。モザイクウィンドウ自体はスクリーンショットや画面共有に映らず、モザイク効果のみが反映されます。

## Features

- **リアルタイムモザイク** - 背面の画面内容をリアルタイムにキャプチャしてモザイク処理
- **3種類のフィルター** - ピクセル化 / ガウスぼかし / クリスタライズ
- **強度調整** - 右クリックメニューのスライダーまたはスクロールホイールで調整
- **複数ウィンドウ** - 同時に複数のモザイク領域を配置可能
- **メニューバー管理** - ウィンドウの一覧表示、表示/非表示の切り替え
- **マルチディスプレイ対応** - 複数モニタ環境でも動作
- **レイアウトプリセット** - ウィンドウ配置を保存して一発で呼び出し（複数登録可能）
- **設定の永続化** - モザイクタイプと強度はアプリ終了後も保持
- **静止画スクリーンショット** - メニューバーからモザイク入りPNGを1枚保存
- **画面録画** - メニューバーから単一ディスプレイを MP4 録画
- **保存後サムネイル確認** - スクショや録画の保存後に、画面上へサムネイルを一時表示
- **開き先の選択** - スクショは Finder / Preview、録画は Finder / QuickTime を選択可能
- **クリックズーム** - 左クリック中はカーソル中心へ滑らかに拡大（1.8x）

## Requirements

- macOS 14.0 以降
- Screen Recording 権限（初回起動時にシステムダイアログが表示されます）
- 録画機能は macOS 15.0 以降で利用可能

## Installation

[Releases](https://github.com/nyanko3141592/ScreenSeal/releases) ページから最新の `ScreenSeal.zip` をダウンロードして解凍し、`ScreenSeal.app` を Applications フォルダに移動してください。

## Usage

1. アプリを起動するとメニューバーにアイコンが表示されます
2. メニューから **New Mosaic Window** をクリックしてモザイクウィンドウを作成
3. ウィンドウをドラッグして隠したい箇所に配置、端をドラッグしてリサイズ
4. **右クリック**でコンテキストメニューを開き、フィルタータイプや強度を変更
5. **スクロールホイール**でも強度を素早く調整可能
6. メニューバーからウィンドウの表示/非表示を切り替え
7. **Capture Mode** で **Record** または **Screenshot** を選びます
8. **Capture Target** で **Full Display** / **Window** / **Select Region...** を選びます
9. **Record** モードでは **Start Recording** で `~/Movies/ScreenSeal/` に MP4 保存
10. **Screenshot** モードでは右隣のボタン、または **Take Screenshot** で `~/Pictures/ScreenSeal/` に PNG 保存
11. **Screenshot Click Action** でスクショの開き先を **Finder** / **Preview** から選びます
12. **Recording Click Action** で録画の開き先を **Finder** / **QuickTime** から選びます
13. 保存後は画面上にサムネイルが出て、クリックすると選んだアプリで開きます
14. 録画中に左クリックを押すとクリックズームが有効化

## Build

```bash
xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Release build
```

## Tech Stack

- Swift / SwiftUI / AppKit
- ScreenCaptureKit (画面キャプチャ)
- Core Image (モザイクフィルター処理)
- Metal (GPU アクセラレーション)

## License

MIT
