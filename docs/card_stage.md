# Card Stage（`BattlePresentationMode.CARD_STAGE = 2`）

基於 `combat-baseline-pre-card-stage` 的新增演出層。`LEGACY`、`STAGE_25D` 行為不變；戰鬥規則、Controller、Popup ItemList、`battle_uid`、F8 回退皆沿用。
角色卡就是戰場單位：直立、站在舞台上，不是 HUD、不是 billboard。

## 啟用
- `BattleScene.presentation_mode = CARD_STAGE`，或 battle context 的 `presentation_mode = 2`，或命令列 `-- --card-stage`。
- 獨立預覽：`res://scenes/presentation/card_stage_prototype.tscn`（不發獎勵、不寫存檔）。
- **正式遊戲預設為 `CARD_STAGE`**（正常劇情進戰鬥不需任何參數）。回退：`-- --stage-25d`、battle context `presentation_mode = 1`、`-- --legacy-battle`、戰鬥中 F8。
- 戰鬥開始會在 console 印 `Battle Presentation: <模式>`；Debug build 左上角短暫顯示同樣文字（F8 切換時會更新為 `LEGACY (F8)`）。

## 檔案
| 檔案 | 責任 |
| --- | --- |
| `CardStageFormation.gd` | 單排站位（純資料／靜態函式） |
| `CardStage3D.gd` (+ `card_stage_3d.tscn`) | 繼承 `CombatStage25D`；放置直式卡、敵方排更深；依各卡尺寸 pick |
| `CardStageActorCard.gd` | 繼承 `StageActorCard`；直式卡面（資訊沿用現有欄位）＋空間化動作 |
| `CardStageBattleUI.gd` | 繼承 `StageBattleUI`，僅覆寫 `_create_stage()` |
| `CardStagePrototype.gd` | 預覽 fixture |

對既有檔案的改動只有掛鉤：`StageBattleUI._create_stage()`、`BattleScene` 的第三個 enum 與分支、`CombatStagePrototype.ui_script_path`。

## 站位（沒有前鋒／中軍／後援職位）
- 每個陣營**一排**卡片，沿 X 排列，同一高度、同一 Z band（只有 `Z_STACK` 0.25 的遮疊排序差）。
- 位置以「螢幕比例」定義，再用真實透視相機換成世界座標（`Formation.world_position`）；大小只來自距離與 FOV，不使用 scale：
  - 我方：卡片名目高 `ALLY_HEIGHT 0.55`，轉 40° 後近側被放大，實際約占螢幕高 **3/5**；基準 Z ≈ +7.7（前景、左）。
  - 敵方：`ENEMY_HEIGHT 0.37`，近乎正面，約占螢幕高 **2/5**；基準 Z ≈ +2.8（後景、右）。
  - 兩排站在同一地平面（`ALLY_FEET 0.79`），所以較遠的敵方腳底在畫面上較高。背景 Z = -11。
- 中央保留至少 15% 螢幕寬的空地給劍痕、MISS 穿越與前衝。
- 速度只決定**初始**由內往外的順序：最快的最靠交鋒區（我方並略向鏡頭突出）。只在 `set_teams()` 決定，戰鬥中 Buff/Debuff 不重排。客座永遠排最外側。actor 可選 `formation = "inner" | "outer"` 覆寫。
- 疊壓：我方右緣、敵方左緣會被鄰卡蓋住，所以敵方卡的名字／氣血／屬性靠右對齊，我方靠左對齊。
- 參數（`CardStageFormation.gd`，均為畫面比例）：`ALLY_LANE 0.285`、`ENEMY_LANE 0.82`、`ALLY_SPACING 0.145`、`ENEMY_SPACING 0.085`、`ALLY_FEET 0.79`。
- Yaw：**我方 35° / 40°（預設）/ 45°** 朝向敵方；**敵方固定 12°**，盡量維持正面（`ENEMY_YAW_DEGREES`，或 `-- --enemy-yaw=N`）。Debug build 戰鬥中按 F9 循環我方 yaw；啟動參數 `-- --card-yaw=45`。

## 直式卡（2:3）
- 世界尺寸 `PORTRAIT_SIZE = 2.3 × 3.45`；畫布 400×600（SubViewport 2 倍解析度）；卡片厚度 `CARD_THICKNESS 0.04`（原 0.06 的 2/3）。
- 上方立繪區，下方資訊帶：名字、LV＋狀態字、氣血＋條、內力＋條（我方）／種族（敵方）、屬性與運行心法（我方）／屬性（敵方）。資訊欄位與 STAGE_25D 卡相同，僅重新排版。

## 動作（皆回到 home_position / home_rotation）
- 出招：後縮 → 朝目標前衝 46%，Z 固定外擺朝向觀眾、卡面轉向鏡頭。
- 受擊：往外退並深入 Z（重擊更深），後仰。
- 閃避：側移、上移並深入 Z。
- 格擋：原地往深處頂住。

## 測試
`--headless --path . --script tests/test_card_stage_phase1.gd`
