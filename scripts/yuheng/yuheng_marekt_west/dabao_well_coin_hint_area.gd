extends Area2D

const QUEST_ID := "yh_side_dabao_01"
const FLAG_COIN_HINT := "yh_side_dabao_01_coin_hint"
const FLAG_COIN_TAKEN := "yh_side_dabao_01_coin_taken"

var _triggered := false

func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if body == null or body.name != "LiuYu":
		return
	if not _can_trigger():
		return
	_triggered = true
	await _play_coin_discovery_sequence()

func _can_trigger() -> bool:
	if GlobalState == null:
		return false
	if not GlobalState.get_flag(FLAG_COIN_HINT):
		return false
	if GlobalState.get_flag(FLAG_COIN_TAKEN):
		return false
	return true

func _play_coin_discovery_sequence() -> void:
	var dialog_manager = get_node_or_null("/root/GameRoot/DialogManager")
	if dialog_manager:
		await dialog_manager.show_main_story_dialog("……這裡就是大寶用繩索指過的地方。", "res://assets/sprites/Liu_Yu/LiuYu_headshot.png", 2, null)
		await dialog_manager.show_main_story_dialog("劉語塵蹲下身，撥開井旁草葉，搬起不起眼的石頭。", "res://assets/sprites/Liu_Yu/LiuYu_headshot.png", 2, null)
		await dialog_manager.show_main_story_dialog("石下果然藏著一把冷冷的銅錢。", "", 1, null)
	if InventorySync:
		InventorySync.add_gold(50)
	if GlobalState and GlobalState.has_method("set_flag"):
		GlobalState.set_flag(FLAG_COIN_TAKEN, true)
	var quest := SideQuestManager.get_quest(QUEST_ID)
	if quest.has("quest_id"):
		quest["description"] = "已完成：大寶的不能說"
		quest["objective"] = "大寶說不出口的井，終究還是用繩索與石頭說了出來。"
		quest["current_objective"] = quest["objective"]
		quest["notes"] = ["大寶說不出口的井，終究還是用繩索與石頭說了出來。那孩子看見的，或許不只是夢。"]
		quest["note"] = "大寶說不出口的井，終究還是用繩索與石頭說了出來。那孩子看見的，或許不只是夢。"
		SideQuestManager.side_quests[QUEST_ID] = quest
		SideQuestManager.complete_quest(QUEST_ID)
