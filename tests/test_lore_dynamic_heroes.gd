extends SceneTree

# 動態豪傑誌：左飲（一個階段）、比武老翁（三個階段，可跳級）。看旗標與任務進度，存讀檔不倒退。
# 執行：godot --headless --path . --script tests/test_lore_dynamic_heroes.gd

var _failures := 0
var LoreDB
var gs
var sq
const OLD := "old_fighter"
const ZUO := "zuoyin"
const QUEST := "yh_side_oldfighter_01"


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL ", what)


func _reset() -> void:
	for f in ["heard_oldman_zuoyin", "yh_side_oldfighter_weapon_win", "yh_side_oldfighter_unarmed_win", "battle_stalactite_fish_boss_phase2", "battle_stalactite_fish_boss_won", "main_yh_manor_after_fish_ready", "triggered_zuoyin_gossip_summary"]:
		gs.set_flag(f, false)
	sq.side_quests.erase(QUEST)


func _finish_quest() -> void:
	sq.register_quest(QUEST, {"quest_id": QUEST, "title": "拳骨未老"})
	sq.complete_quest(QUEST)


func _count(id: String) -> int:
	return LoreDB.get_hero_paragraphs(id).size()


func _run() -> void:
	await process_frame
	LoreDB = load("res://scripts/db/LoreDB.gd")
	gs = root.get_node("GlobalState")
	sq = root.get_node("SideQuestManager")
	var flags_backup: Dictionary = gs.flags.duplicate(true)
	var quests_backup: Dictionary = sq.save_all().duplicate(true)

	# ---- 比武老翁 ----
	_reset()
	_check(not LoreDB.is_hero_unlocked(OLD) and _count(OLD) == 0, "never talked to him: no entry")
	gs.set_flag("heard_oldman_zuoyin", true)
	_check(LoreDB.is_hero_unlocked(OLD) and _count(OLD) == 2, "first conversation (declined the spar): two paragraphs")
	# 挑戰失敗不會落任何旗標 → 維持兩段
	_check(_count(OLD) == 2, "a lost challenge changes nothing")
	gs.set_flag("yh_side_oldfighter_weapon_win", true)
	_check(_count(OLD) == 3, "won with a weapon: three paragraphs")
	gs.set_flag("yh_side_oldfighter_weapon_win", false)
	gs.set_flag("yh_side_oldfighter_unarmed_win", true)
	_check(_count(OLD) == 3, "won bare-handed but still dressed: three paragraphs")
	gs.set_flag("yh_side_oldfighter_weapon_win", true)
	_check(_count(OLD) == 3, "weapon win then bare-handed win: still three")
	_finish_quest()
	_check(_count(OLD) == 4, "quest finished (fully unequipped win): all four paragraphs")
	var full: Array = LoreDB.get_hero_paragraphs(OLD)
	_check(String(full[3]).contains("掃帚") and not String(full[2]).contains("掃帚"), "the broom joke is only in the last paragraph")

	# 第一次比武就完全卸裝獲勝：沒有任何比武旗標、也沒聽過初次交談旗標之外的階段，只有任務完成 → 直接全部
	_reset()
	gs.set_flag("heard_oldman_zuoyin", true)
	_finish_quest()
	_check(_count(OLD) == 4, "first fight won fully unequipped: all four at once")
	_reset()
	_finish_quest()
	_check(_count(OLD) == 4 and LoreDB.is_hero_unlocked(OLD), "even with only the finished quest, every paragraph unlocks")

	# 重新裝備武器不影響（只看曾經完成什麼）
	_check(_count(OLD) == 4, "re-equipping later changes nothing")

	# 存檔 → 清空 → 讀檔
	var saved_flags: Dictionary = gs.flags.duplicate(true)
	var saved_quests: Dictionary = sq.save_all().duplicate(true)
	_reset()
	_check(_count(OLD) == 0, "after wiping the state, nothing is unlocked")
	gs.flags = saved_flags.duplicate(true)
	sq.load_all(saved_quests)
	_check(_count(OLD) == 4, "save then load restores all four paragraphs")

	# 內容不變：沿用老闆給的原文
	_check(String(full[0]).begins_with("玉衡鎮舊演武台旁") and String(full[1]).begins_with("據其自述") and String(full[2]).begins_with("老翁性情好勝"), "paragraph texts are the approved wording")

	# ---- 左飲 ----
	_reset()
	gs.set_flag("triggered_zuoyin_gossip_summary", true)
	_check(not LoreDB.is_hero_unlocked(ZUO) and _count(ZUO) == 0, "only heard rumours about Zuo Yin: no entry")
	gs.set_flag("battle_stalactite_fish_boss_phase2", true)
	_check(LoreDB.is_hero_unlocked(ZUO) and _count(ZUO) == 3, "after the cave rescue and learning who he is: the approved three paragraphs")
	_check(String(LoreDB.get_hero_paragraphs(ZUO)[1]).contains("出手替劉語塵與白書眠解圍"), "the rescue paragraph is there once unlocked")

	# ---- 豪傑誌頁面資料 ----
	_reset()
	var Entries = load("res://scripts/inventory/LoreEntries.gd")
	var heroes: Array = Entries.entries("豪傑")
	var old_entry: Dictionary = {}
	for e in heroes:
		if String(e["id"]) == OLD:
			old_entry = e
	_check(not old_entry.is_empty() and not bool(old_entry["unlocked"]), "the entry is there but locked and named ？？？ before the first conversation")
	_check(String(old_entry["name"]) == Entries.UNKNOWN and String(old_entry["prose"]) == "", "locked entries do not leak any text")
	gs.set_flag("heard_oldman_zuoyin", true)
	for e in Entries.entries("豪傑"):
		if String(e["id"]) == OLD:
			old_entry = e
	_check(bool(old_entry["unlocked"]) and String(old_entry["name"]) == "比武老翁" and String(old_entry["prose"]).split("\n").size() == 2, "after the first conversation the entry shows two paragraphs")
	_check(String(old_entry["summary"]).contains("玉衡鎮演武台") and String(old_entry["summary"]).contains("姓名：未詳"), "the place and name lines sit under the portrait")
	var count_entries := 0
	for e in Entries.entries("豪傑"):
		if String(e["id"]) == OLD:
			count_entries += 1
	_check(count_entries == 1, "one entry per character, not one per stage")

	# ---- 書籤：每段一枚（其一、其二…），點哪枚左頁就顯示那一段 ----
	_finish_quest()
	var menu = load("res://scripts/system_menu.gd").new()
	root.add_child(menu)
	var page = load("res://scripts/inventory/LorePage.gd").new()
	page.menu = menu
	root.add_child(page)
	await process_frame
	await process_frame
	page.open_book("豪傑")
	await create_timer(2.8).timeout
	var at := -1
	for i in page._list.size():
		if String(page._list[i].get("id", "")) == OLD:
			at = i
	page._go(at)
	await create_timer(3.0).timeout
	_check(page._bookmark_nodes.size() == 4, "four unlocked paragraphs give four bookmarks")
	page._bookmark_nodes[3].pressed.emit()
	_check(int(page._hero_section.get(OLD, 0)) == 3 and page._bookmark_nodes.size() == 4, "pressing the fourth bookmark selects the fourth paragraph")
	page.close_book()
	await create_timer(2.4).timeout
	_check(page._bookmark_nodes.is_empty(), "closing the book removes the bookmarks")

	gs.flags = flags_backup
	sq.load_all(quests_backup)
	print("PASS: dynamic lore heroes" if _failures == 0 else "FAILED: %d" % _failures)
	quit(1 if _failures > 0 else 0)
