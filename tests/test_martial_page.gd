extends SceneTree

# 武術頁：動態分類（只列已習得的類別）、內功五標籤篩選、更換內功（沿用現有規則）、內外功搭配、抽屜開關、切換角色。
# 執行：godot --headless --path . --script tests/test_martial_page.gd

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
	team.unlock_roster("shumian")
	var menu = load("res://scripts/system_menu.gd").new()
	root.add_child(menu)
	var info: GDScript = load("res://scripts/inventory/MartialInfo.gd")
	var page = load("res://scripts/inventory/MartialPage.gd").new()
	page.menu = menu
	root.add_child(page)
	await process_frame
	await process_frame
	page._refresh()

	_check(page.actor_id == "liuyu", "starts on 劉語塵")
	# 分類：只出現已習得涉及的類別，順序固定，沒有的不出現
	var cats: Array = page._cats
	_check(not cats.is_empty(), "劉語塵 has categories")
	var have := {}
	for s in page._skills:
		have[String(s.get("weapon_type", "")).strip_edges()] = true
	for c in info.CATEGORY_ORDER:
		_check(cats.has(c) == have.has(c), "category %s appears exactly when a skill of that kind is learned" % c)
	_check(page.category == "全部", "default category is 全部")
	# 選擇分類只列那一類
	if cats.has("劍"):
		page._select_category("劍")
		var all_sword := true
		for s in page._visible_skills():
			all_sword = all_sword and String(s.get("weapon_type", "")) == "劍"
		_check(all_sword and page._visible_skills().size() > 0, "the 劍 tab lists only learned sword skills")
	# 切換角色：分類重算、殘留的分類與選中招式清掉
	page._on_skill_pressed(page._visible_skills()[0])
	_check(not page.selected_skill.is_empty(), "a skill can be selected")
	page._on_actor_pressed("shumian")
	_check(page.actor_id == "shumian" and page.category == "全部" and page.selected_skill.is_empty(), "switching actor resets the category and selection")
	var shu_have := {}
	for s in page._skills:
		shu_have[String(s.get("weapon_type", "")).strip_edges()] = true
	_check(page._cats.size() == info.categories(page._skills).size() and shu_have.size() >= 1, "書眠's categories are rebuilt from her own skills")
	page._on_actor_pressed("liuyu")

	# 內外功搭配：選一招，顯示目前內功的聯動（流塵訣 × 連決劍 在表裡是專屬搭配）
	var cur_id := String(team.get_current_inner_force_id("liuyu"))
	team.set_inner_force("liuyu", "liuchen_jue")
	page._refresh()
	var lian: Dictionary = {}
	for s in page._skills:
		if String(s.get("id", "")) == "skill_lianjuejian":
			lian = s
	_check(not lian.is_empty(), "連決劍 is learned by 劉語塵")
	page._on_skill_pressed(lian)
	_check(page._syn_text.text.contains("流塵") or page._syn_text.text.contains("相合") or page._syn_text.text.contains("專屬"), "the synergy panel shows the linkage for the current inner force")
	team.set_inner_force("liuyu", cur_id)

	# 更換內功：五標籤篩選，換內功沿用 TeamData.set_inner_force
	page._refresh()
	page._open_force_picker()
	_check(page._overlay.visible, "the force picker opens")
	var forces: Array = page._forces()
	_check(forces.size() >= 2, "劉語塵 knows several inner forces")
	var by_el := {}
	for f in forces:
		by_el[String(f.get("element", ""))] = true
	for el in info.ELEMENTS:
		var n: int = page._forces_in(el).size()
		var expected := 0
		for f in forces:
			if String(f.get("element", "")) == el:
				expected += 1
		_check(n == expected, "filter %s lists exactly the forces of that attribute" % el)
	_check(page._forces_in("全部").size() == forces.size(), "全部 lists every learned force")
	var target := ""
	for f in forces:
		if String(f.get("id", "")) != String(team.get_current_inner_force_id("liuyu")):
			target = String(f.get("id", ""))
			break
	page._close_overlay()
	page._switch_force(target)
	_check(String(team.get_current_inner_force_id("liuyu")) == target, "switching changes the running inner force through TeamData")
	_check(page._force_name.text == info.force_name(page._current_force()), "the force panel shows the new force")
	page._switch_force(cur_id)


	# 大地圖施展：只有 menu_usable 的招式標「可施展」；單體選對象、全體直接施展；扣內力、回復氣血
	var qi: Dictionary = {}
	var mo: Dictionary = {}
	var sword: Dictionary = {}
	for s in page._skills:
		match String(s.get("id", "")):
			"skill_qiliaozhang": qi = s
			"skill_mobishuxin": mo = s
			"skill_lianjuejian": sword = s
	_check(not qi.is_empty() and page._world_usable(qi), "氣療掌 is usable on the world map")
	_check(not sword.is_empty() and not page._world_usable(sword), "連決劍 is battle-only (no 可施展 mark)")
	var liu = menu._get_actor_by_id("liuyu")
	menu._set_actor_value(liu, "hp", 20)
	menu._set_actor_value(liu, "mp", 50)
	page._do_cast(qi, "liuyu")
	_check(int(menu._get_actor_value(liu, "hp", 0)) > 20, "single-target cast heals the chosen ally")
	_check(int(menu._get_actor_value(liu, "mp", 0)) == 50 - int(qi.get("mp_cost", 0)), "casting spends the MP cost")
	menu._set_actor_value(liu, "hp", 20)
	menu._set_actor_value(liu, "mp", 0)
	page._cast_skill(qi)
	_check(int(menu._get_actor_value(liu, "hp", 0)) == 20 and not page._overlay.visible, "not enough MP: nothing happens")
	if not mo.is_empty():
		menu._set_actor_value(liu, "hp", 20)
		page._do_cast(mo, "")
		_check(int(menu._get_actor_value(liu, "hp", 0)) > 20, "all-ally cast heals the whole party")
	print("PASS test_martial_page" if _failures == 0 else "FAILED test_martial_page: %d" % _failures)
	quit(1 if _failures > 0 else 0)
