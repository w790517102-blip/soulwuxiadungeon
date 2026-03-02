extends Node
class_name ShopDatabase

const SHOPS := {
	"yuheng_pharmacy": {
		"name": "玉衡鎮藥鋪",
		"items": [
			{"item_id": "med_bandage", "price": 12, "stock": -1},
			{"item_id": "med_stopbleed_herb", "price": 8, "stock": -1},
			{"item_id": "med_jinchuang_small", "price": 18, "stock": -1},
			{"item_id": "med_antidote_powder", "price": 15, "stock": -1},
			{"item_id": "med_awaken_tonic", "price": 18, "stock": -1},
			{"item_id": "med_calm_pill", "price": 22, "stock": -1},
			{"item_id": "med_qi_restore_small", "price": 20, "stock": -1},
			{"item_id": "med_warm_wine", "price": 25, "stock": -1},
			{"item_id": "med_heartguard_small", "price": 45, "stock": 2, "restock_rule": "never"},
			{"item_id": "mat_herb_bundle", "price": 10, "stock": -1},
		],
	},
	"yuheng_weapon_shop": {
		"name": "玉衡鎮武器店",
		"items": [
			{"item_id": "wep_wood_sword", "price": 25, "stock": -1},
			{"item_id": "wep_short_blade", "price": 45, "stock": -1},
			{"item_id": "wep_qingfeng_sword", "price": 60, "stock": -1},
			{"item_id": "wep_bamboo_staff", "price": 55, "stock": -1},
			{"item_id": "arm_cloth", "price": 35, "stock": -1},
			{"item_id": "acc_bracer", "price": 25, "stock": -1},
			{"item_id": "arm_straw_sandals", "price": 28, "stock": -1},
			{"item_id": "arm_thin_leather", "price": 80, "stock": -1},
		],
	},
	"yuheng_general_store_d": {
		"name": "雜貨攤",
		"items": [
			{"item_id": "misc_tinderbox", "price": 15, "stock": -1},
			{"item_id": "misc_hemp_twine", "price": 10, "stock": -1},
			{"item_id": "misc_small_rope", "price": 18, "stock": -1},
			{"item_id": "misc_sachet", "price": 20, "stock": -1},
			{"item_id": "misc_empty_bottle", "price": 8, "stock": -1},
			{"item_id": "food_dried_rations", "price": 12, "stock": -1},
			{"item_id": "misc_paper_ink", "price": 10, "stock": -1},
			{"item_id": "mat_herb_pouch", "price": 14, "stock": -1},
			{"item_id": "throw_stone_pack", "price": 12, "stock": -1},
			{"item_id": "misc_little_box", "price": 16, "stock": -1},
		],
	},
}

static func get_shop(shop_id: String) -> Dictionary:
	if not SHOPS.has(shop_id):
		return {}
	return (SHOPS[shop_id] as Dictionary).duplicate(true)
