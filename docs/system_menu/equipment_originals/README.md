# 裝備頁素材原圖（共邊國原檔，未後製）
`assets/UI/equipment_aged/` 是用 `tools/age_paper.gd` 對大卷軸、裝備格、角色卡槽做過「宣紙泛黃＋污漬＋邊緣燒焦＋纖維」後製的備案版（缺點：紋理會被模糊）；`assets/UI/equipment/` 與這個資料夾是共邊國原檔，預設使用原檔。要切到備案版，把 `StudyPageBase.use_aged_equipment_paper` 設成 true。重跑後製（輸出改寫到 `assets/UI/equipment_aged/`）：

```
AGE_IN=docs/system_menu/equipment_originals/equip_scroll_complete.png AGE_OUT=assets/UI/equipment_aged/equip_scroll_complete.png AGE_MODE=scroll AGE_STAIN=0.75 AGE_YELLOW=0.95 AGE_BURN=0.85 godot --headless --path . --script tools/age_paper.gd
AGE_IN=<原檔> AGE_OUT=assets/UI/equipment_aged/<檔名> AGE_MODE=tile AGE_STAIN=0.6 AGE_YELLOW=0.95 AGE_BURN=0.45 godot --headless --path . --script tools/age_paper.gd
```
強度 0–1.5：AGE_YELLOW 泛黃、AGE_STAIN 污漬與淡墨暈、AGE_BURN 邊緣燒焦、AGE_GRAIN 纖維顆粒。跑完要 `godot --headless --path . --import`。
