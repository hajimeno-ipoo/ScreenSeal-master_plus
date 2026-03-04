変更点（仕様変更）
- 画面収録エラー時に設定画面を開く導線を追加。
- メニューに実行中バージョン表示を追加。

変更点（内部実装）
- OverlayContentView で mouseDownCanMoveWindow = true を追加しドラッグ安定化。
- WindowManager で TCC拒否系エラーを短い日本語メッセージへ正規化。

影響範囲
- UI: MenuBarView のエラーブロック表示。
- 入力: モザイクウィンドウのマウスドラッグ挙動。

検証結果
- 静的確認のみ（Xcodeライセンス未同意でビルド不可）。

リスク
- 設定画面URLはOSバージョンで遷移先が変わる可能性。

ロールバック
- 3ファイル（MenuBarView/WindowManager/OverlayContentView）の追加入力を戻せば復旧可能。