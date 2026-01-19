extends Node

@onready var battle_controller = $BattleController

func _ready() -> void:
	await get_tree().process_frame
	_try_start_from_pending_context()

func _try_start_from_pending_context() -> void:
	if not GlobalState.has_meta("pending_battle_context"):
		return

	var context = GlobalState.get_meta("pending_battle_context")
	GlobalState.remove_meta("pending_battle_context")

	if typeof(context) != TYPE_DICTIONARY:
		push_warning("❗ pending_battle_context 不是 Dictionary，略過啟動戰鬥。")
		return
	if battle_controller == null:
		push_warning("❗ BattleScene 缺少 BattleController，無法啟動戰鬥。")
		return

	battle_controller.start_battle(context)
