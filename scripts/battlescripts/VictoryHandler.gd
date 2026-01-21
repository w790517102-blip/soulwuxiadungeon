extends Node

var _returning := false

func _ready() -> void:
	print("[VictoryHandler] ready")

func victory() -> void:
	print("[VictoryHandler] victory called")
	_request_return_to_map("victory")

func defeat() -> void:
	print("[VictoryHandler] defeat called")
	_request_return_to_map("defeat")

func _request_return_to_map(result: String) -> void:
	if _returning:
		return
	_returning = true

	var return_path := str(GlobalState.get_meta("return_map_path", ""))

	if return_path == "":
		push_warning("❗ return_map_path 缺失")
		_returning = false
		return

	var game_root = get_node_or_null("/root/GameRoot")
	if game_root == null:
		push_warning("❗ 無法回到地圖：找不到 GameRoot。")
		_returning = false
		return

	GlobalState.set_meta("pending_battle_return", true)
	GlobalState.set_meta("pending_battle_result", result)
	game_root.change_map_to(return_path)
