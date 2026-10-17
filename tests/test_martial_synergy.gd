extends SceneTree
## Regression for the three standard martial synergies (inner force x martial skill): 流塵訣×連決劍 (+1 strike),
## 伏潮訣×斷水斬 (on-hit 破防), 沉潮訣×破浪槍 (extra STR/AGI scaling). They must behave identically before and after the
## synergy data is moved to its canonical table, and what SkillView reports must equal what a real battle does.
## Run: --headless --path . --script tests/test_martial_synergy.gd

const InnerForceDBScript = preload("res://scripts/battlescripts/InnerForceDB.gd")

var SkillView: Script
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _run() -> void:
	SkillView = load("res://scripts/battlescripts/SkillView.gd")
	var fixture: Node = (load("res://scenes/presentation/card_stage_prototype.tscn") as PackedScene).instantiate()
	fixture.auto_start = false
	root.add_child(fixture)
	for frame: int in range(30):
		if fixture.prepared:
			break
		await process_frame
	_expect(fixture.prepared, "the card stage prepares")
	if fixture.prepared:
		_check_all(fixture)
	fixture.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS: martial synergy")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		quit(1)


func _force(force_id: String) -> Dictionary:
	var db: Node = InnerForceDBScript.new()
	var force: Dictionary = db.get_force(force_id)
	db.free()
	return force


func _actor(controller: Node, force_id: String) -> Dictionary:
	var actor: Dictionary = {"id": "syn_actor", "name": "測試者", "inner_force_id": force_id, "inner_force": _force(force_id) if force_id != "" else {}}
	return actor


func _check_all(fixture: Node) -> void:
	var ui: Node = fixture.ui
	var controller: Node = fixture.controller
	var skill_db: Node = ui.character_skill_db
	var base_db: Node = SkillView._db()

	# --- 流塵訣 x 連決劍: +1 strike, in the runtime skill, in the controller and in SkillView
	var lian: Dictionary = base_db.get_skill("skill_lianjuejian")
	var liuchen: Dictionary = _force("liuchen_jue")
	var with_force: Dictionary = _actor(controller, "liuchen_jue")
	var without: Dictionary = _actor(controller, "")
	var other: Dictionary = _actor(controller, "fuchao_jue")
	_expect(not liuchen.is_empty(), "流塵訣 exists")
	_expect(controller._resolve_strike_count(with_force, lian) == 4, "連決劍 + 流塵訣 = 4 strikes in the controller")
	_expect(controller._resolve_strike_count(without, lian) == 3, "連決劍 with no inner force = 3 strikes")
	_expect(controller._resolve_strike_count(other, lian) == 3, "連決劍 with another inner force = 3 strikes")
	var view_on: Dictionary = SkillView.strike_info(lian, liuchen)
	_expect(int(view_on.base) == 3 and int(view_on.effective) == 4 and int(view_on.delta) == 1, "SkillView: base 3, effective 4 with 流塵訣: %s" % str(view_on))
	_expect(int(view_on.effective) == controller._resolve_strike_count(with_force, lian), "SkillView == the controller (流塵訣)")
	var view_off: Dictionary = SkillView.strike_info(lian, _force("fuchao_jue"))
	_expect(int(view_off.effective) == 3 and int(view_off.delta) == 0, "SkillView: no change without the matching inner force")
	var runtime_on: Dictionary = skill_db.resolve_runtime_skill(lian, liuchen, with_force)
	_expect(String(runtime_on.get("name", "")) == "流塵連決劍", "runtime skill is renamed: " + String(runtime_on.get("name", "")))
	var runtime_off: Dictionary = skill_db.resolve_runtime_skill(lian, {}, without)
	_expect(String(runtime_off.get("name", "")) == "連決劍", "no rename without the inner force")

	# --- 伏潮訣 x 斷水斬: on-hit 破防 (10, 2 turns) only with 伏潮訣
	var duan: Dictionary = base_db.get_skill("skill_duanshuizhan")
	var fuchao_rule: Dictionary = controller._resolve_pairing_bonus(_actor(controller, "fuchao_jue"), duan)
	var status: Dictionary = (fuchao_rule.get("effects", {}) as Dictionary).get("on_hit_status", {})
	_expect(String(status.get("effect_id", "")) == "break_def" and int(status.get("amount", 0)) == 10 and int(status.get("turns", 0)) == 2, "伏潮訣 x 斷水斬 gives 破防 10 for 2 turns: %s" % str(status))
	_expect(controller._resolve_pairing_bonus(_actor(controller, "liuchen_jue"), duan).is_empty(), "断水斬 with another inner force has no pairing")
	_expect(controller._resolve_pairing_bonus(without, duan).is_empty(), "斷水斬 with no inner force has no pairing")
	controller.action_log_ui = null
	var target: Dictionary = {"id": "syn_foe", "battle_uid": "syn_foe", "name": "木人", "is_enemy": true, "hp": 500, "max_hp": 500, "def": 20, "con": 20, "speed": 10, "evasion": 0, "statuses": []}
	var user: Dictionary = _actor(controller, "fuchao_jue")
	user["battle_uid"] = "syn_actor"
	var before: String = JSON.stringify(target.get("statuses", []))
	controller._apply_pairing_post_hit_effects(user, duan, target, {})
	_expect(JSON.stringify(target.get("statuses", [])) == before, "an empty pairing applies nothing")
	controller._apply_pairing_post_hit_effects(user, duan, target, fuchao_rule)
	_expect(JSON.stringify(target.get("statuses", [])) != before or JSON.stringify(target) != "", "the pairing is applied on hit")
	var applied: bool = JSON.stringify(target).find("break_def") != -1
	_expect(applied, "the target carries 破防 after the hit: " + JSON.stringify(target))
	var runtime_duan: Dictionary = skill_db.resolve_runtime_skill(duan, _force("fuchao_jue"), user)
	_expect(String(runtime_duan.get("name", "")) == "伏潮斷水斬", "runtime rename: " + String(runtime_duan.get("name", "")))

	# --- 沉潮訣 x 破浪槍: scaling str +0.70 / agi +0.45 on top of the base
	var spear: Dictionary = base_db.get_skill("skill_breaking_wave_spear")
	var base_scaling: Dictionary = spear.get("stat_scaling", {})
	var chen: Dictionary = skill_db.resolve_runtime_skill(spear, _force("chenchao_jue"), _actor(controller, "chenchao_jue"))
	var scaling: Dictionary = chen.get("stat_scaling", {})
	_expect(is_equal_approx(float(scaling.get("str", 0.0)), float(base_scaling.get("str", 0.0)) + 0.70), "STR scaling +0.70: %s vs %s" % [str(scaling), str(base_scaling)])
	_expect(is_equal_approx(float(scaling.get("agi", 0.0)), float(base_scaling.get("agi", 0.0)) + 0.45), "AGI scaling +0.45")
	_expect(String(chen.get("name", "")) == "沉潮破浪槍", "runtime rename: " + String(chen.get("name", "")))
	var plain: Dictionary = skill_db.resolve_runtime_skill(spear, _force("liuchen_jue"), _actor(controller, "liuchen_jue"))
	_expect(is_equal_approx(float((plain.get("stat_scaling", {}) as Dictionary).get("str", 0.0)), float(base_scaling.get("str", 0.0))), "no extra scaling with another inner force")
	var no_force: Dictionary = skill_db.resolve_runtime_skill(spear, {}, without)
	_expect(is_equal_approx(float((no_force.get("stat_scaling", {}) as Dictionary).get("agi", 0.0)), float(base_scaling.get("agi", 0.0))), "no extra scaling without an inner force")
	# resolving an already-resolved skill must not stack the bonus twice
	var again: Dictionary = skill_db.resolve_runtime_skill(chen, _force("chenchao_jue"), _actor(controller, "chenchao_jue"))
	_expect(is_equal_approx(float((again.get("stat_scaling", {}) as Dictionary).get("str", 0.0)), float(scaling.get("str", 0.0))), "the bonus does not stack on a resolved skill")

	# --- the exclusive-skill lists stay what they were
	_expect((_force("liuchen_jue").get("exclusive_skill_ids", []) as Array).has("skill_lianjuejian"), "流塵訣 lists 連決劍 as exclusive")
	_expect((_force("fuchao_jue").get("exclusive_skill_ids", []) as Array).has("skill_duanshuizhan"), "伏潮訣 lists 斷水斬 as exclusive")
	_expect((_force("chenchao_jue").get("exclusive_skill_ids", []) as Array).has("skill_breaking_wave_spear"), "沉潮訣 lists 破浪槍 as exclusive")

	# --- strike_info: a fixed count reads "3擊", a range reads "2～4擊"; the range is not mistaken for a base of 1
	var fixed_info: Dictionary = SkillView.strike_info(lian, {})
	_expect(String(fixed_info.base_text) == "3擊" and String(fixed_info.effective_text) == "3擊" and not bool(fixed_info.ranged), "a fixed skill reads 3擊: %s" % str(fixed_info))
	_expect(String(view_on.base_text) == "3擊" and String(view_on.effective_text) == "4擊", "three layers for 連決劍: 基礎 3擊, 目前 4擊")
	var fist: Dictionary = base_db.get_skill("skill_tianjingquan")
	var range_info: Dictionary = SkillView.strike_info(fist, {})
	_expect(bool(range_info.ranged) and int(range_info.base_min) == 2 and int(range_info.base_max) == 4 and String(range_info.base_text) == "2～4擊", "a ranged skill reads 2～4擊: %s" % str(range_info))
	_expect(int(range_info.delta) == 0, "the range is not a change")
	# the controller rolls inside the same range
	for roll: int in range(20):
		var count: int = controller._resolve_strike_count(without, fist)
		_expect(count >= int(range_info.effective_min) and count <= int(range_info.effective_max), "the real count %d is inside the shown range" % count)

	# --- the canonical table feeds the rest
	var table: Script = load("res://scripts/battlescripts/MartialSynergy.gd")
	var standard: int = 0
	for record: Dictionary in table.all():
		if String(record.relation_type) == "standard":
			standard += 1
	_expect(standard == 4, "the table holds exactly the four standard pairings (流塵連決劍、伏潮斷水斬、沉潮破浪槍、清渠澄心落筆)")
	_expect(table.exclusive_skill_ids("liuchen_jue") == ["skill_lianjuejian"], "exclusive ids derive from the table")
	var lian_lines: Array = base_db.get_inner_force_linkage_entries(lian, with_force, liuchen)
	var found_linkage: bool = false
	for entry: Dictionary in lian_lines:
		if String(entry.get("kind", "")) == "專屬搭配":
			found_linkage = true
			_expect(String(entry.text_long) == "流塵訣下可進化為「流塵連決劍」。" and bool(entry.met), "the linkage text comes from the table and is met under 流塵訣")
	_expect(found_linkage, "連決劍 still lists its synergy")
	_expect(table.for_martial("skill_tianjingquan").size() == 2 and table.for_martial("skill_diquejian").size() == 1, "legendary chain (2 records) and risk branch are described in the table")
	for record: Dictionary in table.for_martial("skill_tianjingquan") + table.for_martial("skill_diquejian"):
		_expect(table.runtime_rule(String(record.martial_skill_id), String(record.inner_skill_id)).is_empty(), "%s has no runtime rule (display only)" % String(record.display_name))

	# --- the Inspect 相合 page (acceptance cases): learned only, 運行中 / 未運行, three layers, both directions
	var inspect_data: Script = load("res://scripts/presentation/CardInspectData.gd")
	var context: Dictionary = fixture.build_preview_context()
	var ally: Dictionary = (context.player_party[0] as Dictionary).duplicate(true)
	ally["inner_force"] = _force("qingfeng_jue")
	ally["inner_force_id"] = "qingfeng_jue"
	var idle: String = _page_text(inspect_data.synergy_page(ui, ally))
	_expect(idle.contains("流塵訣 × 連決劍") and idle.contains("未運行") and idle.contains("基礎：3擊") and idle.contains("目前：3擊（流塵訣未運行，相合未生效）"), "A/C: 流塵訣 learned but not running: listed, tagged 未運行, 3擊, not applied")
	_expect(not idle.contains("伏潮訣") and not idle.contains("石破"), "not-yet-learned content is hidden")
	_expect(idle.contains("〔標準相合〕") and idle.contains("〔絕技分支〕"), "relation types are labelled (標準相合 / 絕技分支)")
	ally["inner_force"] = liuchen
	ally["inner_force_id"] = "liuchen_jue"
	var running_page: Dictionary = inspect_data.synergy_page(ui, ally)
	var running_text: String = _page_text(running_page)
	_expect(running_text.contains("〔運行中〕") and running_text.contains("基礎：3擊") and running_text.contains("相合：攻擊段數 +1") and running_text.contains("目前：4擊"), "B: running 流塵訣: 基礎 3擊 → 相合 +1 → 目前 4擊")
	_expect(controller._resolve_strike_count(ally, lian) == 4, "...and the real battle strikes 4 times, as the page says")
	var heading_skills: Array = []
	var heading_forces: Array = []
	for section: Dictionary in running_page.sections:
		for entry: Dictionary in section.entries:
			(heading_forces if String(section.heading) == "內功" else heading_skills).append(String(entry.id))
	_expect(heading_forces.has("force:liuchen_jue") and heading_skills.has("skill:skill_lianjuejian"), "E/F: the force lists its skills and the skill lists its forces (both directions)")
	# the panel shows it: a 相合 tab, left list, right description
	var panel: PanelContainer = ui._inspect.panel
	var data: Dictionary = inspect_data.for_actor(ui, ally, false)
	_expect(data.has("synergy_page"), "a character's inspect data has a synergy page")
	panel.show_data(data)
	panel._show_page("synergy")
	_expect(panel.current_page() == "synergy" and panel._skills_root.visible and not panel._scroll.visible, "the 相合 tab opens its own page")
	_expect(panel.select_skill_entry_by_id("skill:skill_lianjuejian") and panel.skills_description_text().contains("目前：4擊"), "selecting the skill shows the synergy in the description")
	_expect(panel.select_skill_entry_by_id("force:liuchen_jue") and panel.skills_description_text().contains("連決劍"), "selecting the force shows the skill it pairs with")
	panel._show_page("skills")
	_expect(panel.current_page() == "skills" and not panel.skills_description_text().contains("相合："), "switching back to 武學 rebuilds that list")
	panel._show_page("overview")
	# the legendary chain appears for a character who has learned it, tagged 傳說鏈, without touching the runtime
	var master: Dictionary = ally.duplicate(true)
	master["inner_force"] = _force("shipo_xinfa")
	master["inner_force_id"] = "shipo_xinfa"
	master["known_inner_force_ids"] = ["shipo_xinfa"]
	master["available_inner_forces"] = [master.inner_force]
	var fist_runtime: Dictionary = skill_db.resolve_runtime_skill(fist, master.inner_force, master)
	_expect(String(fist_runtime.get("name", "")) in ["石破天驚拳", "真．石破天驚拳"], "the legendary chain still resolves in the runtime: " + String(fist_runtime.get("name", "")))
	var chain_text: String = _page_text(inspect_data.synergy_page(ui, master))
	var block: String = ""
	for record: Dictionary in table.for_martial("skill_tianjingquan"):
		block += "\n".join(PackedStringArray(inspect_data._synergy_block(skill_db, master, master.inner_force, record, "石破心法"))) + "\n"
	_expect(block.contains("〔傳說鏈〕") and block.contains("條件：全身無裝備") and block.contains("基礎：2～4擊") and block.contains("真．石破天驚拳"), "the legendary chain block: 傳說鏈, its condition, 2～4擊, both forms")
	if _page_text(inspect_data.synergy_page(ui, master)).contains("石破"):
		_expect(chain_text.contains("〔傳說鏈〕"), "when learned, the legendary chain shows on the page")


func _page_text(page: Dictionary) -> String:
	var out: Array[String] = []
	for section: Dictionary in page.get("sections", []):
		for entry: Dictionary in section.entries:
			out.append("\n".join(PackedStringArray(entry.lines)))
	return "\n".join(PackedStringArray(out))
