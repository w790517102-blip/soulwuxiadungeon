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

const F_YH_SEWER_INTRO_DONE := "event_yuheng_sewer_final_room_intro_done"
const F_YH_SEWER_MUSIC_SOLVED := "sewer_music_solved"
const F_YH_SEWER_TALISMAN_SOLVED := "sewer_talisman_solved"
const F_YH_SEWER_ALCHEMY_SOLVED := "sewer_alchemy_solved"
const F_YH_SEWER_FINAL_SEAL_OPENED := "sewer_final_seal_opened"
const F_YH_SEWER_MUSIC_HINT_READ := "sewer_music_hint_read"
const F_YH_SEWER_TALISMAN_HINT_READ := "sewer_talisman_hint_read"
const F_YH_SEWER_ALCHEMY_RECIPE_READ := "sewer_alchemy_recipe_read"

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
			{
				"flag": "main_yh_manor_closed",
				"text": "飲月山莊突然閉莊，顧石卻仍守在門前。他守著的究竟是山門，還是一個連自己都不願相信的結果？",
			},
			{
				"flag": "event_baijianju_richman_done",
				"text": "外鄉人也只相信價碼、聽不進他人意願；琴聲是否讓執念壓過了其他聲音？",
			},
			{
				"flag": "event_huiyin_voice_done",
				"text": "書眠把未說完的話收了回去，琴聲卻在夜裡喚我前去。她們像在迴避同一件事，也像都在等我把它問清楚。",
			},
			{
				"flag": "main_yh_got_half_string_copper_button",
				"text": "紅徽音將半弦銅釦交給了我。若那口廢井真能以它開啟，玉衡鎮被壓住的另一半聲音，或許就藏在井下。",
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

func refresh_main_quest_notes() -> void:
	var quest_id := String(main_quest.get("id", "main_001"))
	main_quest["notes"] = _build_main_quest_notes(quest_id)

func refresh_sewer_puzzle_note() -> void:
	# 下水道 Note 仍由同一套主線 notes_rules／display builder 保存與顯示；
	# 此入口只負責在機關旗標改變後立即重建目前的正式 Note 快照。
	refresh_main_quest_notes()

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
		if rule.has("stage") and get_main_stage() != int(rule.get("stage", -1)):
			continue
		var unless_flag := String(rule.get("unless_flag", ""))
		if unless_flag != "" and GlobalState and GlobalState.has_method("get_flag") and bool(GlobalState.get_flag(unless_flag)):
			continue
		if GlobalState and GlobalState.has_method("get_flag") and bool(GlobalState.get_flag(flag_name)):
			notes.append(String(rule.get("text", "")))
	var sewer_note := _resolve_sewer_puzzle_note(quest_id)
	if sewer_note != "":
		notes.append(sewer_note)
	return notes

func _resolve_sewer_puzzle_note(quest_id: String) -> String:
	if quest_id != "main_001" or get_main_stage() != STAGE_YH_SEWER_MECHANISMS:
		return ""
	if not _quest_flag_is_true(F_YH_SEWER_INTRO_DONE):
		return ""

	var music_done: bool = _quest_flag_is_true(F_YH_SEWER_MUSIC_SOLVED)
	var talisman_done: bool = _quest_flag_is_true(F_YH_SEWER_TALISMAN_SOLVED)
	var alchemy_done: bool = _quest_flag_is_true(F_YH_SEWER_ALCHEMY_SOLVED)
	var final_seal_opened: bool = _quest_flag_is_true(F_YH_SEWER_FINAL_SEAL_OPENED)

	if final_seal_opened:
		return "封印已解。前往門後查探。"
	if music_done and talisman_done and alchemy_done:
		return "三處機關皆已解。回終端房查看封印。"

	# 房間詳細 Note 的優先權高於總體剩餘機關 Note。
	if not alchemy_done:
		var alchemy_state: Dictionary = GlobalState.get_alchemy_puzzle_state() \
			if GlobalState and GlobalState.has_method("get_alchemy_puzzle_state") else {}
		var alchemy_phase := String(alchemy_state.get("phase", ""))
		var confirmed := bool(alchemy_state.get("herbs_confirmed", false))
		var methods_value = alchemy_state.get("processing_methods", [])
		var method_count := (methods_value as Array).size() if methods_value is Array else 0
		if alchemy_phase == "retry_needed":
			return "依殘方重新挑選三味藥材。"
		if confirmed:
			if method_count == 0:
				return "將選好的三味藥材帶到調香台。"
			if method_count == 1:
				return "第一味藥材已處理。繼續處理其餘兩味。"
			if method_count == 2:
				return "尚餘最後一味藥材需要處理。"
			return "三味藥材皆已處理。確認配方後點燃藥香。"
		if _quest_flag_is_true(F_YH_SEWER_ALCHEMY_RECIPE_READ):
			return "依殘方從藥櫃挑出三味藥材。"
	if not talisman_done and _quest_flag_is_true(F_YH_SEWER_TALISMAN_HINT_READ):
		return "找齊圖樣，依「心」、「語」、「水」的順序重新貼符。"
	if not music_done and _quest_flag_is_true(F_YH_SEWER_MUSIC_HINT_READ):
		return "依「宮、角、羽」的順序踏過調音室石板。"

	var solved_count := int(music_done) + int(talisman_done) + int(alchemy_done)
	if solved_count == 0:
		return "出口受符陣封鎖。尋找琴、符、藥三處機關。"
	if solved_count == 1:
		if music_done:
			return "琴音機關已解。尚餘符、藥兩處機關。"
		if talisman_done:
			return "符咒機關已解。尚餘琴、藥兩處機關。"
		return "調香機關已解。尚餘琴、符兩處機關。"
	if not music_done:
		return "尚餘琴音機關未解。"
	if not talisman_done:
		return "尚餘符咒機關未解。"
	return "尚餘調香機關未解。"

func _quest_flag_is_true(flag_name: String) -> bool:
	return GlobalState != null \
		and GlobalState.has_method("get_flag") \
		and bool(GlobalState.get_flag(flag_name))
