# 武學相合（Martial Synergy）

`scripts/battlescripts/MartialSynergy.gd` 是「內功 × 武術」相合的**唯一正式資料表**。戰鬥規則、內功的專屬招式清單、
招式說明的搭配行、SkillView、Card Inspect「相合」頁都從這張表讀，一組搭配只寫一次。

## 記錄欄位
`synergy_id`、`relation_type`、`inner_skill_id`、`martial_skill_id`、`display_name`、`display_description`（長）、
`short_description`（短）、`linkage_kind`、`conditions[]`、`effects`（戰鬥實際讀的）、`modifiers`（玩家看的；`effects` 有的會自動換算，也可自己寫：
hit_count / status_apply / stat_scaling / target_rule / damage / mp_cost / element / spawn_entity / other）、`log`。

| relation_type | 標籤 | 執行期 |
|---|---|---|
| `standard` | 標準相合 | 在這裡：`runtime_rule()` → `CharacterSkill.get_pairing_rule`（流塵訣×連決劍 +1擊；伏潮訣×斷水斬 命中破防；沉潮訣×破浪槍 STR/AGI 加權） |
| `legendary_chain` | 傳說鏈 | **不在這裡**：石破心法×天驚拳（含「全身無裝備」→真．石破天驚拳）仍由 `SkillDB.legendary_chain` / `resolve_runtime_skill` 執行；這裡只供顯示 |
| `risk_branch` | 絕技分支 | **不在這裡**：天殘訣×地缺劍仍由 `SkillDB.risk_upgrade` 執行；這裡只供顯示 |

派生出去的東西：`CharacterSkill.get_pairing_rule`、`InnerForceDB.get_force().exclusive_skill_ids`（標準相合）、
`SkillDB.get_inner_force_linkage_entries` 的「專屬搭配／奧義條件／絕技分支」文字、Inspect「相合」頁。

## 新增一組標準相合
在 `RECORDS` 加一筆 `relation_type = standard`、寫 `effects`（目前戰鬥認得 `strike_count_delta`、`on_hit_status`、`bonus_stat_scaling`，以及支援招式用的 `team_status`：施放當下依施術者目前運行的內功成立，讓全隊獲得該狀態；清渠共印×澄心落筆用它）。
新的效果種類要先讓 BattleController / CharacterSkill 認得，表只是資料。不要在別處再寫一份文字。

## 三層顯示（基礎／相合／目前）
`SkillView.strike_info(skill, inner_force)` 回 `base/effective/delta/source` 與 `ranged`、`base_min/max`、`effective_min/max`、
`base_text/effective_text`（固定「3擊」、範圍「2～4擊」）。只是顯示；實際擊數仍由 `BattleController._resolve_strike_count` 擲。

## Inspect「相合」頁
左邊清單（【內功】【武術】）、右邊描述。只列「已習得的內功 × 已習得的武術」；沒習得的第一版不顯示。
內功不在運行 → 仍列出並標「未運行」，「目前」那層不套用它（與 SkillView 最終結果一致）。
從武術看見它相合的內功；從內功看見它相合的武術。每組顯示：關係類型標籤、說明、條件（如全身無裝備）、基礎／相合／目前。
「內功 × 武器類型」（兵器相性／法門加持）這輪不併入。

測試：`tests/test_martial_synergy.gd`（三條規則的 regression、表派生、strike_info、Inspect 相合頁）。

## 閃卡（搭配框掃光）
武學頁中間的搭配框，只要「目前內功 × 選到的招式」有成立的搭配就掃光。**不分內功、不分招式，全部走同一條資料路徑**：
`SkillDB.get_inner_force_linkage_entries` 回的每一列都帶 `tier`，頁面取成立列的最高等級：
1 藍＝武器加成（內功 `boost_weapon` ＝ 招式 `weapon_type`，數字與特殊敘述來自內功資料：`weapon_accuracy_flat_bonus`、`boost_damage_pct`、
`skill_mp_cost_multiplier_by_weapon`、`weapon_boost_note(_short)`，文字由 `InnerForceDB.weapon_boost_texts` 組）、
2 橘＝專屬搭配、3 紫＝絕技分支、4 紅＝奧義（後三者來自本表的 `linkage_kind`，對照在 `MartialSynergy.shine_tier`）。
新增內功只要填 `boost_weapon`、新增搭配只要寫進 `RECORDS`，閃卡自動出現；不要在別處再寫 per-force 的特例。
測試：`tests/test_martial_shine.gd`。
