# tile-convert

## 目的

`docs/misc/minimap` の6枚画像を 2列 x 3行 で合成し、Leaflet で使えるローカルタイル (`z/x/y`) を生成する。

## 前提

- 入力画像: `../minimap/minimap_sea_*.png`
- ファイル名の `minimap_sea_row_col.png` をそのまま行列インデックスとして使う
- 期待レイアウト: `rows=3`, `cols=2`
- 出力先: `./output`

## 実行

```powershell
./build-minimap-tiles.ps1
```

## 出力

- 合成画像: `output/combined/minimap_combined.png`
- タイル: `output/tiles/render/{z}/{x}/{y}.png`
- メタデータ: `output/metadata.json`

## 注意

- world bounds は Los Santos 固定URL と同じ値を仮定している
- 本番利用前に固定点3点で向きと範囲を検証すること

## 検証状況

- 2026-03-27 時点で `output/index.html` による確認を実施
- 地図表示のズレなし
- クリックで取得した `lat/lng` とゲーム内座標の一致を確認
- 現状の 3行 x 2列 合成と Los Santos world bounds 仮定は妥当
