# 舞台實體（Stage Entity）預留擴充點

目前**沒有任何玩法使用它**，只是替未來的「殘響、掩體、塔羅、機關、召喚物、技能實體」留門。空註冊表時，所有掛鉤都是 no-op，既有戰鬥行為不變。

## 分類
- **Actor**：我方、敵方、首領。維持原本的 Dictionary 與 `StageActorCard`，不動。
- **Stage Entity**：站在戰場上的非角色互動物件（本文件）。
- **Attached Marker**（Buff/Debuff/印記/護盾）：不是舞台實體，繼續附著在被影響者身上。

## 檔案與位置
| 檔案 | 內容 |
| --- | --- |
| `scripts/battlescripts/StageEntity.gd` | 共通資料／介面：`entity_id, entity_type, owner_id, faction, targetable, damageable, healable, max_hp, current_hp, duration_turns, priority, tags`，另有 `card_kind / card_config / data`。`from_dict()`、`take_damage()`、`heal()`、`advance_duration()`、`modify_target_priority()`、`is_self()`，以及 10 個空的 `on_*` 生命週期 hook。 |
| `scripts/battlescripts/StageEntityRegistry.gd` | 註冊表，掛在 `BattleController.stage_entities`。`register_/unregister_stage_entity`、`get_stage_entities`、`get_targetable_entities`、`get_entities_by_faction/tag/owner`、`get_entity(id)`、`destroy_entity`、`expire_entity`、`dispatch(event, ctx)`、`modify_target_score()`；signals：`entity_registered / entity_unregistered / entity_event`。 |
| `scripts/battlescripts/StageTargeting.gd` | `Kind`：`ENEMY_ACTOR, ALLY_ACTOR, ANY_ACTOR, STAGE_ENTITY, ALLY_STAGE_ENTITY, ENEMY_STAGE_ENTITY, ANY_TARGETABLE`；`resolve()`；`kind_for_scope()` 把舊的 `target_scope` 字串對應到新類型。 |
| `scripts/presentation/CardStageEntityCard.gd` | 預設的小型實體卡（名字＋HP）。 |

## 掛接位置
- **目標選擇**：`BattleController.get_targets_by_type(kind, user, include_dead)`。角色類型的結果與既有 `get_valid_targets_for_*` 相同；既有函式一律不動。
- **傷害／治療**：`BattleController.apply_damage_to_target(target, amount, context)`／`apply_heal_to_target(...)`。實體走自己的 `take_damage/heal`，並觸發 `on_damage_taken / on_healed / on_destroyed`；角色字典走同樣的 HP 規則（含 `BattleDamageGuard`）。**既有技能仍走 `SkillExecutor`，不經過這裡。**
- **生命週期**（`registry.dispatch`，全部在既有流程裡各加一行）：
  - `on_turn_start`：`_on_turn_started` 開頭
  - `on_turn_end`：`_on_turn_ended` 開頭
  - `on_before_action`：`execute_action` 開頭
  - `on_after_action`：`safe_end_turn` 開頭（行動結束；回合被跳過時也會到這裡）
  - `on_spawn`：註冊時；`on_destroyed`／`on_expire`：`destroy_entity`／`expire_entity`；`on_manual_activate`：由玩家互動的系統自行 `dispatch`。
  - 不需要改 `TurnManager`。
- **AI 權重**：`EnemyAI.target_score(enemy, candidate, base)`、`pick_weighted_target(enemy, candidates)`，會詢問註冊表裡每個實體的 `modify_target_priority`。**尚未接進現有的 `_choose_target_for_entry`**（那裡仍是均勻隨機，結果不變）；日後把那一行換成 `pick_weighted_target` 即可。
- **舞台（Card Stage）**：`spawn_stage_entity_card / remove_stage_entity_card / update_stage_entity_card`、`bind_entity_registry`（自動跟隨註冊表）、`entity_card_factories[card_kind]`（自訂卡片外觀，任何 Node3D，只要有 `home_position / home_rotation / card_size / interaction_priority / set_home / refresh`）。
- **點選**：`CardStage3D.target_card(target)` 與 `pick_target(screen, candidates)`：候選可混合角色與實體，取最近者，距離相同時比 `interaction_priority`。既有 `pick_actor` 不變。
- **數量**：實體卡數量不限；角色排位移除了「最多 3 張」的箭位（`Formation.slot` 不再夾在 3）。客座只在隊伍少於 `guest_party_limit`（預設 3，目前遊戲規則）時顯示，已改成具名設定。

## 三個未來案例怎麼接（不需改戰鬥核心）
- **殘響**：子類別實作 `on_turn_end`（請玩家選敵人後發動），`duration_turns = 2`，`damageable = true`。
- **掩體**：`modify_target_priority` 對自己加權；敵人 AI 改用 `pick_weighted_target`。`get_targets_by_type(ENEMY_STAGE_ENTITY, …)` 讓我方也能選到敵方的掩體。
- **塔羅牌**：實作 `on_damage_taken`、`on_healed`、`on_manual_activate`，各自產生不同效果。

## 注意
- Godot 無法比較 Dictionary 與 Object（`candidate == self` 會報錯）；用 `is_self(candidate)`。
- 排位與行動順序列目前只處理角色卡；實體要不要進入行動順序列，等實際玩法決定（`entity_slot` 只是佔位排法）。

測試：`--headless --path . --script tests/test_stage_entity_hooks.gd`（mock 實體的註冊／取得／移除、目標類型、傷害治療、生命週期、AI 權重、卡片生成與移除、混合點選、超過 6 張卡）。

## 第一個舞台卡技能：替身符
- 資料：`SkillDB` 的 `skill_substitute_talisman`（書眠、筆、20 MP、1 等學會、`stage_entity` 資料區塊）。任何帶 `stage_entity` 的技能都會直接生成該實體、不需選目標（`BattleController._execute_stage_entity_skill`，由 `StageEntityFactory` 建立）。
- 實體：`SubstituteTalisman.gd`（`guard_charges` 一次承傷、不可治療；內部 HP 僅為 1）。排在我方列最左（客座右側），欄位 `row / row_edge_distance / advance_policy / advance_amount / expire_at_edge` 皆為資料，每輪結束向右推進一格，超過最右端失效離場。
- 敵方：`_priority_stage_entity_for` 以 AI 掛鉤給替身符極高權重；僅單體傷害技能會被引去，全體技能照常對每個目標各自判定命中（替身符也有自己的命中判定，可能被閃過），替身符不會替任何人擋掉那一份；`ignore_stage_entity_priority` 的技能可繞過。
- 演出：書眠上前一步 → 一筆畫出符咒（純黑不暈開＋會暈開的濕墨兩支筆刷疊畫）→ 爆開、墨點、鏡頭墨濺 → 卡片從爆點展開並插入最左，角色讓位、全部到位後才進行下一個動作 → 被擊中時震動、裂開、碎屑。卡片為角色卡的 85%。

## 臨符系：活在 ADB 時間軸裡的規則卡（第一張：護脈符）
臨符不再是掛在角色身上的 Buff。它是一張真正進入我方行動順序（ADB）的 Stage Entity：有自己的位置、自己的行動次數，效果由「此刻誰站在它旁邊」即時決定，不是施放時綁定。

- **資料**：`SkillDB` 的 `skill_linfu_humai`（書眠、筆、7 MP、`stage_entity` 區塊、無目標）。`entity_type = "linfu_talisman"`（`LinfuTalisman.gd`），`joins_turn_order = true`，`turn_speed = 999`，`duration_turns = 3`（計它自己的行動次數），`adjacency_pattern = "both"`，`adjacency_effects = [{family: DEFENSE_UP, value: 0.15, stack_rule: HIGHEST_ONLY}]`。標籤 `talisman / linfu / defense`，`targetable = false`。
- **進入順序**：`StageEntity` 新增 `joins_turn_order`、`turn_speed`、`on_activation()` hook。`TurnManager.add_queue_actor(proxy)` 把它放進本輪佇列最後（顯示上就是我方列最左）；之後每輪依速度與所有人一起排序。移除用 `remove_queue_actor`（登記表註銷時自動執行）。
- **排位**：位置變化完全來自既有順序輪轉，符沒有自己的移動邏輯。`TurnManager.get_display_order()` / `get_display_row(enemy_side)` 是畫面與規則共用的「現在的順序」（下一個行動者在最右、index 0）；`CardStage3D.order_keys()` 直接用它。
- **鄰接**：`StageAdjacency.gd`。只認 row 裡直接左右各一張的**活著的角色**（客座也算），隔卡不算（中間有其他實體就被擋住），首尾不相連。支援 `both / left / right`，未來可擴充其他 pattern。
- **效果家族**：`DEFENSE_UP / DAMAGE_REDUCTION / PARRY_UP / STATUS_RESIST`，預設 `HIGHEST_ONLY`（同家族只取最高，不疊加）；`ADD` 規則已預留。
- **生效時機**：`BattleController.get_adjacency_effects(actor)` 每次都從即時順序重算；`SkillExecutor.adjacency_provider` 在算傷害時讀 `DEFENSE_UP`（防禦 ×(1+bonus)）。所以敵人真正出手的那一刻誰站在旁邊，就是誰受護持。
- **壽命**：輪到符時（`_run_stage_entity_turn`）：`on_activation` → `duration -= 1` → 演出脈動 → 耗盡則 `expire_entity`，卡片消散並退出順序，護持立刻消失。不看白書眠回合、全局 Round 或任何人的行動數。
- **舞台**：符卡（`CardStageTokenCard`，圖為替身符插圖轉青碧色，角標顯示剩餘次數）與角色一起排位；被護持的卡牌有淡淡青碧護脈光（`set_ward_aura`），隨順序輪轉同步更新；失效時紙灰與金粉飄散再淡出。
- 測試：`tests/test_linfu_adjacency.gd`（邏輯與情境）、`tests/test_linfu_battle_flow.gd`（真實戰鬥控制器：施放、即時鄰接、傷害減免、三次行動後離場）。
