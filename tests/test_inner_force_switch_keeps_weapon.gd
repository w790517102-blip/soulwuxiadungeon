extends SceneTree

# 戰鬥中切換內功後，我方角色的武器要維持「身上實際裝備」：沒裝武器就不能出現劍招。
# （以前切換內功會從角色資料把預設武器「劍」抄回來，沒裝劍也看得到劍招。）
# 執行：godot --headless --path . --script tests/test_inner_force_switch_keeps_weapon.gd

var _failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL ", what)

func _run() -> void:
	await process_frame
	var src := FileAccess.get_file_as_string("res://scripts/battlescripts/BattleController.gd")
	var start := src.find("func _refresh_battle_actor_from_team_data")
	var end := src.find("func _copy_long_term_actor_fields", start)
	var body := src.substr(start, end - start)
	var copy_at := body.find("_copy_long_term_actor_fields(actor, source)")
	var sync_at := body.find("_sync_one_actor_weapon_types(actor)")
	_check(copy_at >= 0 and sync_at > copy_at, "the equipped weapon types are re-synced right after the long-term fields are copied")
	var reset_at := body.find("actor[\"crit_rate_bonus\"] = float(source.get(\"crit_rate_bonus\", 0.0))")
	_check(reset_at >= 0 and reset_at < copy_at, "crit_rate_bonus is reset before the equipment bonus is applied again (otherwise it stacks on every inner-force switch)")
	print("PASS test_inner_force_switch_keeps_weapon" if _failures == 0 else "FAILED test_inner_force_switch_keeps_weapon: %d" % _failures)
	quit(1 if _failures > 0 else 0)
