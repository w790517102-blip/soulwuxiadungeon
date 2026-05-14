extends Area2D

@export var pickup_flag_id: String = "yuheng_square_valley_shadow_01"
@export var item_id: String = "quest_valley_shadow_grass"
@export var quest_id: String = "yuheng_valley_herb"

var _player_in_area := false
var _busy := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_process_unhandled_input(true)

func _on_body_entered(body: Node2D) -> void:
	if body and body.name == "LiuYu":
		_player_in_area = true

func _on_body_exited(body: Node2D) -> void:
	if body and body.name == "LiuYu":
		_player_in_area = false

func _unhandled_input(event: InputEvent) -> void:
	if _busy or not _player_in_area:
		return
	if not _can_pick():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		await _pickup_flow()

func _can_pick() -> bool:
	if GlobalState == null:
		return false
	if pickup_flag_id == "":
		return false
	if GlobalState.get_flag(pickup_flag_id):
		return false
	return true

func _pickup_flow() -> void:
	_busy = true
	var liuyu = get_node_or_null("/root/GameRoot/LiuYu")
	if liuyu:
		liuyu.can_move = false
	var dialog_manager = get_node_or_null("/root/GameRoot/DialogManager")
	if dialog_manager:
		await dialog_manager.show_main_story_dialog("這株草葉背陰、莖細而韌，正是谷影草。", "res://assets/sprites/Liu_Yu/LiuYu_headshot.png", 2, null)
	if InventorySync:
		InventorySync.add_item_stack(item_id, 1, true)
	if GlobalState and GlobalState.has_method("set_flag"):
		GlobalState.set_flag(pickup_flag_id, true)
	_try_advance_quest_stage()
	if liuyu:
		liuyu.can_move = true
	_busy = false

func _try_advance_quest_stage() -> void:
	if SideQuestManager == null:
		return
	var quest := SideQuestManager.get_quest(quest_id)
	if not quest.has("quest_id"):
		return
	if bool(quest.get("is_finished", false)):
		return
	if InventorySync and InventorySync.has_item(item_id, 3):
		quest["stage"] = 2
		quest["objective"] = "將三朵谷影草交給賣藥翁。"
		quest["current_objective"] = quest["objective"]
		quest["notes"] = ["已採滿三朵谷影草，回去交給賣藥翁。"]
		quest["note"] = "已採滿三朵谷影草，回去交給賣藥翁。"
		SideQuestManager.side_quests[quest_id] = quest
		if SideQuestManager.has_method("notify_objective_updated"):
			SideQuestManager.notify_objective_updated(quest_id)
