# release-notes

GitHub Releases に貼る説明文を、版ごとに保存するフォルダです。

## ファイル名のルール

- `v0.1.0.md`
- `v0.1.1.md`
- `v0.2.0.md`

## リリース手順

1. `TEMPLATE.md` をコピーする
2. 今回の版名で保存する
3. Release ビルドを作る
4. 配布用 zip を作る
5. タグを作って送る
6. `gh release create` の `--notes-file` で指定する

## コマンド例

```bash
mkdir -p /Users/apple/.gh-config

cd /Users/apple/Desktop/Dev_App/ScreenSeal-master_plus

xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Release -derivedDataPath build build
ditto -c -k --sequesterRsrc --keepParent build/Build/Products/Release/ScreenSeal_plus.app ScreenSeal_plus-macOS.zip

git tag v0.1.0
git push origin v0.1.0

GH_CONFIG_DIR=/Users/apple/.gh-config gh auth status || GH_CONFIG_DIR=/Users/apple/.gh-config gh auth login
GH_CONFIG_DIR=/Users/apple/.gh-config gh release create v0.1.0 ./ScreenSeal_plus-macOS.zip \
  --title "ScreenSeal_plus v0.1.0" \
  --notes-file release-notes/v0.1.0.md
```

## 各コマンドの説明

- `mkdir -p /Users/apple/.gh-config`
  - `gh` の設定を保存する専用フォルダを作ります
  - `-p` は、すでにあってもエラーにしにくくするための指定です

- `cd /Users/apple/Desktop/Dev_App/ScreenSeal-master_plus`
  - このプロジェクトのフォルダへ移動します
  - ここで実行しないと、ビルドや Release 作成の場所がずれることがあります

- `xcodebuild -project ScreenSeal.xcodeproj -scheme ScreenSeal -configuration Release -derivedDataPath build build`
  - Xcode をコマンドで動かして、Release 版のアプリを作ります
  - `Release` は配布向けのビルドです
  - `-derivedDataPath build` は、出力先を `build/` にそろえる指定です

- `ditto -c -k --sequesterRsrc --keepParent build/Build/Products/Release/ScreenSeal_plus.app ScreenSeal_plus-macOS.zip`
  - できあがった `ScreenSeal_plus.app` を zip にまとめます
  - GitHub Releases に添付する配布ファイルを作る役目です

- `git tag v0.1.0`
  - 今のコードの状態に `v0.1.0` という札を付けます
  - この札が、Release の版番号になります

- `git push origin v0.1.0`
  - 作ったタグを GitHub に送ります
  - GitHub Releases は、このタグをもとに公開します

- `GH_CONFIG_DIR=/Users/apple/.gh-config gh auth status || GH_CONFIG_DIR=/Users/apple/.gh-config gh auth login`
  - まず `gh` がログイン済みか確認します
  - 未ログインなら、そのままログイン画面へ進みます
  - `GH_CONFIG_DIR=...` は、`gh` の設定保存先をこのフォルダにする指定です

- `GH_CONFIG_DIR=/Users/apple/.gh-config gh release create v0.1.0 ./ScreenSeal_plus-macOS.zip --title "ScreenSeal_plus v0.1.0" --notes-file release-notes/v0.1.0.md`
  - GitHub Releases を実際に作るコマンドです
  - `v0.1.0` は公開する版番号です
  - `./ScreenSeal_plus-macOS.zip` は添付する配布ファイルです
  - `--title` は Release の見出しです
  - `--notes-file` は説明文のファイルを指定しています

## メモ

- `v0.1.0` は毎回その版に合わせて変える
- `release-notes/v0.1.0.md` も同じ版名にそろえる
- `gh` は `GH_CONFIG_DIR=/Users/apple/.gh-config` 付きで使う
