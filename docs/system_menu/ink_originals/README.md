# 筆畫圖章原圖（未做紋理處理）
墨色標籤（`label_ink_s/m`）、稀有度章（`rarity_1~4`）、紅印章（`seal_type`）、使用狀態章（`status_*`）、類別章（`badge_*`）在 `assets/UI/inventory/` 的版本，已經用 `tools/ink_texture.gd` 加上毛筆質感（邊緣飛白、墨色濃淡、紙纖維透出）。這裡是處理前的原圖，可以從這裡重跑：

```
INK_K=1.7 godot --headless --path . --script tools/ink_texture.gd
godot --headless --path . --import
```
INK_K 是強度（0.5 淡 ～ 2.3 重，目前 1.7）。注意：`tools/paint_badges_and_shadow.gd` 會重畫 badge／status 章，重跑它會蓋掉紋理，之後要再跑一次 ink_texture。
