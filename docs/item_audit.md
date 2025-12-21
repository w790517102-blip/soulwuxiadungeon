# 道具交握稽核

## InventorySync 可出現的道具
下表列出 `InventorySync.gd` 初始背包中宣告的道具與來源檔案。

| item_id | 名稱 | 說明/預期效果 | 來源檔案 |
| --- | --- | --- | --- |
| herb | 藥草 | 回復 50 點 HP，友方單體 | `scripts/battlescripts/InventorySync.gd` |
| elixir_qi | 回氣丹 | 回復 15 點 MP，友方單體 | `scripts/battlescripts/InventorySync.gd` |
| light_step_powder | 輕身散 | 速度 +5，友方單體 | `scripts/battlescripts/InventorySync.gd` |
| chicken_spike | 雞爪釘 | 速度 -5，敵方單體 | `scripts/battlescripts/InventorySync.gd` |
| haste_talisman | 神速符 | 我方：速度 +8；敵方：元素改為「快」，可指定任一單體 | `scripts/battlescripts/InventorySync.gd` |
| item_pili_single | 霹靂彈 | 固定 20 點傷害，敵方單體 | `scripts/battlescripts/InventorySync.gd` |
| item_pili_aoe | 轟雷霹靂彈 | 固定 15 點傷害，敵方全體 | `scripts/battlescripts/InventorySync.gd` |
| item_fire_talisman | 烈火符 | 預期 15 點火屬性效果，可指定任一單體 | `scripts/battlescripts/InventorySync.gd` |

> 目前專案內未找到 `items.json`、`ItemDB.gd` 或 `data/items` 等其他道具資料庫，所有可用道具都來自上述 Autoload 清單。

## BattleController 處理情況
- 道具效果在 `BattleController.use_item` 以 `effect` 字串分支處理。
- 已實作的 effect：
  - `heal`/`heal_hp`（回復 HP）
  - `mp_heal`（回復 MP）
  - `buff_speed`（加速）
  - `debuff_speed`（減速）
  - `haste_talisman`（神速符：我方加速／敵方改屬性）
  - `bomb_single`（霹靂彈固定傷害）
  - `bomb_aoe`（轟雷霹靂彈固定傷害）
- 其他 effect 會落入預設分支，產生「尚未實作」的戰報訊息，效果實際無作用。

## 總表
| 道具名 | item_id | 預期效果 | 已實作(Y/N) | 實作位置 | 缺漏說明 |
| --- | --- | --- | --- | --- | --- |
| 藥草 | herb | 回復 50 HP（heal） | Y | `BattleController.gd` `use_item` 的 `heal/heal_hp` 分支 | — |
| 回氣丹 | elixir_qi | 回復 15 MP（mp_heal） | Y | `BattleController.gd` `use_item` 的 `mp_heal` 分支 | — |
| 輕身散 | light_step_powder | 速度 +5（buff_speed） | Y | `BattleController.gd` `use_item` 的 `buff_speed` 分支 | — |
| 雞爪釘 | chicken_spike | 速度 -5（debuff_speed） | Y | `BattleController.gd` `use_item` 的 `debuff_speed` 分支 | — |
| 神速符 | haste_talisman | 我方加速 +8 或敵方轉「快」屬性 | Y | `BattleController.gd` `use_item` 的 `haste_talisman` 分支 | — |
| 霹靂彈 | item_pili_single | 敵方單體固定 20 傷害 | Y | `BattleController.gd` `use_item` → `_apply_bomb_single` | — |
| 轟雷霹靂彈 | item_pili_aoe | 敵方全體固定 15 傷害 | Y | `BattleController.gd` `use_item` → `_apply_bomb_aoe` | — |
| 烈火符 | item_fire_talisman | 預期火屬性/15 點效果 | N | `BattleController.gd` 預設 `_` 分支 | 使用時會出現「使用了 XX，但目前尚未實作 effect：fire_talisman。」且無實際效果 |
