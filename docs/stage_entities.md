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
