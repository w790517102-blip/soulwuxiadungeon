# 語破江湖 — 戰鬥系統導覽（給 Codex）

Godot 4.4.1（GDScript）。本文只涵蓋「Card Stage 戰鬥演出」與「ADB（行動順序牌陣）／舞台實體」這一塊。場景、對話、劇情不在此範圍。

## 用語
**僚卡／支援卡**：所有「非角色卡」的卡片（持鞘、臨符如護脈符、替身符，以及未來的飛刀、詭雷等），舊稱「小雞卡」。對照：角色卡（劉語塵、書眠、左飲、敵方角色）才有速度；僚卡只吃牌陣順序。程式識別字（`StageEntity`、`stage_entity`、`is_stage_entity`、`follow_topology`、`entity_cards`）暫不改名。

## 跑測試
Windows 上的 Godot 位置（本機）：`C:\Users\user\Desktop\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64_console.exe`

```bash
godot --headless --path . --script tests/test_card_positions.gd
```

目前全部通過的測試：
`test_card_positions`、`test_substitute_talisman`(37)、`test_sheath_stance`(65)、`test_linfu_adjacency`、`test_linfu_battle_flow`(22)、`test_linfu_families`(45)、`test_stage_entity_hooks`(85)、`test_guest_turn`、`test_liuyu_sheath_known`、`test_card_stage_phase1`(810)、`test_combat_stage_25d`(95，含隨機命中，偶爾不穩)、`test_multi_strike_log`(292)。
測試需要專案 autoload，所以一律用 `--script` 配 `--path .`；測試內才 `load()` 依賴 autoload 的腳本，autoload 節點名稱是 `TeamData`（不是 `TeamDataManager`）。
**測試只涵蓋邏輯與排位，演出（shader、動畫、懸停手感、灰階）沒有自動驗證，全靠使用者實機驗收。**

## 架構速覽
| 區塊 | 檔案 |
|---|---|
| 戰鬥規則總控 | `scripts/battlescripts/BattleController.gd`（超大檔）、`SkillExecutor.gd`（單一 Hit 的傷害／格擋／命中）、`TurnManager.gd`（ADB） |
| 技能資料 | `scripts/db/SkillDB.gd`；角色「已學招式」另在 `TeamDataManager.gd`（`known_skill_ids_by_actor`、`LIUYU_INNATE_SKILL_IDS`）——新增角色技能兩邊都要接 |
| 舞台實體（站在牌陣裡的卡） | `StageEntity.gd`、`StageEntityRegistry.gd`、`StageEntityFactory.gd`、`StageAdjacency.gd`；實作：`SubstituteTalisman.gd`、`LinfuTalisman.gd`、`SheathCard.gd` |
| 演出 | `scripts/presentation/CardStage3D.gd`（舞台）、`CardStageBattleUI.gd`（UI→舞台橋）、`CardStageActorCard.gd`（角色卡）、`CardStageTokenCard.gd`（符卡）、`CardStageFormation.gd`（排位幾何）、各種 `*FX.gd` 與 `shaders/*.gdshader` |

詳細文件：`docs/stage_entities.md`（舞台實體、卡片排位規則、回合動畫與互動）；`docs/card_stage.md`、`docs/combat_stage_25d.md`。

### ADB 規則（角色吃速度，卡片吃拓樸）——最新規格見 docs/stage_entities.md 最後兩節
- `TurnManager.get_display_row(enemy_side)`：畫面與規則共用的「現在的順序」。**index 0 = 最右端 = Resolution Frontier；最後一格 = 最左。**
- **角色**依速度排序（`_character_order`：還沒行動者＋已行動者，已行動者依回到最左的順序 `left_stamp`）。**卡片（非角色）沒有速度**；每張卡記住「它右側有哪些角色」(`right_keys`) 與卡間次序 (`rank`)，讀取時排在「右側仍存活角色數」那一格之後。因此：速度改變只讓角色互換位置、卡片不動；角色死亡不會把卡片轉給別人。
- **角色結束回合 (`end_turn`)**：自己回最左；他左側連續的 `follow_topology` 卡（目前只有持鞘）不會瞬移，而是依距離由近到遠各自「走到最右端」輪到自己的回合（`_chick_queue`、`_bring_to_frontier`），播完動畫／倒數（無事可做的卡停 0.8 秒）後各自回最左。本輪才施放的卡直接跟著走。
- **Frontier 卡的回合**：`next_turn` 會先處理 `pending_frontier_card()`（最右端、尚未行動的卡）；一輪的結束會等它。回合內容 `BattleController._run_stage_entity_turn`：先 `on_activation`（能力），再依 `duration_turns` 倒數（≥0 倒數、−1 無壽命不扣）。
- `send_to_far_left(entry)`（只搬這一個，並標記不會被 End Turn 再搬一次，鞘劍連擊用）、`add_queue_actor(proxy, beside_actor)`（預設最左，`beside_actor` = 插在他左邊一格）、`remove_queue_actor(proxy)`（吃 Dictionary）、`resort_remaining_characters()`（速度中途改變時呼叫；**目前沒有任何技能呼叫它**）。
- 鄰接（`StageAdjacency.gd`）：只認 row 裡直接左右各一張；隔卡不算；首尾不相連；實體卡本身不是受益者。

### 格擋管線
`SkillExecutor.block_provider`（`BattleController._hit_block_info(target, attacker)`）在每個「已命中」的 Hit 落下前被問一次，回 `{"blocked","text"}`。順序：先 `_substitute_for(target)`（緊貼該角色左右、仍有次數的替身符：**一次敵方行動算一次，這次行動落在鄰居身上的每個 Hit 都被擋**，行動結束 `_spend_substitutes` 才碎裂），沒有才 `_sheath_blocks_hit`（持鞘卡緊貼劉語塵時每 Hit 50%）。替身符擋下時不再問持鞘。戰報：多段攻擊的被擋 Hit 寫「被擋下了」。演出：`hit_blocked` → `play_sheath_block` 記下擋的卡；`CardStage3D.present_attack` 開頭的 `_schedule_block_reactions` 依每個被擋 Hit 排程 `ActorCard.show_block()`（卡片飛到角色面前、角色只做格擋姿勢，不側步）。

### 回合節奏
`BattleController.safe_end_turn` 在結束行動前會 `_await_action_finished`：舞台演出完全結束（牌陣穩定、卡片停穩）**且**戰報輸出完才放行下一個行動。

### 卡片檢閱（Card Inspect）
見 `docs/card_inspect.md`：玩家選擇行動期間左／右鍵點任何卡開啟；當前可行動卡左鍵仍是行動。戰場卡面維持單字（`BATTLEFIELD_STATUS_ICONS = false`），ICON 在檢閱面板。

### 互動
滑鼠指到任何卡（含符卡）會浮起、鄰居讓開（`CardStage3D._update_pointer_hover`，範圍限制在畫面帶 `PARTY_BAND`/`ENEMY_BAND`）；**只在玩家回合、尚未打開指令選單／選目標／動畫時**啟用（`CardStageBattleUI.pointer_hover_allowed`）。已行動的卡立繪變暗、名稱後出現紅字「行動結束」（`set_standby`）。符卡的移動方式與速度和角色卡相同（一般滑動 0.4 秒；剛行動完的卡 0.7 秒繞到其他卡後方回最左）。

### 技能資料的特殊欄位
`stage_entity`（生成實體的資料區塊，含 `follow_topology`、`joins_turn_order`、`duration_turns`；`turn_speed` 已不被讀取）、`requires_stance` / `unavailable_in_stance` / `ends_stance` / `sheath_combo`（站姿系統，`SkillDB.STANCES`）、`fx_style`（敵方技能指定演出：`staff_sweep`、`water_bullet`）、`adjacency_effects`（family／value／mode flat|percent／stack_rule）。

## 這一輪完成的內容
- 普攻演出：刀、拳（含天驚拳連打、真．石破天驚拳流星雨）、筆、琴、棍、槍；鏡面扭曲、停格。
- 防禦演出、符咒施放、治療／增益／減益演出；敵方三色卡面模板；客座左飲進入 ADB 並自動行動。
- 臨符系列（護脈、啟慧、聚福、燃鋒、固元、疾影、壯力）：ADB 裡的卡，效果於傷害當下依左右鄰居即時計算；現行為固定 +15（有 `_PCT` 版本）。
- 拔劍持鞘（劉語塵）：持鞘卡、站姿、鞘劍連擊（劉打→鞘打→鞘歸→劉歸）、收鞘於背、50% 格擋，抽出／收回／格擋動畫；已補進劉語塵的已學招式（新檔與舊檔都會補）。
- 替身符改版：不吸引仇恨，擋緊貼兩側角色卡的傷害，行動結束後碎裂。
- 墨鱗魘將：槍系技能用槍特效、尾巴掃擊用棍特效、水彈為全新水流特效。
- ADB 重構：卡片只吃拓樸、僚卡跟隨、Frontier 卡自己的回合與倒數動畫、行動結束標示、滑鼠懸停、下一個行動等演出與戰報都結束。

## 已知疑慮／請 Codex 留意
1. **演出都沒有自動驗證**。卡片破圖（相鄰卡片平面交叉）是否真的消失、懸停手感、倒數動畫、行動結束標示都需使用者實機確認；我用過的對策：符卡旁間距 `ENTITY_GAP` 1.9、我方有符卡那一排越外側越往後 0.12（`CardStageFormation.slot`）。
2. **替身符、護脈符目前 `follow_topology = false`**（會被角色一個個走過後推到最右端結算）。只有持鞘是跟隨卡。每種新卡都要自己宣告。
3. **鞘劍連擊後，劉語塵左邊若還有其他跟隨卡不會跟著他走**（他是自己 `send_to_far_left`）。目前只有持鞘一張跟隨卡所以沒發生。
4. **劉語塵倒下時的持鞘**規格沒定：現在留在場上、被推到最右端結算空回合再回最左。
5. **舊替身符機制的死碼沒清**：`_priority_stage_entity_for`、`_perform_enemy_attack_on_entity`、`_advance_stage_entities`、`row_edge_distance`、`ignore_stage_entity_priority`。刪除前先確認沒有其他實體仍在用。
6. `BattleController._last_blocker`、`_substitute_actions` 是單一敵方行動內的暫存；`perform_enemy_action` 是包裝，內容在 `_perform_enemy_action_core`。新增敵方行動入口要記得結算 `_spend_substitutes`。敵方「全體攻擊專屬演出」(`play_enemy_area_fx`) 沒有套用逐 Hit 的格擋演出，仍走舊的 `block_pending`。
7. `safe_end_turn` 現在是協程（有 `await`）；舊呼叫點若假設它同步完成要留意。有約 30 秒的上限避免演出出錯卡死。
8. `test_combat_stage_25d` 與戰報文案有隨機成分，偶爾會不穩。
9. 我沒有全面審查舊程式碼；上面只是記得、有印象的點。

## 請勿碰的東西
工作目錄中有**與戰鬥無關、尚未提交**的檔案（約 27 個 `.tscn`、`scripts.rar` 被刪除、`docs/experiments/`、`scenes/fx/`、三個怪物場景、`zueyue_teashop_night.tscn`）。那是使用者另外的工作，請不要順手提交或還原；提交時只選自己動過的檔案，不要 `git add -A`。

## 下一步（使用者預告）
場景優化、對話系統優化、以及「墨鱗魘將二階段被擊敗後、回飲月山莊之前」的過場動畫。這些尚未調查，見 `HANDOFF_TO_CODEX.md`。
