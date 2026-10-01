extends SceneTree

const ControllerScript = preload("res://scripts/encounter/RandomEncounterController.gd")
const ProfilesScript = preload("res://scripts/encounter/EncounterProfiles.gd")
const LIUYU_SOURCE := "res://scripts/liu_yu.gd"
const GAME_ROOT_SOURCE := "res://scripts/game_root.gd"
const SECRET_ROOM_SOURCE := "res://scripts/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_secret_room/yuheng_sewer_secret_room.gd"

var _failures: Array[String] = []
var _rolls: Array[Dictionary] = []


func _initialize() -> void:
	_test_pressure_milestones()
	_test_region_persistence_and_reset()
	_test_integration_contracts()
	if _failures.is_empty():
		print("PASS: random encounter pressure static contracts")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: %s" % failure)
		quit(1)


func _test_pressure_milestones() -> void:
	_rolls.clear()
	var controller = ControllerScript.new()
	controller.roll_evaluated.connect(_on_roll_evaluated)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	controller.enter_region(
		"test_zone",
		{
			"encounter_region_id": "test_region",
			"encounter_profile": {
				"pressure_checks": [
					{"distance": 1600.0, "chance": 0.0},
					{"distance": 2000.0, "chance": 0.0},
					{"distance": 2400.0, "chance": 0.0},
				],
				"max_pressure_interval": 400.0,
				"max_pressure_chance": 0.0,
			},
		},
		{}
	)

	controller.advance_distance(1599.0, rng)
	_expect(_rolls.is_empty(), "0..1599 px must be completely safe")
	controller.advance_distance(1.0, rng)
	_expect(_rolls.size() == 1 and is_equal_approx(float(_rolls[0]["chance"]), 0.0), "crossing 1600 px must roll exactly once")
	controller.advance_distance(399.0, rng)
	_expect(_rolls.size() == 1, "remaining between milestones must not reroll per frame")
	controller.advance_distance(1.0, rng)
	_expect(_rolls.size() == 2 and is_equal_approx(float(_rolls[1]["distance"]), 2000.0), "crossing 2000 px must roll exactly once")
	controller.advance_distance(400.0, rng)
	_expect(_rolls.size() == 3 and is_equal_approx(float(_rolls[2]["distance"]), 2400.0), "crossing 2400 px must roll exactly once")
	controller.advance_distance(400.0, rng)
	controller.advance_distance(400.0, rng)
	_expect(_rolls.size() == 5, "2400 px misses must retry once per additional 400 px")
	_expect(is_equal_approx(float(_rolls[3]["distance"]), 2800.0), "first max-pressure retry must be at 2800 px")
	_expect(is_equal_approx(float(_rolls[4]["distance"]), 3200.0), "second max-pressure retry must be at 3200 px")


func _test_region_persistence_and_reset() -> void:
	var controller = ControllerScript.new()
	var rng := RandomNumberGenerator.new()
	var config := {
		"encounter_region_id": "shared_region",
		"encounter_profile": {
			"pressure_checks": [{"distance": 1600.0, "chance": 0.0}],
			"max_pressure_interval": 400.0,
			"max_pressure_chance": 0.0,
		},
	}
	controller.enter_region("map_a", config, {})
	controller.advance_distance(1300.0, rng)
	controller.leave_region("shared_region")
	controller.enter_region("map_b", config, {})
	_expect(is_equal_approx(controller.get_accumulated_distance(), 1300.0), "same encounter region must preserve pressure across scenes")
	controller.reset_all()
	_expect(is_zero_approx(controller.get_accumulated_distance()), "a real safe-zone reset must clear pressure")


func _test_integration_contracts() -> void:
	var profile := ProfilesScript.get_profile(ProfilesScript.YUHENG_SEWER_PRESSURE_V1)
	var checks: Array = profile.get("pressure_checks", [])
	_expect(checks.size() == 3, "sewer profile must have three rising-pressure milestones")
	_expect(float((checks[0] as Dictionary).get("distance", 0.0)) == 1600.0, "sewer safe distance must be 1600 px")
	_expect(float((checks[2] as Dictionary).get("chance", 0.0)) == 0.85, "sewer maximum pressure must be 85 percent")
	_expect(float(profile.get("max_pressure_chance", 0.0)) < 1.0, "pressure profile must never use a 100 percent hard pity")

	var liuyu_source := FileAccess.get_file_as_string(LIUYU_SOURCE)
	_expect(liuyu_source.contains("global_position.distance_to(position_before_move)"), "LiuYu must contribute actual displacement, not requested velocity")
	_expect(liuyu_source.contains("_random_encounter.advance_distance(moved_distance, _encounter_rng)"), "LiuYu must delegate encounter state evaluation to the component")

	var root_source := FileAccess.get_file_as_string(GAME_ROOT_SOURCE)
	_expect(root_source.contains("_scene_contains_random_encounter_zone(new_scene)"), "scene changes must distinguish dangerous destinations from safe zones")
	_expect(root_source.contains("suspend_encounter_for_scene_change"), "dangerous scene changes must preserve same-region pressure")

	var secret_source := FileAccess.get_file_as_string(SECRET_ROOM_SOURCE)
	_expect(secret_source.contains('"encounter_profile_id": "yuheng_sewer_pressure_v1"'), "Secret Room must opt into pressure profile v1")
	_expect(secret_source.contains('{"w": 28, "enemies": ["yumei_sewer_rat", "yumei_sewer_rat"]}'), "Secret Room encounter weights must remain unchanged")


func _on_roll_evaluated(distance: float, chance: float, succeeded: bool) -> void:
	_rolls.append({"distance": distance, "chance": chance, "succeeded": succeeded})


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
