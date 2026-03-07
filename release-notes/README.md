# release-notes

GitHub Releases に貼る説明文を、版ごとに保存するフォルダです。

## おすすめの名前

- `v0.1.0.md`
- `v0.1.1.md`
- `v0.2.0.md`

## 使い方

1. `TEMPLATE.md` をコピーする
2. 今回の版名で保存する
3. `gh release create` の `--notes-file` で指定する

## 例

```bash
gh release create v0.1.0 ./ScreenSeal_plus-macOS.zip \
  --title "ScreenSeal_plus v0.1.0" \
  --notes-file release-notes/v0.1.0.md
```
