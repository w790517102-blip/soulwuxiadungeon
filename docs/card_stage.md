# Card Stage（`BattlePresentationMode.CARD_STAGE = 2`）

基於 `combat-baseline-pre-card-stage` 的新增演出層。`LEGACY`、`STAGE_25D` 行為不變；戰鬥規則、Controller、Popup ItemList、`battle_uid`、F8 回退皆沿用。

## 啟用
- `BattleScene.presentation_mode = CARD_STAGE`，或 battle context 的 `presentation_mode = 2`，或命令列 `-- --card-stage`。
- 獨立預覽：`res://scenes/presentation/card_stage_prototype.tscn`（不發獎勵、不寫存檔）。
- 預設仍為 `STAGE_25D`。

## 檔案
| 檔案 | 責任 |
| --- | --- |
| `CardStageFormation.gd` | 站位表與速度排位（純資料／靜態函式） |
| `CardStage3D.gd` (+ `card_stage_3d.tscn`) | 繼承 `CombatStage25D`，以站位放置卡片；不畫空槽 |
| `CardStageActorCard.gd` | 繼承 `StageActorCard`，空間化的前衝／受擊／閃避／格擋 |
| `CardStageBattleUI.gd` | 繼承 `StageBattleUI`，僅覆寫 `_create_stage()` |
| `CardStagePrototype.gd` | 預覽 fixture |

對既有檔案的改動只有掛鉤：`StageBattleUI._create_stage()`、`BattleScene` 的第三個 enum 與分支、`CombatStagePrototype.ui_script_path`。

## 站位參數（我方 x 取負，敵方取正；z = 該方基準深度 + dz）
基準深度：我方 +1.0、敵方 -1.0（沿用 `player_depth` / `enemy_depth`）。Yaw 維持 22°。

| 人數 | 角色 | 距中線 x | 高度 y | dz |
| --- | --- | --- | --- | --- |
| 1 | 先鋒 | 4.9 | 0.3 | +0.9 |
| 2 | 先鋒 / 後援 | 4.9 / 6.3 | -1.0 / 1.7 | +0.9 / -0.7 |
| 3 | 先鋒 / 中軍 / 後援 | 4.8 / 6.0 / 6.7 | -1.5 / 0.85 / 3.2 | +0.9 / -0.2 / -1.2 |

排位：依 `speed` 由快到慢取先鋒→後援；同速保持原順序；客座永遠最後；可用 actor 的 `formation = "vanguard" | "support"` 覆寫。只在 `set_teams()` 時決定，不寫回 actor。

## 動作（皆回到 home_position / home_rotation）
- 出招：後縮 0.45 → 朝目標前衝 46%，Z 固定外擺 +0.9 朝向觀眾、卡面開向鏡頭（yaw 減半）。
- 受擊：往外側退 0.55（重擊 1.0）並深入 Z -0.9（重擊 -1.6），後仰 -0.2。
- 閃避：側移 0.5、上移 0.35、深入 Z -1.25。
- 格擋：原地 Z -0.35 頂住。

## 測試
`--headless --path . --script tests/test_card_stage_phase1.gd`
