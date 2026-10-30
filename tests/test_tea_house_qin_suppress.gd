extends SceneTree

# 《臨風寄影》壓情後、白書眠解釋前先去醉月茶坊：特殊階段的開關、門口演出條件、紅徽音 A／B 循環。
# 執行：godot --headless --path . --script tests/test_tea_house_qin_suppress.gd

var Suppress
const TEASHOP := "res://scenes/yuheng/zueyue_teashop/zue_yue_teashop.tscn"

var _failures := 0
var gs
var qm


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL ", what)


func _text_of(lines: Array) -> String:
	var parts: PackedStringArray = []
	for l in lines:
		parts.append(String(l["text"]))
	return "\n".join(parts)


func _run() -> void:
	await process_frame
	Suppress = load("res://scripts/yuheng/yuheng_market_east/zueyue_teashop/TeaHouseQinSuppress.gd")
	gs = root.get_node("GlobalState")
	qm = root.get_node("QuestManager")
	var flags_backup: Dictionary = gs.flags.duplicate(true)
	var main_backup: Dictionary = qm.main_quest.duplicate(true)
	for f in [Suppress.F_SUPPRESSED, Suppress.F_ENTRY_DONE, Suppress.F_FIRST_MET, Suppress.F_MELODY_RECALL, Suppress.F_YINPINGYU_DONE]:
		gs.set_flag(f, false)
	qm.main_quest["stage"] = 1

	# ---- 還沒被壓情：什麼都不觸發 ----
	_check(not Suppress.is_window_open(), "not suppressed yet: window closed")
	_check(not Suppress.entry_pending() and not Suppress.huiyin_special_active(), "not suppressed yet: no entry, no special talk")

	# ---- 被壓情後、白書眠還沒解釋：門口演出待播；演出前紅徽音還是一般對話 ----
	gs.set_flag(Suppress.F_SUPPRESSED, true)
	_check(Suppress.is_window_open(), "suppressed, Shumian silent: window open")
	_check(Suppress.entry_pending(), "entry scene pending (first visit, regardless of earlier visits)")
	_check(not Suppress.huiyin_special_active(), "special talk only after the entry scene has played")

	# ---- 演出播完：紅徽音特殊循環生效，門口不再重播 ----
	gs.set_flag(Suppress.F_ENTRY_DONE, true)
	_check(not Suppress.entry_pending(), "entry scene does not replay")
	_check(Suppress.huiyin_special_active(), "after the entry scene: special talk active")
	_check(not gs.get_flag(Suppress.F_FIRST_MET), "the entry scene does not mark the first real conversation as done")

	# ---- 白書眠談完但《銀屏語》還沒完成：階段仍在 ----
	gs.set_flag("met_Su_Mien", true)
	_check(Suppress.is_window_open() and Suppress.huiyin_special_active(), "after the first Shumian talk: still open until Yinpingyu is done")
	gs.set_flag("met_Su_Mien", false)

	# ---- 《銀屏語》完成之後：階段結束，旗標保留 ----
	gs.set_flag(Suppress.F_YINPINGYU_DONE, true)
	_check(not Suppress.is_window_open() and not Suppress.huiyin_special_active(), "after Yinpingyu done: special talk ends")
	_check(gs.get_flag(Suppress.F_ENTRY_DONE), "entry flag stays set after the window closes")

	# ---- 已經跟紅徽音說過話：不播門口演出，只有找她時的特殊對白 ----
	gs.set_flag(Suppress.F_YINPINGYU_DONE, false)
	gs.set_flag(Suppress.F_ENTRY_DONE, false)
	gs.set_flag(Suppress.F_FIRST_MET, true)
	_check(not Suppress.entry_pending(), "already talked to her: no entry scene")
	_check(Suppress.huiyin_special_active(), "already talked to her: special talk still active")
	gs.set_flag(Suppress.F_FIRST_MET, false)
	gs.set_flag(Suppress.F_YINPINGYU_DONE, true)

	# ---- 先完成《銀屏語》的玩家：階段在進茶坊前就結束，門口不播 ----
	gs.set_flag(Suppress.F_ENTRY_DONE, false)
	_check(not Suppress.entry_pending(), "finished Yinpingyu first: no entry scene")

	# ---- 台詞 ----
	var entry := _text_of(Suppress.entry_part1()) + "\n" + _text_of(Suppress.entry_part2())
	_check(entry.contains("錚——") and entry.contains("真就是好事麼"), "entry scene: two plucks and the closing question")
	_check(entry.contains("你仍記得自己為何而來"), "entry scene: memory and reason are kept, only the feeling is gone")
	var a := _text_of(Suppress.huiyin_loop(true))
	var b := _text_of(Suppress.huiyin_loop(false))
	_check(a.contains("你再次走近琴案") and not a.contains("素未謀面"), "A (talked before) wording")
	_check(b.contains("素未謀面") and not b.contains("你再次走近琴案"), "B (never talked) wording")
	_check(Suppress.huiyin_loop(true) == Suppress.huiyin_loop(true), "the loop is the same every time")

	# ---- 場景已掛好觸發節點 ----
	var state := (load(TEASHOP) as PackedScene).get_state()
	var names: Array = []
	for i in state.get_node_count():
		names.append(String(state.get_node_name(i)))
	_check(names.has("tea_house_qin_suppress_entry") and names.has("tea_house_melody_recall"), "teashop scene has both entry triggers")

	gs.flags = flags_backup
	qm.main_quest = main_backup
	print("tea house qin suppress: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	quit(1 if _failures > 0 else 0)
