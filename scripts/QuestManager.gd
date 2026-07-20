extends Node
class_name QuestManagerInstance

const STAGE_YH_INVESTIGATE := 1
const STAGE_YH_GO_TO_MANOR := 2
const STAGE_YH_MANOR_GATE := 3
const STAGE_YH_BAIJIANJU_OPEN := 4
const STAGE_YH_YINPINGYU_DONE := 5
const STAGE_YH_GO_TO_ZUIYUE := 6
const STAGE_YH_SEWER_STARTED := 7
const STAGE_YH_SEWER_MECHANISMS := 8
const STAGE_YH_STALACTITE_CAVE := 9
const STAGE_YH_NIGHT_MEETING := 10
const STAGE_YH_LIEFENG_STARTED := 11

const MAIN_QUEST_DEFS := {
	"main_001": {
		"chapter_title": "靜默的琴聲",
		"description": "尋找飲月山莊的左飲",
		"objectives_by_stage": {
			STAGE_YH_INVESTIGATE: "在玉衡鎮打聽左飲的消息",
			STAGE_YH_GO_TO_MANOR: "想辦法說服飲月山莊的門衛",
			STAGE_YH_MANOR_GATE: "與飲月山莊門衛顧石周旋，證明求見左飲的誠意。",
			STAGE_YH_BAIJIANJU_OPEN: "飲月山莊暫時閉門，回玉衡鎮尋找其他線索。",
			STAGE_YH_YINPINGYU_DONE: "《銀屏語》事件已了，等待夜晚琴音指向下一步。",
			STAGE_YH_GO_TO_ZUIYUE: "前往醉月茶坊，尋找紅徽音。",
			STAGE_YH_SEWER_STARTED: "依紅徽音線索前往舊井，探查玉衡鎮舊水道。",
			STAGE_YH_SEWER_MECHANISMS: "破解舊水道三處機關，前往終端房解除封印。",
			STAGE_YH_STALACTITE_CAVE: "穿過終端房，進入鐘乳石洞查明魚怪異變。",
			STAGE_YH_NIGHT_MEETING: "回到飲月山莊夜會，整理舊水道與魚怪線索。",
			STAGE_YH_LIEFENG_STARTED: "準備前往清風竹林，追查烈風寨章的開端。",
		},
		"notes_rules": [
			{
				"flag": "met_yuheng_inn_boss",
				"text": "從旅館老闆口中得知，左飲似乎不是那麼容易見到面的。",
			},
			{
				"flag": "triggered_zuoyin_gossip_summary",
				"text": "左飲是位古道熱腸的俠士，但如今卻怎麼不常現身呢？",
			},
			{
				"flag": "event_market_choice_observe",
				"text": "這小鎮竟然被一個奇妙的琴音壟罩著！但左飲為何沒有採取行動呢？",
			},
			{
				"flag": "event_tea_house_first_met",
				"text": "這位姑娘想必就是鎮上的用琴高手，但為何她從不開口說話？",
			},
			{
				"flag": "met_Su_Mien",
				"text": "書眠姑娘也是琴音壓情的受害者，但為什麼她會如此自責呢？",
			},
		],
	},
}

var main_quest := {
	"id": "main_001",
	"chapter_title": "靜默的琴聲",
	"stage": 1,
	"description": "尋找飲月山莊的左飲",
	"current_objective": "在玉衡鎮打聽左飲的消息",
	"notes": [],
}

func get_main_quest_state() -> Dictionary:
	return main_quest

func get_main_stage() -> int:
	return int(main_quest.get("stage", STAGE_YH_INVESTIGATE))

func has_reached_main_stage(stage_value: int) -> bool:
	return get_main_stage() >= stage_value

func get_main_quest_display() -> Dictionary:
	var out := main_quest.duplicate(true)
	var quest_id := String(out.get("id", "main_001"))
	var stage := int(out.get("stage", 1))
	var def: Dictionary = MAIN_QUEST_DEFS.get(quest_id, {})
	if not def.is_empty():
		out["chapter_title"] = String(def.get("chapter_title", out.get("chapter_title", quest_id)))
		out["description"] = String(def.get("description", out.get("description", "")))
		var objective_map: Dictionary = def.get("objectives_by_stage", {})
		var objective_override := String(out.get("objective_override", "")).strip_edges()
		out["current_objective"] = objective_override if objective_override != "" else String(objective_map.get(stage, out.get("current_objective", out.get("description", ""))))
		out["notes"] = _build_main_quest_notes(quest_id)
		if not out.has("title") or String(out.get("title", "")).strip_edges() == "":
			out["title"] = out.get("chapter_title", quest_id)
	return out

func load_main_quest(data: Dictionary) -> void:
	main_quest = data.duplicate(true)
	var display_data := get_main_quest_display()
	main_quest["chapter_title"] = String(display_data.get("chapter_title", main_quest.get("chapter_title", "")))
	main_quest["description"] = String(display_data.get("description", main_quest.get("description", "")))
	main_quest["current_objective"] = String(display_data.get("current_objective", main_quest.get("current_objective", "")))
	main_quest["notes"] = display_data.get("notes", [])
	print("[任務] 主線載入成功:", main_quest)

func reset_main_quest() -> void:
	main_quest = {
		"id": "main_001",
		"stage": 1,
	}
	var display_data := get_main_quest_display()
	main_quest["chapter_title"] = String(display_data.get("chapter_title", "靜默的琴聲"))
	main_quest["description"] = String(display_data.get("description", "尋找飲月山莊的左飲"))
	main_quest["current_objective"] = String(display_data.get("current_objective", "在玉衡鎮打聽左飲的消息"))
	main_quest["notes"] = display_data.get("notes", [])


# ✅ 新增主線進度推進方法
func advance_main_quest(new_stage: int, new_objective: String = "") -> void:
	if GlobalState and GlobalState.get("is_loading") == true:
		return
	main_quest["stage"] = new_stage
	var objective_override := String(new_objective).strip_edges()
	if objective_override != "":
		main_quest["objective_override"] = objective_override
	else:
		main_quest.erase("objective_override")
	var display_data := get_main_quest_display()
	main_quest["chapter_title"] = String(display_data.get("chapter_title", main_quest.get("chapter_title", "")))
	main_quest["description"] = String(display_data.get("description", main_quest.get("description", "")))
	main_quest["current_objective"] = String(display_data.get("current_objective", main_quest.get("description", "")))
	main_quest["notes"] = display_data.get("notes", [])
	print("[任務] 主線已更新：第%d階段｜%s" % [new_stage, String(main_quest.get("current_objective", ""))])

func set_main_objective(text: String) -> void:
	if GlobalState and GlobalState.get("is_loading") == true:
		return
	var objective := String(text).strip_edges()
	if objective == "":
		return
	var display_data := get_main_quest_display()
	main_quest["chapter_title"] = String(display_data.get("chapter_title", main_quest.get("chapter_title", "")))
	main_quest["description"] = String(display_data.get("description", main_quest.get("description", "")))
	main_quest["objective_override"] = objective
	main_quest["current_objective"] = objective
	main_quest["notes"] = display_data.get("notes", [])
	print("[任務] 主線目標已更新：%s" % objective)

func _build_main_quest_notes(quest_id: String) -> Array:
	var notes: Array = []
	var def: Dictionary = MAIN_QUEST_DEFS.get(quest_id, {})
	if def.is_empty():
		return notes
	var rules: Array = def.get("notes_rules", [])
	for rule_any in rules:
		if typeof(rule_any) != TYPE_DICTIONARY:
			continue
		var rule: Dictionary = rule_any
		var flag_name := String(rule.get("flag", ""))
		if flag_name == "":
			continue
		if GlobalState and GlobalState.has_method("get_flag") and bool(GlobalState.get_flag(flag_name)):
			notes.append(String(rule.get("text", "")))
	return notes
