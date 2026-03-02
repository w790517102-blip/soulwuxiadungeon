# InventorySync.gd
# ✅ Autoload 全域同步用背包系統：負責道具堆疊與戰利品結算

extends Node

const ItemDB = preload("res://scripts/db/ItemDB.gd")

signal inventory_changed
signal gold_changed(new_gold: int)
signal equipment_changed

var party_inventory: Array = [
	{"id": "herb", "count": 3},
	{"id": "elixir_qi", "count": 2},
	{"id": "light_step_powder", "count": 2},
	{"id": "chicken_spike", "count": 3},
	{"id": "haste_talisman", "count": 1},
	{"id": "item_pili_single", "count": 3},
	{"id": "item_pili_aoe", "count": 3},
	{"id": "item_fire_talisman", "count": 3},
	{"id": "iron_sword", "count": 1},
	{"id": "bronze_sword", "count": 1},
	{"id": "ink_brush", "count": 1},
	{"id": "yaoqin", "count": 1},
	{"id": "short_dao", "count": 1},
	{"id": "cloth_armor", "count": 1},
	{"id": "jade_pendant", "count": 1},
	{"id": "quest_letter", "count": 1},
]
const NEW_GAME_START_GOLD: int = 1000
var party_gold: int = NEW_GAME_START_GOLD
var equipped_by_actor: Dictionary = {}
const STAT_KEYS := ["atk", "def", "max_hp", "max_mp", "speed"]

func export_inventory_state() -> Dictionary:
	return {
		"party_inventory": party_inventory.duplicate(true),
		"party_gold": party_gold,
		"equipped_by_actor": equipped_by_actor.duplicate(true),
	}

func import_inventory_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	if typeof(data.get("party_inventory", null)) == TYPE_ARRAY:
		party_inventory = (data.get("party_inventory", []) as Array).duplicate(true)
	if typeof(data.get("party_gold", null)) in [TYPE_INT, TYPE_FLOAT]:
		party_gold = int(data.get("party_gold", 0))
	if typeof(data.get("equipped_by_actor", null)) == TYPE_DICTIONARY:
		equipped_by_actor = (data.get("equipped_by_actor", {}) as Dictionary).duplicate(true)
	inventory_changed.emit()
	gold_changed.emit(party_gold)
	equipment_changed.emit()

func get_gold() -> int:
	return party_gold

func get_items() -> Array:
	return _make_item_list(party_inventory)

func get_battle_items() -> Array:
	return get_items().filter(func(i):
		return str(i.get("use_action", "none")) == "consume" \
			and ["any", "battle"].has(str(i.get("use_scope", "none")))
	)

func get_item_by_id(id: String) -> Dictionary:
	for entry in party_inventory:
		if entry.get("id") == id:
			var item_def = ItemDB.get_def(id)
			if item_def.is_empty():
				return {}
			var item = item_def.duplicate(true)
			var count = int(entry.get("count", 0))
			item["quantity"] = count
			item["count"] = count
			item["description"] = item.get("desc", item.get("description", ""))
			return item
	return {}

func consume_item(id: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	for entry in party_inventory:
		if entry.get("id") == id:
			var new_count = int(entry.get("count", 0)) - amount
			if new_count <= 0:
				party_inventory.erase(entry)
			else:
				entry["count"] = new_count
			inventory_changed.emit()
			return

func add_item_stack(id: String, amount: int = 1) -> void:
	if _add_item_stack_internal(id, amount):
		inventory_changed.emit()

func equip_item(item_id: String, actor_id: String = "") -> void:
	var item_def := ItemDB.get_def(item_id)
	if item_def.is_empty():
		return
	if get_item_by_id(item_id).is_empty():
		return
	var slot := str(item_def.get("equip_slot", ""))
	if slot == "":
		return
	var equipped = _get_equipped_ref(actor_id)
	if not equipped.has(slot):
		return
	var current_id := str(equipped.get(slot, ""))
	if current_id == item_id:
		return
	if current_id != "":
		_add_item_stack_internal(current_id, 1)
	equipped[slot] = item_id
	consume_item(item_id, 1)
	equipment_changed.emit()

func unequip(slot: String, actor_id: String = "") -> void:
	var equipped = _get_equipped_ref(actor_id)
	if not equipped.has(slot):
		return
	var current_id := str(equipped.get(slot, ""))
	if current_id == "":
		return
	equipped[slot] = ""
	_add_item_stack_internal(current_id, 1)
	inventory_changed.emit()
	equipment_changed.emit()

func get_equipped(actor_id: String = "") -> Dictionary:
	return _get_equipped_ref(actor_id).duplicate(true)

func is_equipped(item_id: String, actor_id: String = "") -> bool:
	if item_id == "":
		return false
	var equipped = _get_equipped_ref(actor_id)
	for slot in equipped.keys():
		if str(equipped.get(slot, "")) == item_id:
			return true
	return false

func get_equipment_stat_bonus(actor_id: String = "") -> Dictionary:
	var bonus := {}
	for key in STAT_KEYS:
		bonus[key] = 0
	var equipped = _get_equipped_ref(actor_id)
	for slot in equipped.keys():
		var item_id := str(equipped.get(slot, ""))
		if item_id == "":
			continue
		var item_def := ItemDB.get_def(item_id)
		if item_def.is_empty():
			continue
		var stats: Dictionary = item_def.get("stats", {})
		for key in STAT_KEYS:
			if stats.has(key):
				bonus[key] = int(bonus.get(key, 0)) + int(stats.get(key, 0))
	return bonus

func _get_equipped_ref(actor_id: String) -> Dictionary:
	var resolved_id := _resolve_actor_id(actor_id)
	if not equipped_by_actor.has(resolved_id):
		equipped_by_actor[resolved_id] = {
			"weapon_1": "",
			"weapon_2": "",
			"armor": "",
			"accessory": "",
		}
	return equipped_by_actor[resolved_id]

func _resolve_actor_id(actor_id: String) -> String:
	if actor_id != "":
		return actor_id
	if TeamData and TeamData.current_team_ids.size() > 0:
		return str(TeamData.current_team_ids[0])
	return "liuyu"

func _add_item_stack_internal(id: String, amount: int) -> bool:
	if id == "" or amount <= 0:
		return false
	for entry in party_inventory:
		if entry.get("id") == id:
			entry["count"] = int(entry.get("count", 0)) + amount
			return true
	party_inventory.append({"id": id, "count": amount})
	return true

func apply_battle_result(battle_result: Dictionary) -> void:
	if battle_result.is_empty():
		return
	var gold_gain = int(battle_result.get("gold", 0))
	if gold_gain != 0:
		party_gold += gold_gain
		gold_changed.emit(party_gold)
	var drops = battle_result.get("drops", [])
	var inventory_changed_local := false
	if drops is Array:
		for drop in drops:
			if typeof(drop) != TYPE_DICTIONARY:
				continue
			var drop_id := str(drop.get("id", drop.get("item_id", "")))
			var drop_count := int(drop.get("count", 0))
			if drop_id == "" or drop_count <= 0:
				continue
			inventory_changed_local = _add_item_stack_internal(drop_id, drop_count) or inventory_changed_local
	elif drops is Dictionary:
		for key in drops.keys():
			var drop_id := str(key)
			var drop_count := int(drops[key])
			if drop_id == "" or drop_count <= 0:
				continue
			inventory_changed_local = _add_item_stack_internal(drop_id, drop_count) or inventory_changed_local
	if inventory_changed_local:
		inventory_changed.emit()
	var exp_gain = int(battle_result.get("exp", 0))
	if exp_gain > 0:
		print("[BattleResult] exp pending:", exp_gain)

func _make_item_list(source_inventory: Array) -> Array:
	var items: Array = []
	for entry in source_inventory:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id = str(entry.get("id", ""))
		if id == "":
			continue
		var count = int(entry.get("count", 0))
		var item_def = ItemDB.get_def(id)
		if item_def.is_empty():
			continue
		var item = item_def.duplicate(true)
		item["quantity"] = count
		item["count"] = count
		item["description"] = item.get("desc", item.get("description", ""))
		items.append(item)
	return items

func spend_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	if party_gold < amount:
		return false
	party_gold -= amount
	gold_changed.emit(party_gold)
	return true

func add_gold(amount: int) -> void:
	if amount == 0:
		return
	party_gold += amount
	gold_changed.emit(party_gold)


func is_item_equipped_anywhere(item_id: String) -> bool:
	if item_id == "":
		return false
	for actor_id in equipped_by_actor.keys():
		var equipped = equipped_by_actor[actor_id]
		if typeof(equipped) != TYPE_DICTIONARY:
			continue
		for slot in (equipped as Dictionary).keys():
			if str((equipped as Dictionary).get(slot, "")) == item_id:
				return true
	return false
