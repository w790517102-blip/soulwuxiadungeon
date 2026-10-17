extends SceneTree

# 玉衡鎮序章收尾的狀態規則（YuhengPrologueState）：
#   白書眠是否入隊、《渠燈補封》支線進度、是否啟程烈風寨，是三件互相獨立的事。
# 執行：godot --headless --path . --script tests/test_prologue_ending_state.gd

var _failures := 0
var _state: GDScript


func _initialize() -> void:
	# 自動載入的單例在下一個 frame 才在 root 底下
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_state = load("res://scripts/yuheng/YinYueManor/YuhengPrologueState.gd")
	_expect(_state != null, "YuhengPrologueState must load")
	if _state == null:
		quit(1)
		return

	_reset()
	_test_before_night_meeting()
	_reset()
	_test_available_then_accept()
	_reset()
	_test_accept_then_complete_then_depart()
	_reset()
	_test_depart_without_accepting()
	_reset()
	_test_depart_in_progress()
	_reset()
	_test_party_independent_of_quest()
	_reset()
	_test_join_level()
	_reset()

	if _failures == 0:
		print("PASS test_prologue_ending_state")
		quit(0)
	else:
		print("FAIL test_prologue_ending_state failures=%d" % _failures)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + message)


func _gs() -> Node:
	return root.get_node("GlobalState")


func _team() -> Node:
	return root.get_node("TeamData")


func _quests() -> Node:
	return root.get_node("SideQuestManager")


func _reset() -> void:
	_gs().flags.clear()
	_gs().triggered_flags.clear()
	_team().reset_to_initial_team_state()
	_quests().reset_all()


func _night_meeting_done() -> void:
	_gs().set_flag(_state.F_NIGHT_MEETING_DONE, true)
	_gs().set_flag(_state.F_SHUMIAN_SIDE_AVAILABLE, true)


func _shumian_slots() -> int:
	var count := 0
	for id in _team().current_team_ids:
		if String(id) == "shumian":
			count += 1
	return count


func _test_before_night_meeting() -> void:
	_expect(_state.get_side_quest_state() == _state.SideQuestState.UNAVAILABLE, "before the night meeting the side quest is unavailable")
	_expect(not _state.is_prologue_ending_phase(), "before the night meeting is not the ending phase")
	_expect(_state.can_enter_clean_sewer(), "the clean sewer keeps its old behaviour before the night meeting")
	_expect(not _state.is_shumian_joined(), "Shumian is not in the party at the start")


func _test_available_then_accept() -> void:
	_night_meeting_done()
	_expect(_state.is_prologue_ending_phase(), "after the night meeting and before departure is the ending phase")
	_expect(_state.get_side_quest_state() == _state.SideQuestState.AVAILABLE, "side quest available after the night meeting")
	_expect(not _state.can_enter_clean_sewer(), "cannot enter the clean sewer before accepting")
	_expect(not _state.is_shumian_joined(), "available does not mean joined")

	_state.accept_qudeng()
	_expect(_state.get_side_quest_state() == _state.SideQuestState.IN_PROGRESS, "accepted -> in progress")
	_expect(_state.is_shumian_joined(), "accepting makes Shumian join")
	_expect(_team().is_roster_unlocked("shumian"), "TeamData roster unlocks Shumian")
	_expect(_shumian_slots() == 1, "Shumian occupies exactly one party slot")
	_expect(_quests().get_quest(_state.QUDENG_QUEST_ID).has("quest_id"), "the side quest is registered in SideQuestManager")
	_expect(not _quests().is_quest_finished(_state.QUDENG_QUEST_ID), "accepting does not finish the quest")
	_expect(_state.can_enter_clean_sewer(), "can enter the clean sewer after accepting")

	# 重複接取：不重複入隊、不重複註冊、不改變狀態
	_quests().advance_quest(_state.QUDENG_QUEST_ID, 2)
	_state.accept_qudeng()
	_expect(_shumian_slots() == 1, "accepting twice does not add a second party slot")
	_expect(int(_quests().get_quest(_state.QUDENG_QUEST_ID).get("stage", 0)) == 2, "accepting twice does not reset the quest stage")
	_expect(_state.get_side_quest_state() == _state.SideQuestState.IN_PROGRESS, "still in progress")


func _test_accept_then_complete_then_depart() -> void:
	_night_meeting_done()
	_state.accept_qudeng()
	_gs().set_flag(_state.F_QD_DONE, true)
	_state.on_qudeng_completed()
	_expect(_state.get_side_quest_state() == _state.SideQuestState.DONE, "completed -> done")
	_expect(_quests().is_quest_finished(_state.QUDENG_QUEST_ID), "the quest log marks it finished")
	_expect(_state.is_shumian_joined(), "completing keeps Shumian in the party")
	_expect(not _state.flag(_state.F_LIEFENG_CHAPTER_STARTED), "completing does not start the next chapter")
	_expect(_state.is_prologue_ending_phase(), "still free roaming after completing")

	var marked: bool = _state.settle_side_quest_for_departure()
	_expect(not marked, "a completed side quest is not marked missed when departing")
	_expect(_state.get_side_quest_state() == _state.SideQuestState.DONE, "completed stays completed")
	_expect(not _quests().is_quest_missed(_state.QUDENG_QUEST_ID), "the quest log does not mark a completed quest missed")
	_state.join_shumian()
	_expect(_shumian_slots() == 1, "joining again never duplicates the party slot")


func _test_depart_without_accepting() -> void:
	_night_meeting_done()
	var marked: bool = _state.settle_side_quest_for_departure()
	_expect(marked, "an unaccepted side quest is marked missed when departing")
	_expect(_state.get_side_quest_state() == _state.SideQuestState.MISSED, "unaccepted -> missed")
	_expect(_quests().is_quest_missed(_state.QUDENG_QUEST_ID), "the quest log records it as missed")
	_expect(not _quests().is_quest_finished(_state.QUDENG_QUEST_ID), "missed is not finished")
	_expect(not _state.is_shumian_joined(), "settling alone does not decide the party")
	_state.join_shumian()
	_expect(_state.is_shumian_joined() and _shumian_slots() == 1, "departing still brings Shumian along")
	_expect(not _state.can_enter_clean_sewer(), "a missed side quest closes the clean sewer")
	_expect(not _state.settle_side_quest_for_departure(), "settling twice is a no-op")


func _test_depart_in_progress() -> void:
	_night_meeting_done()
	_state.accept_qudeng()
	var marked: bool = _state.settle_side_quest_for_departure()
	_expect(marked, "an unfinished accepted quest is marked missed when departing")
	_expect(_state.get_side_quest_state() == _state.SideQuestState.MISSED, "in progress -> missed")
	_expect(_state.is_shumian_joined(), "missing the quest does not remove Shumian from the party")
	_expect(_shumian_slots() == 1, "Shumian keeps her single slot")


func _test_party_independent_of_quest() -> void:
	_night_meeting_done()
	_state.join_shumian()
	_expect(_state.is_shumian_joined(), "joined")
	_expect(_state.get_side_quest_state() == _state.SideQuestState.AVAILABLE, "joining does not accept or complete the quest")
	_state.set_flag(_state.F_LIEFENG_CHAPTER_STARTED, true)
	_expect(not _state.is_prologue_ending_phase(), "starting the chapter ends the ending phase")


# ------------------------------------------------------------
# 書眠正式入隊等級：新遊戲、舊存檔的 Lv2、已超過 Lv6、重複入隊、讀檔修復
# ------------------------------------------------------------
const STAT_KEYS := ["level", "max_hp", "max_mp", "atk", "def", "speed", "accuracy", "evasion", "str", "agi", "int", "con", "luck"]


func _shumian() -> Dictionary:
	return _team().all_characters["shumian"]


func _snapshot() -> Dictionary:
	var out := {}
	for key in STAT_KEYS:
		out[key] = _shumian().get(key)
	return out


## 舊存檔的書眠：Lv1 時代開局，只升過一級（Lv2，經驗 25），完全沒有 Lv6 的初始化。
func _make_legacy_lv2_shumian() -> void:
	var actor: Dictionary = _shumian()
	actor["level"] = 1
	actor["exp"] = 0
	actor["stat_cycle_index"] = 0
	for key in ["str", "agi", "int", "con", "luck"]:
		actor[key] = 5
		actor["base_" + key] = 5
	for key in ["max_hp", "max_mp", "atk", "def", "accuracy", "evasion"]:
		actor.erase("base_" + key)
	actor["max_hp"] = 120
	actor["max_mp"] = 100
	actor["atk"] = 12
	actor["def"] = 3
	actor["accuracy"] = 100
	actor["evasion"] = 0
	actor["hp"] = 120
	actor["mp"] = 100
	_team().call("_level_up_actor", actor)
	actor["exp"] = 25
	_expect(int(actor["level"]) == 2, "legacy fixture is Lv2")


func _test_join_level() -> void:
	# 新遊戲：本來就是 Lv6，入隊不改變任何數字
	_reset()
	var canonical := _snapshot()
	_expect(int(canonical["level"]) == 6, "a new game's Shumian is Lv6")
	_night_meeting_done()
	_state.join_shumian()
	_expect(_snapshot() == canonical, "joining a fresh Lv6 Shumian changes nothing")
	_state.join_shumian()
	_expect(_snapshot() == canonical, "joining again changes nothing")

	# 舊存檔 Lv2：入隊時補到 Lv6，數值和新遊戲的 Lv6 一致，經驗保留，HP/MP 不超過上限
	_reset()
	_make_legacy_lv2_shumian()
	_night_meeting_done()
	_state.join_shumian()
	var repaired := _snapshot()
	_expect(repaired == canonical, "a legacy Lv2 Shumian reaches exactly the canonical Lv6 stats: %s vs %s" % [str(repaired), str(canonical)])
	_expect(int(_shumian()["exp"]) == 25, "earned exp is kept")
	_expect(int(_shumian()["hp"]) <= int(_shumian()["max_hp"]) and int(_shumian()["mp"]) <= int(_shumian()["max_mp"]), "HP/MP stay within their maxima")
	for skill_id in _team().SHUMIAN_INITIAL_SKILL_IDS:
		_expect(_team().get_known_skill_ids("shumian").has(skill_id), "initial skill known: " + String(skill_id))
	# 再入隊、再修復：不會再升級
	_state.join_shumian()
	_expect(not _state.repair_shumian_join_level(), "repair is a no-op once she is Lv6")
	_expect(_snapshot() == canonical, "no repeated growth")
	_expect(_shumian_slots() == 1, "still one party slot")
	# 之後正常升級
	_team().add_exp_to_actor_ids_with_growth(50, ["shumian"])
	_expect(int(_shumian()["level"]) == 7, "she levels up to Lv7 normally afterwards")

	# 已經超過 Lv6：不降級
	_reset()
	_team().add_exp_to_actor_ids_with_growth(50 * 3, ["shumian"])
	var high := int(_shumian()["level"])
	_expect(high == 9, "fixture: Shumian at Lv9")
	_state.join_shumian()
	_expect(int(_shumian()["level"]) == 9, "a higher level is never lowered")

	# 讀檔修復的條件：沒有入隊旗標、或名冊沒解鎖 → 不動
	_reset()
	_make_legacy_lv2_shumian()
	_expect(not _state.repair_shumian_join_level(), "no repair before she formally joins")
	_expect(int(_shumian()["level"]) == 2, "the Lv2 card is left alone when she has not joined")
	_gs().set_flag(_state.F_SHUMIAN_JOINED, true)
	_expect(not _state.repair_shumian_join_level(), "no repair when the roster does not have her")
	_team().unlock_roster("shumian")
	_expect(_state.repair_shumian_join_level(), "a joined Lv2 Shumian is repaired on load")
	_expect(int(_shumian()["level"]) == 6, "repaired to Lv6")
	_expect(not _state.repair_shumian_join_level(), "repairing twice does nothing")

	# Boss 戰的劇情戰鬥卡片（永久卡片之外的另一份）不被改動
	_reset()
	_make_legacy_lv2_shumian()
	_state.join_shumian()
	var story_card: Array = _team().get_story_battle_party_for_actor_ids(["shumian"])
	_expect(story_card.size() == 1 and int((story_card[0] as Dictionary).get("level", 0)) == 6, "the story battle card stays Lv6")
