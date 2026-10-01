extends SceneTree

const GameRootScript = preload("res://scripts/game_root.gd")
const GAME_ROOT_SOURCE := "res://scripts/game_root.gd"
const GRANDMA_SCENE := "res://scenes/yuheng/Bamboo_Grove_Suburb/Bamboo_Grove_Suburb.tscn"
const OUTSKIRTS_SOURCE := "res://scripts/yuheng/yuheng_bamboo_outskirts/yuheng_bamboo_outskirts.gd"
const GUSHI_SOURCE := "res://scripts/yuheng/YinYueManor/gu_shi.gd"

var _failures: Array[String] = []


func _initialize() -> void:
	_test_exit_requires_leave_contract()
	_test_normal_scene_change_uses_entry_guard()
	_test_gushi_to_grandma_return_contract()
	if _failures.is_empty():
		print("PASS: normal map entry guard regression tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: %s" % failure)
		quit(1)


func _test_exit_requires_leave_contract() -> void:
	var game_root := GameRootScript.new()
	var player := Node2D.new()
	player.name = "LiuYu"
	var map_exit := Area2D.new()
	map_exit.name = "to_previous_map"

	game_root.call("_guard_map_exit_until_player_leaves", map_exit, player)
	_expect(map_exit.has_meta("map_transition_requires_exit"), "spawn-overlapped exit must be disarmed")
	_expect(not game_root.can_use_map_transition(player, map_exit), "disarmed exit must reject immediate reverse transition")

	map_exit.body_exited.emit(player)
	_expect(not map_exit.has_meta("map_transition_requires_exit"), "leaving the exit must rearm it")
	_expect(game_root.can_use_map_transition(player, map_exit), "rearmed exit must permit a later intentional transition")

	map_exit.free()
	player.free()
	game_root.free()


func _test_normal_scene_change_uses_entry_guard() -> void:
	var source := FileAccess.get_file_as_string(GAME_ROOT_SOURCE)
	var function_start := source.find("func change_map_to(path: String):")
	var function_end := source.find("\nfunc play_music_by_tag", function_start)
	_expect(function_start >= 0 and function_end > function_start, "change_map_to source must be available")
	if function_start < 0 or function_end <= function_start:
		return
	var body := source.substr(function_start, function_end - function_start)
	_expect(body.contains("lock_map_transitions(\"scene_change\")"), "normal scene changes must lock destination exits during placement")
	_expect(body.contains("await get_tree().physics_frame"), "normal scene changes must wait for Area2D overlap state")
	_expect(body.contains("disarm_overlapping_map_exits($LiuYu)"), "normal scene changes must disarm spawn-overlapped exits")
	_expect(body.contains("if not inherited_transition_lock:\n\t\tunlock_map_transitions(\"scene_change\")"), "scene change must release only the lock it acquired")


func _test_gushi_to_grandma_return_contract() -> void:
	var packed := load(GRANDMA_SCENE) as PackedScene
	_expect(packed != null, "Grandma scene must remain loadable")
	if packed != null:
		var scene := packed.instantiate()
		_expect(scene.has_node("SpawnPoints/from_yuheng_bamboo_outskirts"), "Gu Shi return route must have its destination spawn")
		_expect(scene.has_node("to_yuheng_bamboo_jungle"), "Grandma scene must retain the paired map exit guarded by GameRoot")
		scene.free()

	var outskirts_source := FileAccess.get_file_as_string(OUTSKIRTS_SOURCE)
	_expect(outskirts_source.contains("spawn_point_name = \"from_yuheng_bamboo_outskirts\""), "outskirts must select the Grandma return spawn")
	_expect(outskirts_source.contains("change_map_to(Bamboo_Grove_Suburb)"), "outskirts must return through the shared scene transition")

	var gushi_source := FileAccess.get_file_as_string(GUSHI_SOURCE)
	var reset_start := gushi_source.find("func reset_dialog_state():")
	var reset_end := gushi_source.find("\nfunc ", reset_start + 1)
	_expect(reset_start >= 0 and reset_end > reset_start, "Gu Shi dialogue cleanup must remain available")
	if reset_start >= 0 and reset_end > reset_start:
		var reset_body := gushi_source.substr(reset_start, reset_end - reset_start)
		_expect(reset_body.contains("can_move = true"), "Gu Shi dialogue cleanup must return its own movement lock")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
