extends Node

enum BattlePresentationMode { LEGACY, STAGE_25D }
@export var presentation_mode: BattlePresentationMode = BattlePresentationMode.STAGE_25D

@onready var battle_controller = $BattleController

func _enter_tree() -> void:
	# Select the view before child _ready; both modes use the same combat rules.
	# No existing scene or legacy UI script is replaced on disk.
	var selected: int = presentation_mode
	if GlobalState.has_meta("pending_battle_context"):
		var context: Variant = GlobalState.get_meta("pending_battle_context")
		if context is Dictionary:
			selected = int(context.get("presentation_mode", selected))
	if "--legacy-battle" in OS.get_cmdline_user_args():
		selected = BattlePresentationMode.LEGACY
	if selected == BattlePresentationMode.STAGE_25D:
		get_node("BattleUILayer/BattleUI/LogPanel").set_script(load("res://scripts/presentation/StageLogPanel.gd"))
		_replace_view_script(get_node("BattleUILayer/BattleUI"), load("res://scripts/presentation/StageBattleUI.gd"), ["tone"])
		if not has_meta("presentation_preview_controller"):
			_replace_view_script(get_node("BattleController"), load("res://scripts/presentation/StageBattleController.gd"), ["tone_map", "status_manager"])

static func _replace_view_script(node: Node, view_script: Script, owned_helpers: Array[String]) -> void:
	# PackedScene has already initialized the old script. Its unattached Node
	# helpers are not RefCounted; release them before replacing their owner.
	for field in owned_helpers:
		var helper: Variant = node.get(field)
		if helper is Node and is_instance_valid(helper) and helper.get_parent() == null:
			helper.free()
	node.set_script(view_script)

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
