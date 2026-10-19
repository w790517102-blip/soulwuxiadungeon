extends RefCounted
## 裝備頁的資料整理：欄位名稱、品類名稱、裝備前後數值比較、特殊效果說明。
## 只讀資料，不動實際裝備；數值用 system_menu.compute_overview_stats（與狀態頁同一套公式）。

const ItemDB = preload("res://scripts/db/ItemDB.gd")

## 版面順序：左 4 格、右 4 格（照概念圖）
const LEFT_SLOTS := ["weapon_1", "armor_head", "armor_hands", "accessory_1"]
const RIGHT_SLOTS := ["weapon_2", "armor_body", "armor_feet", "mechanism"]

const SLOT_LABELS := {
	"weapon_1": "主武器", "weapon_2": "副武器",
	"armor_head": "頭部", "armor_body": "身體", "armor_hands": "手部", "armor_feet": "足部",
	"accessory_1": "飾品", "mechanism": "機關",
}

## 裝備效果的數值列：[key, 名稱]。命中、閃避是「力」（與狀態頁一致）。
const STAT_ROWS := [
	["atk", "攻擊力"], ["def", "防禦力"], ["hit", "命中力"],
	["max_hp", "氣血上限"], ["max_mp", "內力上限"], ["speed", "速度"], ["evade", "閃避力"], ["crit", "暴擊率"],
]
## 沒有變動也一定列出的列（概念圖的三行）
const ALWAYS_ROWS := ["atk", "def", "hit"]

static func slot_label(slot: String) -> String:
	return String(SLOT_LABELS.get(slot, slot))

## 品類名稱：劍（刀、槍、琴、筆、棍…）類兵器、頭／身體／手部／足部護具、飾品、機關
static func category_label(item_def: Dictionary) -> String:
	match String(item_def.get("equip_slot", "")):
		"weapon_1", "weapon_2":
			var weapon_type := String(item_def.get("weapon_type", ""))
			return "%s類兵器" % weapon_type if weapon_type != "" else "兵器"
		"armor_head": return "頭部護具"
		"armor_body": return "身體護具"
		"armor_hands": return "手部護具"
		"armor_feet": return "足部護具"
		"accessory_1": return "飾品"
		"mechanism": return "機關"
	return ""

## 這位角色換上 new_item_id（空字串＝卸下）之後的假設裝備
static func equipped_after(actor_id: String, slot: String, new_item_id: String) -> Dictionary:
	var equipped: Dictionary = InventorySync.get_equipped(actor_id)
	equipped[slot] = new_item_id
	return equipped

## 裝備前後數值比較。回傳 [{key, label, before, after, delta}]，只含「有變動」或 ALWAYS_ROWS 的列。
## menu 是 system_menu（提供 compute_overview_stats）；actor 是角色資料。
static func compare(menu, actor, actor_id: String, slot: String, new_item_id: String) -> Array:
	var before: Dictionary = menu.compute_overview_stats(actor, InventorySync.get_equipment_stat_bonus(actor_id))
	var after_bonus: Dictionary = InventorySync.get_stat_bonus_for_equipped(equipped_after(actor_id, slot, new_item_id))
	var after: Dictionary = menu.compute_overview_stats(actor, after_bonus)
	var rows: Array = []
	for entry: Array in STAT_ROWS:
		var key: String = entry[0]
		var b = before.get(key, 0)
		var a = after.get(key, 0)
		var changed: bool = absf(float(a) - float(b)) > 0.0001
		if not changed and not ALWAYS_ROWS.has(key):
			continue
		rows.append({"key": key, "label": entry[1], "before": b, "after": a, "delta": float(a) - float(b)})
	return rows

static func format_value(key: String, value) -> String:
	return "%.1f%%" % float(value) if key == "crit" else str(int(value))

static func format_delta(key: String, delta: float) -> String:
	if absf(delta) < 0.0001:
		return "－"
	if key == "crit":
		return "%+.1f%%" % delta
	return "%+d" % int(round(delta))

## 特殊效果說明（機關的觸發、被動效果）；沒有就回傳「無特殊效果。」
static func special_effect_text(item_def: Dictionary) -> String:
	var parts: Array[String] = []
	if typeof(item_def.get("trigger", null)) == TYPE_DICTIONARY:
		parts.append(ItemDB.get_effect_display_text(item_def))
	var effects: Dictionary = item_def.get("equip_effects", {}) if typeof(item_def.get("equip_effects", null)) == TYPE_DICTIONARY else {}
	for key in effects.keys():
		match String(key):
			"animal_damage_taken_multiplier":
				parts.append("受到野獸的傷害%s" % _percent_change(float(effects[key])))
			"suppress_random_encounter_region_ids":
				parts.append("在特定區域行走時，不會遇到隨機戰鬥")
			_:
				parts.append(String(key))
	return "\n".join(parts) if not parts.is_empty() else "無特殊效果。"

static func _percent_change(multiplier: float) -> String:
	var pct := int(round((multiplier - 1.0) * 100.0))
	return "降低 %d%%" % -pct if pct < 0 else "提高 %d%%" % pct
