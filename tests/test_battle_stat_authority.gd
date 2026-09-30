extends SceneTree

const BattleControllerScript = preload("res://scripts/battlescripts/BattleController.gd")

var _failures: Array[String] = []


class FakeTeamData:
	extends Node
	var actors: Dictionary = {}

	func get_character_by_id(actor_id: String) -> Dictionary:
		return actors.get(actor_id, {})


func _initialize() -> void:
	_test_runtime_actor_isolated_from_canonical()
	_test_phase_resources_apply_after_equipment_baseline()
	_test_resource_sync_is_whitelisted()

	if _failures.is_empty():
		print("PASS: battle stat authority regression")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: %s" % failure)
		quit(1)


func _test_runtime_actor_isolated_from_canonical() -> void:
	var controller = BattleControllerScript.new()
	var canonical := {
		"id": "liuyu",
		"hp": 440,
		"max_hp": 440,
		"mp": 100,
		"max_mp": 100,
		"def": 20,
	}
	var runtime_party: Array = controller._build_player_battle_actors([canonical])
	var runtime: Dictionary = runtime_party[0]
	runtime["max_hp"] = 450
	runtime["def"] = 30
	runtime["status_effects"] = {"weaken": {"turns_left": 2}}
	_expect(int(canonical.get("max_hp", 0)) == 440, "equipment max HP does not mutate canonical data")
	_expect(int(canonical.get("def", 0)) == 20, "equipment DEF does not mutate canonical data")
	_expect(not canonical.has("status_effects"), "battle-only status does not leak into canonical data")
	controller.free()


func _test_phase_resources_apply_after_equipment_baseline() -> void:
	var controller = BattleControllerScript.new()
	controller.player_party = [{
		"id": "liuyu",
		"hp": 440,
		"max_hp": 450,
		"mp": 90,
		"max_mp": 100,
		"battle_base_max_hp": 450,
	}]
	controller._apply_initial_player_resources({
		"initial_player_resources": {
			"liuyu": {"hp": 450, "mp": 73},
		},
	})
	var runtime: Dictionary = controller.player_party[0]
	_expect(int(runtime.get("hp", 0)) == 450, "Phase II full HP clamps against equipment-integrated 450 baseline")
	_expect(int(runtime.get("mp", 0)) == 73, "Phase II carries current MP without copying status dictionaries")
	controller.free()


func _test_resource_sync_is_whitelisted() -> void:
	var controller = BattleControllerScript.new()
	var team_data := FakeTeamData.new()
	var canonical := {
		"id": "liuyu",
		"hp": 440,
		"max_hp": 440,
		"mp": 100,
		"max_mp": 100,
		"def": 20,
	}
	team_data.actors["liuyu"] = canonical
	controller.team_data_manager = team_data
	controller._sync_player_resources_to_canonical({
		"player_resources": {
			"liuyu": {"hp": 317, "mp": 61},
		},
	})
	_expect(int(canonical.get("hp", 0)) == 317, "normal battle end preserves current HP without refilling")
	_expect(int(canonical.get("mp", 0)) == 61, "normal battle end preserves current MP")
	_expect(int(canonical.get("max_hp", 0)) == 440, "runtime equipment max HP is not baked into canonical max HP")
	_expect(int(canonical.get("def", 0)) == 20, "resource sync cannot overwrite canonical equipment-independent stats")
	controller.free()
	team_data.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
