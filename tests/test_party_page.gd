extends SceneTree

# 隊伍頁：上陣三格（劉語塵固定）、候補清單、移入／移出／隊伍已滿時替換。
# 執行：godot --headless --path . --script tests/test_party_page.gd

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL ", what)


func _run() -> void:
	await process_frame
	var team = root.get_node("TeamData")
	team.current_team_ids = ["liuyu"]
	team.unlock_roster("shumian")
	team.unlock_roster("lieshao")
	var menu = load("res://scripts/system_menu.gd").new()
	root.add_child(menu)
	var page = load("res://scripts/inventory/PartyPage.gd").new()
	page.menu = menu
	root.add_child(page)
	await process_frame
	await process_frame
	page._refresh()

	_check(page._focus_id == "liuyu", "starts on 劉語塵")
	_check(page._tiles.size() == 8 and page._tiles["weapon_1"].mouse_filter == Control.MOUSE_FILTER_IGNORE, "eight display-only equipment tiles")
	_check(not page._tiles["weapon_1"].get_node("EmptyIcon").visible, "劉語塵 wears a weapon in the main slot")
	_check(page._btn_action.disabled, "劉語塵 cannot be moved out")
	_check(page._row_buttons.size() == 2 and page._row_buttons.has("shumian") and page._row_buttons.has("lieshao"), "both unlocked allies are listed as candidates")

	page._on_candidate_pressed("shumian")
	_check(not page._btn_action.disabled and page._btn_action.text == "移入隊伍", "a candidate can move in")
	page._on_action_pressed()
	_check(team.current_team_ids == ["liuyu", "shumian"], "move in appends to the party")
	_check(page._row_buttons.size() == 1 and not page._row_buttons.has("shumian"), "the moved ally leaves the candidate list")
	_check(page._btn_action.text == "移出隊伍", "the moved ally now offers move out")

	page._on_candidate_pressed("lieshao")
	page._on_action_pressed()
	_check(team.current_team_ids == ["liuyu", "shumian", "lieshao"], "the third slot fills")

	# 隊伍已滿時：先點上陣隊員當換下對象，再從候補移入
	page._on_party_card_pressed("shumian")
	page._on_action_pressed()
	_check(team.current_team_ids == ["liuyu", "lieshao"], "move out removes the member")
	team.unlock_roster("lieshao")
	page._on_candidate_pressed("shumian")
	page._on_action_pressed()
	_check(team.current_team_ids.size() == 3, "back to a full party")

	page._on_party_card_pressed("liuyu")
	_check(page._btn_action.disabled, "劉語塵 stays locked even when the party is full")
	_check(page._swap_target == "" or page._swap_target != "liuyu", "劉語塵 is never a swap target")

	team.current_team_ids = ["liuyu"]
	print("PASS: party page" if _failures == 0 else "FAILED: %d" % _failures)
	quit(1 if _failures > 0 else 0)
