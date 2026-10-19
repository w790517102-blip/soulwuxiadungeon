extends SceneTree

# 機關：欄位、舊存檔相容、諸葛連弩裝備／卸下、TRIGGER 取得（沒裝備／被動就沒有按鈕）。
# 執行：godot --headless --path . --script tests/test_mechanism.gd

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL ", what)


func _run() -> void:
	await process_frame
	var inv = root.get_node("InventorySync")
	var trig_script: GDScript = load("res://scripts/battlescripts/MechanismTrigger.gd")
	inv.party_inventory = [{"id": "tool_zhuge_crossbow", "count": 1}, {"id": "ammo_arrow", "count": 3}, {"id": "jade_pendant", "count": 1}]
	inv.equipped_by_actor = {}
	var actor := {"id": "liuyu"}

	_check(inv.EQUIP_SLOTS.has("mechanism") and not inv.EQUIP_SLOTS.has("accessory_2"), "slot list has mechanism, not accessory_2")
	_check(trig_script.get_trigger(actor).is_empty(), "no mechanism equipped → no trigger (no button)")

	var def: Dictionary = load("res://scripts/db/ItemDB.gd").get_def("tool_zhuge_crossbow")
	_check(def.get("equip_slot") == "mechanism" and def.get("use_action") == "equip", "crossbow is an equippable mechanism")
	_check(not def.get("trigger", {}).is_empty(), "crossbow has a trigger")

	inv.equip_item_to_slot("tool_zhuge_crossbow", "mechanism", "liuyu")
	_check(inv.get_equipped("liuyu").get("mechanism") == "tool_zhuge_crossbow", "crossbow equips into the mechanism slot")
	_check(inv.get_item_by_id("tool_zhuge_crossbow").is_empty(), "equipped crossbow leaves the bag")
	var trig: Dictionary = trig_script.get_trigger(actor)
	_check(String(trig.get("effect", "")) == "zhuge_crossbow" and String(trig.get("target_scope", "")) == "enemy_single" and int(trig.get("power", 0)) == 18, "trigger keeps the old numbers (18 power, enemy single)")
	_check(trig_script.block_reason(trig) == "", "arrows available → can fire")
	_check(trig_script.get_trigger({"id": "shumian"}).is_empty(), "another actor without a mechanism → no trigger")
	inv.equip_item_to_slot("jade_pendant", "mechanism", "liuyu")
	_check(inv.get_equipped("liuyu").get("mechanism") == "tool_zhuge_crossbow", "a non-mechanism item cannot go into the mechanism slot")

	inv.party_inventory = [{"id": "tool_zhuge_crossbow", "count": 0}]
	inv.consume_item("ammo_arrow", 99)
	_check(trig_script.block_reason(trig) != "", "no arrows → blocked")

	inv.unequip("mechanism", "liuyu")
	_check(trig_script.get_trigger(actor).is_empty(), "unequipped → trigger gone")

	# 舊存檔：accessory_2 搬到空的飾品欄；飾品欄滿了就退回背包
	inv.party_inventory = []
	inv.equipped_by_actor = {}
	inv.import_inventory_state({"party_inventory": [], "equipped_by_actor": {"liuyu": {"accessory_2": "jade_pendant"}}})
	var eq: Dictionary = inv.get_equipped("liuyu")
	_check(eq.get("accessory_1") == "jade_pendant" and not eq.has("accessory_2"), "legacy accessory_2 moves to accessory_1")
	inv.import_inventory_state({"party_inventory": [], "equipped_by_actor": {"liuyu": {"accessory_1": "acc_bracer", "accessory_2": "jade_pendant"}}})
	_check(not inv.get_item_by_id("jade_pendant").is_empty(), "legacy accessory_2 returns to the bag when accessory_1 is taken")

	print("PASS test_mechanism" if _failures == 0 else "FAILED test_mechanism: %d" % _failures)
	quit(1 if _failures > 0 else 0)
