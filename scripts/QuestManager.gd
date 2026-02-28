extends Node
class_name QuestManagerInstance

var main_quest := {
	"id": "main_001",
	"stage": 1,
	"description": "打聽左飲的消息"
}

func get_main_quest_state() -> Dictionary:
	return main_quest

func load_main_quest(data: Dictionary) -> void:
	main_quest = data
	print("[任務] 主線載入成功:", main_quest)

# ✅ 新增主線進度推進方法
func advance_main_quest(new_stage: int, new_description: String) -> void:
	if GlobalState and GlobalState.get("is_loading") == true:
		return
	main_quest["stage"] = new_stage
	main_quest["description"] = new_description
	print("[任務] 主線已更新：第%d階段｜%s" % [new_stage, new_description])
