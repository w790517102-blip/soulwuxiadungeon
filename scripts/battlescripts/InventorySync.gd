# InventorySync.gd
# ✅ Autoload 全域同步用道具庫：負責道具清單與戰鬥物品存取

extends Node

# === 初始背包道具 ===
var inventory: Array = [
	{
		"id": "herb",
		"name": "藥草",
		"description": "回復50點HP的藥草。",
		"effect": "heal",         # ✅ 走 use_item 裡的 heal/heal_hp 分支
		"amount": 50,
		"quantity": 3,            # 持有數量
		"target_scope": "ally_single"  # 單體友方
	},
	{
		"id": "elixir_qi",
		"name": "回氣丹",
		"description": "回復15點內力。",
		"effect": "mp_heal",      # ✅ 回復 MP
		"amount": 15,
		"quantity": 2,
		"target_scope": "ally_single"
	},
	{
		"id": "light_step_powder",
		"name": "輕身散",
		"description": "暫時提升使用者的身法速度。",
		"effect": "buff_speed",   # ✅ 速度 BUFF
		"amount": 5,
		"quantity": 2,
		"target_scope": "ally_single"
	},
	{
		"id": "chicken_spike",
		"name": "雞爪釘",
		"description": "拋向敵人足下，可拖慢對方腳步。",
		"effect": "debuff_speed", # ✅ 速度 DEBUFF
		"amount": 5,
		"quantity": 3,
		"target_scope": "enemy_single"
	},
	{
		"id": "haste_talisman",
		"name": "神速符",
		"description": "貼在己方可加速，貼在敵方可改變其屬性為「快」。",
		"effect": "haste_talisman",   # ✅ 特殊：我方加速 / 敵方改屬性
		"amount": 8,
		"quantity": 1,
		"target_scope": "all_single"  # ✅ 需要能選「任一單體」的 target_scope
	},
	# 單體炸彈：霹靂彈
	{
		"id": "item_pili_single",
		"name": "霹靂彈",
		"effect": "bomb_single",      # ✅ 效果代號
		"amount": 20,                  # ✅ 固定傷害
		"quantity": 3,
		"target_scope": "enemy_single"     # ✅ 單體
	},
# AOE：轟雷霹靂彈
	{
		"id": "item_pili_aoe",
		"name": "轟雷霹靂彈",
		"effect": "bomb_aoe",         # ✅ 效果代號
		"amount": 15,                  # ✅ 每隻固定傷害
		"quantity": 3,
		"target_scope": "enemy_all"  # ✅ 敵方全體
	},
        {
                "id": "item_fire_talisman",
                "name": "烈火符",
                "effect": "fire_talisman",
                "amount": 15,
                "enemy_damage": 30,
                "quantity": 3,
                "target_scope": "all_single" # 你可以自訂一個代表「可指定敵／我方」
        },

]

func get_items() -> Array:
	return inventory

# ✅ 取得所有具有戰鬥效果的道具（有 effect 欄位）
func get_battle_items() -> Array:
	return inventory.filter(func(i): return i.has("effect"))

# ✅ 消耗指定道具數量（預設1）
func consume_item(id: String, amount := 1):
	for i in inventory:
		if i.get("id") == id:
			i["quantity"] -= amount
			if i["quantity"] <= 0:
				inventory.erase(i)
			return

# ✅ 新增或疊加道具
func add_item(item: Dictionary):
	for i in inventory:
		if i.get("id") == item.get("id"):
			i["quantity"] += item.get("quantity", 1)
			return
	# 否則為新物品
	inventory.append(item)

# ✅ 查詢特定 ID 的道具（可用於描述）
func get_item_by_id(id: String) -> Dictionary:
	for i in inventory:
		if i.get("id") == id:
			return i
	return {}
