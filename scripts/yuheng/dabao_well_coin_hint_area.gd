extends Area2D

const QUEST_ID := "yh_side_dabao_01"
const FLAG_COIN_HINT := "yh_side_dabao_01_coin_hint"
const FLAG_COIN_TAKEN := "yh_side_dabao_01_coin_taken"

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
	if _busy:
		return
	if not _player_in_area:
		return
	if not _can_trigger():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		await _run_investigation_flow()

func _can_trigger() -> bool:
	if GlobalState == null:
		return false
	if not GlobalState.get_flag(FLAG_COIN_HINT):
		return false
	if GlobalState.get_flag(FLAG_COIN_TAKEN):
		return false
	return true

func _run_investigation_flow() -> void:
	_busy = true
	var liuyu = get_node_or_null("/root/GameRoot/LiuYu")
	if liuyu:
		liuyu.can_move = false
	var dialog_manager = get_node_or_null("/root/GameRoot/DialogManager")
	if dialog_manager:
		await dialog_manager.show_main_story_dialog("……這裡就是大寶用繩索指過的地方。", "res://assets/sprites/Liu_Yu/LiuYu_headshot.png", 2, null)
		await dialog_manager.show_main_story_dialog("劉語塵蹲下身，撥開井旁的草葉，搬起那塊不起眼的石頭。", "res://assets/sprites/Liu_Yu/LiuYu_headshot.png", 2, null)
		await dialog_manager.show_main_story_dialog("石下果然藏著一把冷冷的銅錢。", "", 1, null)
	if InventorySync:
		InventorySync.add_gold(50)
	if GlobalState and GlobalState.has_method("set_flag"):
		GlobalState.set_flag(FLAG_COIN_TAKEN, true)
	_complete_dabao_quest_note()
	if liuyu:
		liuyu.can_move = true
	_busy = false

func _complete_dabao_quest_note() -> void:
	var quest := SideQuestManager.get_quest(QUEST_ID)
	if not quest.has("quest_id"):
		return
	quest["description"] = "已完成：大寶的不能說"
	quest["objective"] = "大寶說不出口的井，終究還是用繩索與石頭說了出來。"
	quest["current_objective"] = quest["objective"]
	quest["notes"] = ["大寶說不出口的井，終究還是用繩索與石頭說了出來。那孩子看見的，或許不只是夢。"]
	quest["note"] = "大寶說不出口的井，終究還是用繩索與石頭說了出來。那孩子看見的，或許不只是夢。"
	SideQuestManager.side_quests[QUEST_ID] = quest
	SideQuestManager.complete_quest(QUEST_ID)
