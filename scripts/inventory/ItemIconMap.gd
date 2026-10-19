extends RefCounted
class_name ItemIconMap
# 道具 → 通用圖組（01–16）對照表。之後補「專屬圖」時：在 DEDICATED 裡填 道具id → 檔名（不含副檔名），不用動別的地方。
# 圖檔位置：assets/UI/inventory/item_icon_XX.png（小圖 80×80）、item_art_XX.png（大圖 380×560）。
# 專屬圖放在：assets/UI/inventory/dedicated/<名稱>_icon.png、<名稱>_art.png。

const GROUP_NAMES := {
	1: "herb", 2: "medicine", 3: "wine", 4: "bandage", 5: "sword", 6: "saber", 7: "spear", 8: "armor",
	9: "shoes", 10: "gloves", 11: "accessory", 12: "book", 13: "letter", 14: "tea", 15: "food", 16: "tools",
}

## 專屬圖（目前沒有）：{"道具id": "檔名前綴"}
const DEDICATED := {}

## 明確指定的道具 → 組別（依 2026-10-19 的道具資料）
const EXPLICIT := {
	"med_stopbleed_herb": 1, "item_antidote_herb": 1, "med_trauma_herb": 1, "quest_valley_shadow_grass": 1,
	"mat_herb_pouch": 1, "mat_herb_bundle": 1, "food_walnut": 1,
	"med_antidote_powder": 2, "med_awaken_tonic": 2, "med_calm_pill": 2, "med_qi_restore_small": 2, "med_focus_powder": 2,
	"med_heartguard_small": 2, "med_jinchuang_small": 2, "med_smoke_sand": 2, "med_binding_resin": 2,
	"med_warm_wine": 3, "med_bandage": 4,
	"wep_wood_sword": 5, "wep_qingfeng_sword": 5, "wep_short_blade": 6, "wep_bamboo_staff": 7,
	"arm_cloth": 8, "arm_thin_leather": 8, "arm_leather_cloth": 8,
	"arm_straw_sandals": 9, "arm_boss_running_shoes": 9,
	"cloth_gloves": 10, "leather_gloves": 10, "arm_boss_crit_gloves": 10,
	"acc_bracer": 11, "acc_boss_sighting_ring": 11, "misc_sachet": 11,
	"item_yinpingyu_scroll": 13, "misc_paper_ink": 13,
	"food_dried_rations": 15, "item_gushi_lunchbox": 15, "quest_green_beans_raw": 15, "quest_green_beans_fried": 15,
	# 2026-10-19 補：實際背包裡的道具 id
	"herb": 1, "elixir_qi": 2, "light_step_powder": 2,
	"haste_talisman": 13, "item_fire_talisman": 13, "quest_letter": 13,
	"chicken_spike": 16, "item_pili_single": 16, "item_pili_aoe": 16,
	"ammo_arrow": 16, "tool_zhuge_crossbow": 16, "throw_stone_pack": 16, "misc_smoke_pellet": 16,
	"item_clean_charcoal": 16, "misc_hemp_twine": 16, "misc_small_rope": 16, "misc_empty_bottle": 16,
	"ink_brush": 16, "yaoqin": 16,
}

## 回傳通用圖組編號（1–16）。順序：明確指定 → 前綴（book_、tea_）→ 道具資料（裝備欄位、武器類型）→ 工具與雜物（16）。
static func group_of(item_id: String, item_def: Dictionary = {}) -> int:
	if EXPLICIT.has(item_id):
		return int(EXPLICIT[item_id])
	if item_id.begins_with("book_"):
		return 12
	if item_id.begins_with("tea_"):
		return 14
	var slot := String(item_def.get("equip_slot", ""))
	var wtype := String(item_def.get("weapon_type", ""))
	if slot.begins_with("weapon"):
		match wtype:
			"劍": return 5
			"刀": return 6
			"槍", "棍": return 7
		return 5
	match slot:
		"armor_head", "armor_body": return 8
		"armor_feet": return 9
		"armor_hands": return 10
		"accessory_1", "accessory_2": return 11
	match String(item_def.get("type", "")):
		"book": return 12
		"consumable": return 2
		"food": return 15
		"material": return 1
	return 16

static func icon_path(item_id: String, item_def: Dictionary = {}) -> String:
	if DEDICATED.has(item_id):
		return "res://assets/UI/inventory/dedicated/%s_icon.png" % DEDICATED[item_id]
	return "res://assets/UI/inventory/item_icon_%02d.png" % group_of(item_id, item_def)

static func art_path(item_id: String, item_def: Dictionary = {}) -> String:
	if DEDICATED.has(item_id):
		return "res://assets/UI/inventory/dedicated/%s_art.png" % DEDICATED[item_id]
	return "res://assets/UI/inventory/item_art_%02d.png" % group_of(item_id, item_def)
