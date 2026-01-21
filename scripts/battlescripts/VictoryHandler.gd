extends Node

var _returning := false

func _ready() -> void:
	print("[VictoryHandler] ready")

func victory() -> void:
	print("[VictoryHandler] victory called")
	await _return_to_map("victory")

func defeat() -> void:
	print("[VictoryHandler] defeat called")
	await _return_to_map("defeat")

func _return_to_map(result: String) -> void:
	if _returning:
		return
	_returning = true

	var return_path := str(GlobalState.get_meta("return_map_path", ""))
	var return_pos: Vector2 = GlobalState.get_meta("return_player_pos", Vector2.ZERO)
	var cooldown_distance := float(GlobalState.get_meta("return_encounter_cooldown", 0.0))

	if return_path == "":
		push_warning("❗ 無法回到地圖：return_map_path 缺失。")
		_returning = false
		return

	var game_root = get_node_or_null("/root/GameRoot")
	if game_root == null:
		push_warning("❗ 無法回到地圖：找不到 GameRoot。")
		_returning = false
		return
	print("[VictoryReturn] change_map_to=", return_path, " pos=", return_pos, " cooldown=", cooldown_distance)

	await game_root.change_map_to(return_path)
	await get_tree().process_frame
	await get_tree().process_frame

	var liuyu = game_root.get_node_or_null("LiuYu")
	if liuyu:
		liuyu.global_position = return_pos
		if liuyu.has_method("battle_restore"):
			liuyu.battle_restore()
		else:
			push_warning("❗ LiuYu 缺少 battle_restore()，無法恢復控制/顯示。")
		if liuyu.has_method("set_encounter_cooldown"):
			liuyu.set_encounter_cooldown(cooldown_distance)
		print("[VictoryReturn] liuyu=", liuyu, " visible=", liuyu.visible, " can_move=", liuyu.get("can_move"))
	else:
		push_warning("❗ 無法回到地圖：找不到 LiuYu。")
		_returning = false
		return

	if GlobalState.has_meta("return_map_path"):
		GlobalState.remove_meta("return_map_path")
	if GlobalState.has_meta("return_player_pos"):
		GlobalState.remove_meta("return_player_pos")
	if GlobalState.has_meta("return_encounter_cooldown"):
		GlobalState.remove_meta("return_encounter_cooldown")

	print("✅ 戰鬥結束（%s），已回到地圖。" % result)
	_returning = false
