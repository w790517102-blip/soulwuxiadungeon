extends SceneTree
## Skill usability: one cost / one verdict (SkillView) shared by the battle skill list, Card Inspect and the
## controller; the list shows MP, mutes (same hue) what cannot be used now but keeps it readable; a refused skill
## spends nothing and does NOT use the actor's turn, in the controller and in the UI flow.
## Run: --headless --path . --script tests/test_skill_availability.gd

# Loaded at run time: these scripts reach the project autoloads, which do not exist yet when this file compiles.
var SkillView: Script

var _failures: Array[String] = []
var _completed: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _run() -> void:
	SkillView = load("res://scripts/battlescripts/SkillView.gd")
	_check_view()
	var fixture: Node = (load("res://scenes/presentation/card_stage_prototype.tscn") as PackedScene).instantiate()
	fixture.auto_start = false
	root.add_child(fixture)
	for frame: int in range(30):
		if fixture.prepared:
			break
		await process_frame
	_expect(fixture.prepared, "the card stage prepares")
	if fixture.prepared:
		await _check_flow(fixture)
	fixture.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS: skill availability")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		quit(1)


func _check_view() -> void:
	var skill: Dictionary = {"id": "x", "name": "測試招", "weapon_type": "劍", "mp_cost": 20}
	var actor: Dictionary = {"id": "a", "mp": 12, "weapon_1": "劍", "weapon_2": ""}
	_expect(SkillView.mp_cost(actor, skill) == 20, "the cost is the skill's own cost")
	var verdict: Dictionary = SkillView.check(actor, skill)
	_expect(not bool(verdict.ok) and String(verdict.code) == "mp" and int(verdict.need) == 20 and int(verdict.have) == 12, "12 MP for a 20 MP skill: refused with the numbers")
	_expect(SkillView.disabled_reason(actor, skill) == "內力不足：需要 20，目前 12", "the reason reads: " + SkillView.disabled_reason(actor, skill))
	actor.mp = 20
	_expect(SkillView.can_use(actor, skill) and SkillView.disabled_reason(actor, skill) == "", "exactly enough MP is enough")
	# the inner force changes the cost: the same function everywhere
	actor["inner_force"] = {"skill_mp_cost_multiplier": 1.5}
	_expect(SkillView.mp_cost(actor, skill) == 30, "an inner force that makes skills dearer is part of the cost")
	_expect(not SkillView.can_use(actor, skill), "...and the verdict follows it")
	# a free skill is always affordable
	_expect(SkillView.can_use({"mp": 0}, {"id": "y", "mp_cost": 0}), "a skill that costs nothing is usable with 0 MP")
	# muted keeps the hue
	var blue := Color(0.35, 0.78, 1.0)
	var muted: Color = SkillView.muted(blue)
	_expect(is_equal_approx(muted.h, blue.h) and muted.s < blue.s and muted.v < blue.v, "muted: same hue, less saturation and brightness")
	_expect(not is_equal_approx(SkillView.muted(Color(1.0, 0.62, 0.2)).h, muted.h), "...different skills keep different hues, they do not all turn the same grey")


func _check_flow(fixture: Node) -> void:
	var ui: Node = fixture.ui
	var controller: Node = fixture.controller
	var context: Dictionary = fixture.build_preview_context()
	var ally: Dictionary = (context.player_party[0] as Dictionary).duplicate(true)
	var foe: Dictionary = (context.enemy_party[0] as Dictionary).duplicate(true)
	ally["battle_uid"] = "skill_ally"
	foe["battle_uid"] = "skill_foe"
	foe["is_enemy"] = true
	controller.player_party = [ally]
	controller.enemy_party = [foe]
	controller.ruleset = context.ruleset
	ui.set_teams([ally], [foe])
	var popup: Node = ui.skill_list_popup
	var skills: Array = ui.character_skill_db.get_skills_by_actor(ally)
	# a skill that costs something, found in the real data
	var costly: Dictionary = {}
	var free: Dictionary = {}
	for skill: Dictionary in skills:
		if SkillView.mp_cost(ally, skill) > 0 and costly.is_empty() and String(skill.get("target_side", "enemy")) == "enemy":
			costly = skill
		if SkillView.mp_cost(ally, skill) == 0 and free.is_empty():
			free = skill
	_expect(not costly.is_empty(), "the party member has a skill that costs MP")
	if costly.is_empty():
		return
	var cost: int = SkillView.mp_cost(ally, costly)
	ally["mp"] = cost - 1
	ui.current_actor = ally
	ui.current_turn_id = String(ally.get("id", ""))
	ui.on_action_selection = true
	popup.show_skills(skills, ally.get("inner_force", {}), ui.character_skill_db, ["劍", "刀", "拳", "掌", "棍", "槍", "筆", "琴"], ally)
	var found: int = -1
	for index: int in range(popup.skill_list.item_count):
		if String(popup.available_skills[index].get("id", "")) == String(costly.get("id", "")):
			found = index
	_expect(found >= 0, "the costly skill is in the list")
	_expect(found >= 0 and popup.skill_list.get_item_text(found).ends_with("%d MP" % cost), "the list shows its cost: " + (popup.skill_list.get_item_text(found) if found >= 0 else ""))
	_expect(found >= 0 and not popup.skill_list.is_item_disabled(found), "it stays selectable (its description can be read)")
	var normal_color: Color = ui.character_skill_db.get_skill_color(popup.available_skills[found], ally.get("inner_force", {})) if found >= 0 else Color.WHITE
	var shown_color: Color = popup.skill_list.get_item_custom_fg_color(found) if found >= 0 else Color.WHITE
	_expect(found >= 0 and shown_color.s <= normal_color.s and shown_color.v < normal_color.v, "short of MP, it is shown in a muted colour")
	popup.skill_list.select(found)
	popup._on_SkillList_item_selected(found)
	_expect(popup.confirm_button.disabled, "it cannot be confirmed")
	_expect(popup.description_label.text.contains("內力不足：需要 %d，目前 %d" % [cost, cost - 1]), "the description says how much is needed and how much there is")
	if not free.is_empty():
		var free_index: int = -1
		for index: int in range(popup.skill_list.item_count):
			if String(popup.available_skills[index].get("id", "")) == String(free.get("id", "")):
				free_index = index
		_expect(free_index >= 0 and String(popup.unusable_reasons[free_index]) == "", "a free skill is not refused")
	# enough MP: the same skill is fine
	ally["mp"] = cost
	popup.show_skills(skills, ally.get("inner_force", {}), ui.character_skill_db, ["劍", "刀", "拳", "掌", "棍", "槍", "筆", "琴"], ally)
	popup.skill_list.select(found)
	popup._on_SkillList_item_selected(found)
	_expect(not popup.confirm_button.disabled and String(popup.unusable_reasons[found]) == "", "with enough MP it can be confirmed, nothing muted")
	popup.hide()

	# --- the controller refuses a skill it cannot pay for: nothing spent, no turn used
	ally["mp"] = cost - 1
	ally["acted_this_turn"] = false
	var manager: Node = controller.turn_manager
	var index_before: int = int(manager.current_index)
	var round_before: int = int(manager.round_count)
	await controller.execute_action(ally, costly, foe)
	_expect(int(ally.mp) == cost - 1, "a refused skill takes no MP")
	_expect(not bool(ally.get("acted_this_turn", false)), "...and does not use the actor's action")
	_expect(String(controller.last_action_rejection) == "mp", "the controller says why it refused")
	_expect(int(manager.current_index) == index_before and int(manager.round_count) == round_before, "...and the ADB did not move")

	# --- the UI flow: a refused skill goes back to the list and the character can still act
	var completed: Array = [0]
	ui.player_action_complete.connect(func(_actor: Dictionary) -> void: completed[0] += 1)
	ui.on_action_selection = false
	await ui._apply_skill_and_finish_turn(ally, costly, foe)
	_expect(completed[0] == 0, "the turn was not ended after a refused skill")
	_expect(ui.on_action_selection, "the character is still choosing")
	_expect(ui._menu == "skill" or popup.visible, "the skill list is open again")
	_expect(int(ally.mp) == cost - 1, "still no MP spent")
	# --- and the second look in the UI (the list's own pre-check is bypassed on purpose)
	var skipped: Array = [0]
	ui.player_action_complete.connect(func(_actor: Dictionary) -> void: skipped[0] += 1)
	ui._on_PopupSkillSelect_skill_selected(costly)
	_expect(ui.pending_skill.is_empty() and ui.on_action_selection, "confirming an unaffordable skill straight from outside the list is refused as well")
	_expect(skipped[0] == 0, "...without ending the turn")
	# a skill that can be paid for still runs normally
	controller.action_log_ui = null   # nobody is there to click through the log in this test
	ally["mp"] = cost + 5
	await controller.execute_action(ally, costly, foe)
	_expect(String(controller.last_action_rejection) == "" and int(ally.mp) == 5, "with enough MP the skill runs and its cost is taken (%d left)" % int(ally.mp))
	_completed += 1
