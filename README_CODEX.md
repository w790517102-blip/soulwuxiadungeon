# 語破江湖 — 戰鬥系統導覽（給 Codex）

Godot 4.4.1（GDScript）。本文只涵蓋「Card Stage 戰鬥演出」與「ADB（行動順序牌陣）／舞台實體」這一塊。場景、對話、劇情不在此範圍。

## 跑測試
Windows 上的 Godot 位置（本機）：`C:\Users\user\Desktop\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64_console.exe`

```bash
godot --headless --path . --script tests/test_substitute_talisman.gd
```

交接時全部通過的測試（括號為斷言數）：
`test_substitute_talisman`(31)、`test_card_stage_phase1`(810)、`test_combat_stage_25d`(95)、`test_multi_strike_log`(292)、`test_sheath_stance`(64)、`test_linfu_adjacency`、`test_linfu_battle_flow`(22)、`test_linfu_families`(45)、`test_stage_entity_hooks`(85)、`test_guest_turn`。
測試需要專案 autoload，所以一律用 `--script` 配 `--path .`，且測試內才 `load()` 依賴 autoload 的腳本。

## 架構速覽
| 區塊 | 檔案 |
|---|---|
| 戰鬥規則總控 | `scripts/battlescripts/BattleController.gd`（超大檔）、`SkillExecutor.gd`（單一 Hit 的傷害／格擋／命中）、`TurnManager.gd`（ADB） |
| 技能資料 | `scripts/db/SkillDB.gd`（技能欄位見下） |
| 舞台實體（站在牌陣裡的卡） | `StageEntity.gd`、`StageEntityRegistry.gd`、`StageEntityFactory.gd`、`StageAdjacency.gd`；實作：`SubstituteTalisman.gd`、`LinfuTalisman.gd`、`SheathCard.gd` |
| 演出 | `scripts/presentation/CardStage3D.gd`（舞台）、`CardStageBattleUI.gd`（UI→舞台橋）、`CardStageTokenCard.gd`（小卡）、各種 `*FX.gd` 與 `shaders/*.gdshader` |

詳細的舞台實體文件：`docs/stage_entities.md`；舞台本身：`docs/card_stage.md`、`docs/combat_stage_25d.md`。

### ADB（行動順序）
- `TurnManager.get_display_row(enemy_side)`：畫面與規則共用的「現在的順序」。**index 0 = 下一個行動者 = 畫面最右；最後一格 = 最左。**
- `get_display_order()` = 還沒行動者（依佇列）＋ 已行動者（依速度，`left_stamp` 者排在其他人後面）。
- `send_to_far_left(entry)`、`add_queue_actor(proxy, beside_actor)`、`remove_queue_actor(proxy)`（吃 Dictionary，不是 id）、`find_queue_actor(entity_id)`。
- 舞台實體若 `joins_turn_order`，會在這裡有一個 proxy 條目。

### 鄰接（`StageAdjacency.gd`）
只認 row 裡**直接左右各一張**；中間隔著任何卡就不算；首尾不相連；實體卡（持鞘、臨符、替身符）本身不是受益者／被保護者。

### 格擋管線
`SkillExecutor.block_provider`（`BattleController._hit_block_info(target, attacker)`）每個 Hit 落下前被問一次，回 `{"blocked", "text"}`。順序：先 `_substitute_for(target)`（替身符），沒有才 `_sheath_blocks_hit`（持鞘 50%，且持鞘必須在最右端）。替身符擋下時不會再問持鞘，避免兩張卡同時出來擋。演出走 `hit_blocked` 訊號 → `play_sheath_block`。

### 技能資料的特殊欄位
`stage_entity`（生成實體的資料區塊）、`requires_stance` / `unavailable_in_stance` / `ends_stance` / `sheath_combo`（站姿系統，`SkillDB.STANCES`）、`fx_style`（敵方技能指定演出：`staff_sweep`、`water_bullet`）、`adjacency_effects`（family／value／mode flat|percent／stack_rule）。

## 這一輪完成的內容
- 普攻演出：刀、拳（含天驚拳連打、真．石破天驚拳流星雨）、筆、琴、棍、槍；鏡面扭曲（mirage warp）、停格（`Engine.time_scale`）。
- 防禦演出（冰藍薄膜）、符咒施放（朱砂筆畫＋印）、治療／增益／減益演出。
- 敵方卡面模板（江湖／山賊／朝廷三色）。
- 客座左飲進入 ADB 並自動行動。
- 臨符系列六張（護脈、啟慧、聚福、燃鋒、固元、疾影、壯力）：ADB 裡的卡，效果於傷害當下即時依左右鄰居計算；現行為固定 +15（有 `_PCT` 版本，未來內功可把 +15 變 +15%）。
- 拔劍持鞘（劉語塵）：持鞘卡生成於劉語塵左側，站姿 HOLDING_SHEATH、鞘劍連擊、收鞘於背、50% 格擋，抽出／收回／格擋動畫。
- 墨鱗魘將：槍系技能用槍特效、尾巴掃擊用棍特效、水彈為全新水流特效。
- 替身符改版：不吸引仇恨，改為擋下緊貼左右兩側角色的第一個 Hit，行動結束後碎裂。

## 已知疑慮／請 Codex 留意
1. **卡片已改為「角色吃速度、卡片吃拓樸」（見 docs/stage_entities.md 最後一節）**：`turn_speed` 對卡片不再有排序作用；持鞘格擋改為緊貼劉語塵；沒有實機驗證。
2. **替身符沒有期限**（`duration_turns -1`），也不再右移。一次行動內「每位相鄰角色的第一個 Hit」被擋，行動結束才碎裂。
3. **舊替身符程式碼多半已成死碼**：`_priority_stage_entity_for`、`_perform_enemy_attack_on_entity`、`_advance_stage_entities`、`row_edge_distance`、`ignore_stage_entity_priority` 等。我沒有逐一清理，刪除前請確認沒有其他實體仍在用。
4. **持鞘格擋只在持鞘卡位於最右端（row[0]）才生效**，這是之前的規則；`_sheath_blocks_hit` 保留原簽名因為測試直接呼叫。與使用者近期描述的鄰接版本是否一致，我沒有重新確認。
5. `BattleController._last_blocker` 與 `_substitute_actions` 是控制器上的暫存狀態（單一行動內有效）；`perform_enemy_action` 現在是包裝函式，真正的內容在 `_perform_enemy_action_core`。若新增其他進入點，記得也要結算 `_spend_substitutes`。
6. `CardStageTokenCard.fly_to_block` 有 `_blocking` 防重入（一張符同時擋兩人時第二次只閃光）；其餘動畫（`play_draw`、`play_stow`）沒有類似防護。
7. 曾懷疑「破圖」（劉語塵的卡窗顯示成白書眠的立繪），後來判定是我的示範腳本造成（行動者還沒重新排序就前進），真實戰鬥不會；沒有留任何修改，但沒有做完整驗證。
8. 演出多半靠肉眼驗收，自動測試只涵蓋邏輯與排位，不涵蓋 shader 外觀。
9. 我沒有全面審查舊程式碼；上面只是我記得、有印象的點。

## 請勿碰的東西
工作目錄中有大量**與戰鬥無關、尚未提交**的檔案（約 27 個 `.tscn`、`scripts.rar` 被刪除、`docs/experiments/`、`scenes/fx/`、三個怪物場景、`zueyue_teashop_night.tscn`）。那是使用者另外的工作，不是我們的，請不要順手提交或還原。

## 下一步（使用者預告）
場景優化、對話系統優化、以及「墨鱗魘將二階段被擊敗後、回飲月山莊之前」的過場動畫。這些我尚未調查，請見 `HANDOFF_TO_CODEX.md`。
