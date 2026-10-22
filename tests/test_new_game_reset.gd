extends SceneTree

# 新遊戲起始狀態：拍快照後弄髒旗標、背包、隊伍，還原後要回到快照時的樣子；沒快照時不動任何東西。
# 只動記憶體，不碰存檔檔案。執行：godot --headless --path . --script tests/test_new_game_reset.gd

var _failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL ", what)

func _run() -> void:
	await process_frame
	var sm = root.get_node("SaveManager")
	var gs = root.get_node("GlobalState")
	var team = root.get_node("TeamData")
	var inv = root.get_node("InventorySync")
	_check(sm.reset_to_new_game_state() == false or sm.has_new_game_snapshot(), "without a snapshot the reset reports false")
	sm._new_game_snapshot = {}
	_check(not sm.reset_to_new_game_state(), "no snapshot: the reset does nothing")
	sm.capture_new_game_snapshot()
	_check(sm.has_new_game_snapshot(), "the snapshot is captured")
	var flags_before: int = gs.flags.size()
	var gold_before: int = inv.get_gold()
	var hp_before: int = int(team.all_characters["liuyu"]["hp"])
	var level_before: int = int(team.all_characters["liuyu"]["level"])
	# 弄髒
	gs.flags["_dirty_flag"] = true
	gs.triggered_flags["_dirty_trigger"] = true
	gs.ethics = 7
	inv.add_gold(500, false)
	team.all_characters["liuyu"]["hp"] = 1
	team.all_characters["liuyu"]["level"] = 9
	team.unlock_roster("shumian")
	_check(gs.flags.has("_dirty_flag") and inv.get_gold() == gold_before + 500, "state is dirty before the reset")
	_check(sm.reset_to_new_game_state(), "the reset runs when a snapshot exists")
	_check(not gs.flags.has("_dirty_flag") and not gs.triggered_flags.has("_dirty_trigger"), "flags are back to the snapshot")
	_check(gs.flags.size() == flags_before and gs.ethics == 0, "flag count and ethics restored")
	_check(inv.get_gold() == gold_before, "gold restored")
	_check(int(team.all_characters["liuyu"]["hp"]) == hp_before and int(team.all_characters["liuyu"]["level"]) == level_before, "team stats restored")
	print("PASS test_new_game_reset" if _failures == 0 else "FAILED test_new_game_reset: %d" % _failures)
	quit(1 if _failures > 0 else 0)
