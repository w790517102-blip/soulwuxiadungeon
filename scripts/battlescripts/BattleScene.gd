extends Node

enum BattlePresentationMode { LEGACY, STAGE_25D, CARD_STAGE }
## Default view for normal story battles. STAGE_25D stays fully available via
## `-- --stage-25d` or a battle context `presentation_mode = 1`.
@export var presentation_mode: BattlePresentationMode = BattlePresentationMode.CARD_STAGE

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
	if "--stage-25d" in OS.get_cmdline_user_args():
		selected = BattlePresentationMode.STAGE_25D
	if "--card-stage" in OS.get_cmdline_user_args():
		selected = BattlePresentationMode.CARD_STAGE
	if selected == BattlePresentationMode.STAGE_25D or selected == BattlePresentationMode.CARD_STAGE:
		var ui_script := "res://scripts/presentation/CardStageBattleUI.gd" if selected == BattlePresentationMode.CARD_STAGE else "res://scripts/presentation/StageBattleUI.gd"
		get_node("BattleUILayer/BattleUI/LogPanel").set_script(load("res://scripts/presentation/StageLogPanel.gd"))
		_replace_view_script(get_node("BattleUILayer/BattleUI"), load(ui_script), ["tone"])
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

var _presentation_badge: Label
var _presentation_badge_tween: Tween
var _shown_presentation: String = ""

func _ready() -> void:
	await get_tree().process_frame
	_shown_presentation = active_presentation_name()
	print("Battle Presentation: %s" % _shown_presentation)
	if OS.is_debug_build():
		_build_presentation_badge()
		_show_presentation_badge(_shown_presentation)
	else:
		set_process(false)
	_try_start_from_pending_context()

# Reports the view that is really active (not just the requested one), so a wrong
# build can be spotted at a glance. F8 to the text view reads as LEGACY.
func active_presentation_name() -> String:
	var ui: Node = get_node_or_null("BattleUILayer/BattleUI")
	if ui == null or ui.get_script() == null:
		return "LEGACY"
	var script_path: String = ui.get_script().resource_path
	if script_path.ends_with("/CardStageBattleUI.gd"):
		return "CARD_STAGE" if bool(ui.get("stage_enabled")) else "LEGACY (F8)"
	if script_path.ends_with("/StageBattleUI.gd"):
		return "STAGE_25D" if bool(ui.get("stage_enabled")) else "LEGACY (F8)"
	return "LEGACY"

func _process(_delta: float) -> void:
	if _presentation_badge == null:
		return
	var current := active_presentation_name()
	if current != _shown_presentation:
		_shown_presentation = current
		print("Battle Presentation: %s" % current)
		_show_presentation_badge(current)

func _build_presentation_badge() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PresentationBadgeLayer"
	layer.layer = 200
	add_child(layer)
	_presentation_badge = Label.new()
	_presentation_badge.name = "PresentationBadge"
	_presentation_badge.position = Vector2(12, 8)
	_presentation_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_presentation_badge.add_theme_font_size_override("font_size", 18)
	_presentation_badge.add_theme_color_override("font_color", Color("fff0a0"))
	_presentation_badge.add_theme_color_override("font_outline_color", Color.BLACK)
	_presentation_badge.add_theme_constant_override("outline_size", 6)
	layer.add_child(_presentation_badge)

func _show_presentation_badge(text: String) -> void:
	_presentation_badge.text = "Battle Presentation: %s" % text
	_presentation_badge.modulate.a = 1.0
	if _presentation_badge_tween and _presentation_badge_tween.is_valid():
		_presentation_badge_tween.kill()
	_presentation_badge_tween = create_tween()
	_presentation_badge_tween.tween_interval(4.0)
	_presentation_badge_tween.tween_property(_presentation_badge, "modulate:a", 0.0, 0.8)

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
