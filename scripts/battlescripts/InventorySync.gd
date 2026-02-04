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
	{"id": "cloth_armor", "count": 1},
	{"id": "jade_pendant", "count": 1},
	{"id": "quest_letter", "count": 1},
]
var party_gold: int = 0
var equipped := {
	"weapon": "",
	"armor": "",
	"accessory": "",
}

func get_gold() -> int:
	return party_gold

func get_items() -> Array:
	return _make_item_list(party_inventory)

func get_battle_items() -> Array:
	return get_items().filter(func(i): return i.has("effect"))

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

func equip_item(item_id: String) -> void:
	var item_def := ItemDB.get_def(item_id)
	if item_def.is_empty():
		return
	if get_item_by_id(item_id).is_empty():
		return
	var slot := str(item_def.get("equip_slot", ""))
	if slot == "":
		return
	var current_id := str(equipped.get(slot, ""))
	if current_id == item_id:
		return
	if current_id != "":
		_add_item_stack_internal(current_id, 1)
	equipped[slot] = item_id
	consume_item(item_id, 1)
	equipment_changed.emit()

func unequip(slot: String) -> void:
	if not equipped.has(slot):
		return
	var current_id := str(equipped.get(slot, ""))
	if current_id == "":
		return
	equipped[slot] = ""
	_add_item_stack_internal(current_id, 1)
	inventory_changed.emit()
	equipment_changed.emit()

func get_equipped() -> Dictionary:
	return equipped.duplicate(true)

func is_equipped(item_id: String) -> bool:
	if item_id == "":
		return false
	for slot in equipped.keys():
		if str(equipped.get(slot, "")) == item_id:
			return true
	return false

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
