extends SceneTree
## Integration checks use copied dictionaries and the isolated preview controller.
## Run explicitly with --headless --path . --script tests/test_combat_stage_25d.gd.

var PrototypeScene: PackedScene
var SkillDBScript: Script
const SkillExecutorScript := preload("res://scripts/battlescripts/SkillExecutor.gd")
const ForceDBScript := preload("res://scripts/battlescripts/InnerForceDB.gd")

var _failures: Array[String] = []
var _assertions: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Load scripts referencing project autoloads only after those exist.
	PrototypeScene = load("res://scenes/presentation/combat_stage_prototype.tscn")
	SkillDBScript = load("res://scripts/db/SkillDB.gd")
	var team: Node = root.get_node("TeamData")
	var state: Node = root.get_node("GlobalState")
	var inventory: Node = root.get_node("InventorySync")
	# The production equipment getter lazily creates an empty actor slot map.
	# Normalize that cache before measuring grants/equipment changes.
	inventory.get_equipped("liuyu")
	var original_team: Dictionary = team.export_team_state().duplicate(true)
	var original_inventory: Dictionary = inventory.export_inventory_state().duplicate(true)
	var original_force_meta: Variant = state.get_meta("inner_force_ids", {}).duplicate(true)
	var pending_sentinel := {"battle_id": "do_not_consume_preview_sentinel"}
	var had_pending: bool = state.has_meta("pending_battle_context")
	var prior_pending: Variant = state.get_meta("pending_battle_context") if had_pending else null
	state.set_meta("pending_battle_context", pending_sentinel)
	await _check_battle_entrypoint_modes(state, pending_sentinel)

	var fixture: Node = PrototypeScene.instantiate()
	fixture.auto_start = false
	root.add_child(fixture)
	for frame: int in range(30):
		if fixture.prepared:
			break
		await process_frame
	_expect(fixture.prepared, "standalone fixture prepares without starting campaign battle")
	if fixture.prepared:
		await _check_presentation_and_combat(fixture)
		await _check_target_contract(fixture)
		await _check_real_command_cycle(fixture)
		_expect(state.get_meta("pending_battle_context", {}) == pending_sentinel, "fixture preserves another pending battle context")
		_expect(team.export_team_state() == original_team, "fixture and inner-force switch preserve canonical team")
		_expect(inventory.export_inventory_state() == original_inventory, "preview victory grants no gold/items and preserves equipment")
		_expect(state.get_meta("inner_force_ids", {}) == original_force_meta, "fixture inner-force switch preserves global mapping")
	fixture.queue_free()
	await process_frame
	if had_pending:
		state.set_meta("pending_battle_context", prior_pending)
	else:
		state.remove_meta("pending_battle_context")
	if _failures.is_empty():
		print("PASS: ", _assertions, " assertions; 2.5D binding, picking, combat turns and preview isolation")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		quit(1)


func _check_presentation_and_combat(fixture: Node) -> void:
	var context: Dictionary = fixture.build_preview_context()
	var actor: Dictionary = context.player_party[0]
	var enemy: Dictionary = context.enemy_party[0]
	enemy["is_enemy"] = true
	enemy["battle_uid"] = "preview_enemy#0"
	var ui: Node = fixture.ui
	var controller: Node = fixture.controller
	controller.player_party = [actor]
	controller.enemy_party = [enemy]
	controller.ruleset = context.ruleset
	ui.set_teams([actor], [enemy])
	ui.apply_ruleset(context.ruleset)
	var stage: Node3D = ui.stage
	var ally_card: Node3D = stage.card_for(actor)
	var enemy_card: Node3D = stage.card_for(enemy)
	_expect(ally_card != null and enemy_card != null, "actor dictionaries resolve to distinct stage cards")
	_expect(stage.cards.size() == 6, "stage preserves three fixed slots per side")
	var empty_count := 0
	for card: Node3D in stage.cards.values():
		if card.actor_id.is_empty():
			empty_count += 1
			_expect(card.visible and card.hp_label.text.is_empty() and card.status_label.text.is_empty(), "empty slots retain visible frames without actor content")
	_expect(empty_count == 4, "one versus one retains four empty frames")
	_expect(stage.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "camera uses perspective")
	_expect(ally_card.home_position.z > enemy_card.home_position.z, "party and enemy use distinct depth bands")
	_expect(ally_card.home_rotation.y > 0 and enemy_card.home_rotation.y < 0, "card yaw is mirrored")
	_expect(stage.gaze_offset(Vector2(0.5, 0.5)) == Vector2.ZERO, "camera remains still in the gaze dead zone")
	_expect(stage.gaze_offset(Vector2(1.0, 0.5)).x > 0, "camera gaze responds at screen edge")
	_expect(stage.command_tray.COMMAND_IDS == ["skill", "inner_force", "item", "defend"], "command tray contains only four approved commands")
	_expect(ally_card.hp_label.text.contains(str(actor.hp)), "card HP reads actor runtime resource")
	_expect(ally_card.mp_label.text.contains(str(actor.mp)), "card MP reads actor runtime resource")
	_expect(enemy_card.species_label.visible and not enemy_card.mp_label.visible, "enemy card shows species and no MP row")
	var force_db: Node = ForceDBScript.new()
	var force: Dictionary = force_db.get_force("liuchen_jue")
	_expect(controller.apply_inner_force_switch(actor, force), "real inner-force switch can operate on preview TeamData")
	ui.update_ally_panel()
	ally_card = stage.card_for(actor)
	_expect(ally_card.element_label.text == String(force.get("element", "")), "party badge displays active inner-force element")
	_expect(ally_card.force_label.text.replace("\n", "").contains("流塵"), "party vertical text displays active inner force")
	force_db.free()
	actor["status_effects"] = {"atk_up": {"payload": {"atk_delta": 7}, "turns_left": 3}, "blind": {"turns_left": 3}}
	ui.update_ally_status(0, actor)
	_expect(ally_card.status_label.text.contains("攻") and ally_card.status_label.text.contains("盲"), "stage reuses production buff/debuff abbreviations")
	_expect(ally_card.status_label.position.y == ally_card.level_label.position.y, "buff/debuff abbreviations share the LV row")
	actor["status_effects"].clear()
	ui.update_ally_status(0, actor)
	_expect(ally_card.status_label.text.is_empty(), "removed statuses do not remain on the card")

	await process_frame
	var rectangles: Array = stage.command_tray.get_button_screen_rects(stage.camera)
	_expect(rectangles.size() == 4, "all four commands expose screen picking bounds")
	for index: int in range(rectangles.size()):
		var rect: Rect2 = rectangles[index]
		_expect(stage.command_tray.pick(stage.camera, rect.get_center()) == index, "ray picking resolves command %d" % index)
	stage.command_tray.set_hover(0)
	await create_timer(0.3).timeout
	_expect(stage.command_tray._buttons[0].position.z > stage.command_tray._homes[0].z, "hover moves the selected command toward the camera")
	_expect(stage.command_tray._buttons[0].scale == Vector3.ONE, "hover does not resize font through Control/card scale")
	_expect(stage.command_tray._buttons[1].position.x > stage.command_tray._homes[1].x, "hover pushes the neighboring command aside")
	stage.command_tray.set_hover(-1)
	ally_card.attack_motion(enemy_card.home_position)
	await create_timer(0.22).timeout
	_expect(ally_card.position.x > ally_card.home_position.x and ally_card.position.z < ally_card.home_position.z, "card attack actually advances in X and Z")
	await create_timer(0.5).timeout
	enemy_card.hit_reaction()
	await create_timer(0.08).timeout
	_expect(enemy_card.position.z < enemy_card.home_position.z and not is_zero_approx(enemy_card.rotation.x) and not is_zero_approx(enemy_card.rotation.z), "impact combines knockback with pitch and roll")
	await create_timer(0.7).timeout
	_expect(enemy_card.position.is_equal_approx(enemy_card.home_position), "impact recovery returns to its own home transform")
	var miss_trail: Node3D = load("res://scripts/presentation/SwordTrail3D.gd").new()
	stage.fx_root.add_child(miss_trail)
	await miss_trail.play(ally_card.home_position, enemy_card.home_position, false)
	_expect(miss_trail.last_endpoint.z < enemy_card.home_position.z and miss_trail.path_history.size() > 2, "MISS ribbon really travels behind the enemy plane")
	miss_trail.queue_free()

	var db: Node = SkillDBScript.new()
	var executor: Node = SkillExecutorScript.new()
	var skill: Dictionary = db.get_skill("skill_lianjuejian").duplicate(true)
	skill["power"] = float(skill.effects[0].power)
	var attack_actor: Dictionary = actor.duplicate(true)
	attack_actor["weapon_1"] = "劍"
	attack_actor["accuracy"] = 10000
	attack_actor["crit_rate"] = 0.0
	attack_actor["battle_base_atk"] = 40
	attack_actor["atk"] = 999
	attack_actor["status_effects"] = {"atk_up": {"payload": {"atk_delta": 7}, "turns_left": 3}}
	var hit: Dictionary = {}
	var target: Dictionary = {}
	for attempt: int in range(64):
		target = enemy.duplicate(true)
		hit = executor.execute(attack_actor, target, skill, {})
		if bool(hit.hit):
			break
	_expect(bool(hit.get("hit", false)), "production Executor yields a hit with high accuracy")
	_expect(int(hit.get("effective_atk", 0)) == 47, "damage uses battle baseline plus runtime status, not stale presentation ATK")
	_expect(int(target.hp) == maxi(0, int(enemy.hp) - int(hit.damage)), "real hit reduces runtime HP by resolved damage")
	var before_visual: Dictionary = enemy.duplicate(true)
	await stage.present_attack(actor, enemy, skill, hit)
	_expect(enemy == before_visual, "stage hit animation cannot mutate combat resource dictionaries")
	attack_actor["accuracy"] = -10000
	var miss: Dictionary = {}
	for attempt: int in range(64):
		target = enemy.duplicate(true)
		miss = executor.execute(attack_actor, target, skill, {})
		if not bool(miss.hit):
			break
	_expect(not bool(miss.get("hit", true)), "production Executor yields a real miss")
	_expect(int(target.hp) == int(enemy.hp) and int(miss.damage) == 0, "miss preserves target HP")
	await stage.present_attack(actor, enemy, skill, miss)
	_expect(enemy == before_visual and not stage.busy, "miss visual completes without damage or stuck action")
	ui.set_stage_enabled(false)
	_expect(not ui.stage_enabled, "legacy presentation is selectable")
	_expect(ui.ally_panel.visible and ui.enemy_panel.visible and ui.log_panel.visible and not stage.visible, "legacy panels/log restore without a second combat state")
	ui.set_stage_enabled(true)
	_expect(ui.stage_enabled, "stage presentation can be restored")
	controller._begin_end_battle("victory")
	_expect(controller.battle_finished, "preview victory terminates without reward pipeline")
	executor.style.free()
	executor.tone.free()
	executor.free()
	db.free()


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _check_target_contract(fixture: Node) -> void:
	var ui: Node = fixture.ui
	var controller: Node = fixture.controller
	controller._ending = false
	controller.battle_finished = false
	var context: Dictionary = fixture.build_preview_context()
	var actor: Dictionary = context.player_party[0]
	var first: Dictionary = context.enemy_party[0]
	first["is_enemy"] = true
	first["battle_uid"] = "same_species#0"
	var second: Dictionary = first.duplicate(true)
	second["battle_uid"] = "same_species#1"
	var dead: Dictionary = first.duplicate(true)
	dead["battle_uid"] = "same_species#2"
	dead["hp"] = 0
	controller.player_party = [actor]
	controller.enemy_party = [first, second, dead]
	ui.set_teams(controller.player_party, controller.enemy_party)
	ui._opening_overlay.hide()
	ui._battle_black_overlay.hide()
	ui.begin_turn(actor)
	await process_frame
	ui._sync_input_state()
	ui.dispatch_stage_command("skill")
	_expect(ui.skill_list_popup.visible and ui.skill_list_popup.skill_list is ItemList, "skill menu is the actual production ItemList")
	ui.select_stage_option(0)
	var resources := Vector2i(actor.hp, actor.mp)
	ui.select_stage_option(ui._option_actions.find("confirm"))
	_expect(ui.target_picker.candidates.size() == 2, "target picker excludes defeated actors")
	var point: Vector2 = ui.stage.card_screen_rect(second).get_center()
	ui.target_picker._update_pointer(point)
	_expect(ui.stage.card_for(second)._target_frame.visible and not ui.stage.card_for(first)._target_frame.visible, "hover selects distinct battle UID, not same-species ID")
	ui.target_picker.select_at(point)
	_expect(ui.target_picker.selected.get("battle_uid", "") == second.battle_uid, "target click resolves the actual second actor")
	_expect(Vector2i(actor.hp, actor.mp) == resources, "target click opens confirmation without executing")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = point
	root.push_input(right, true)
	_expect(ui.target_picker.state == ui.target_picker.State.PICKING, "right-click confirmation goes back one layer")
	root.push_input(right, true)
	_expect(ui.skill_list_popup.visible and ui.skill_list_popup.selected_index == 0, "right-click target state restores original skill selection")
	ui.skill_list_popup._on_Cancel_pressed()
	_expect(ui._menu.is_empty() and not ui.target_picker.active and ui.pending_skill.is_empty(), "skill cancellation returns to main command without stale pending skill")
	for definition: Dictionary in [{"target_scope": "enemy_all", "target_side": "enemy"}, {"target_scope": "single", "target_side": "ally"}, {"target_scope": "single", "target_side": "self"}]:
		ui.pending_skill = definition
		ui.pending_skill_user = actor
		ui._start_target_select_for_skill(actor, definition)
		_expect(ui.target_picker.active, "AoE/ally/self skills also wait for explicit target confirmation")
		_expect(ui.target_picker.candidates.size() == (2 if definition.target_side == "enemy" else 1), "target side eligibility stays production-compatible")
		ui.target_picker.cancel_layer()
		ui.skill_list_popup._on_Cancel_pressed()
	var card: Node = ui.stage.card_for(first)
	_expect(card.card_viewport.size == Vector2i(1280, 600) and card.card_viewport.size_2d_override == Vector2i(640, 300), "enemy text renders at double source resolution")
	_expect(card.scale == Vector3.ONE and ui.stage.card_for(second).scale == Vector3.ONE, "multiple enemies do not shrink their text by card scale")
	var font: Font = load("res://assets/fonts/DotGothic16-Regular.ttf")
	_expect(card.name_label.get_theme_font("font") == font and card.hp_label.get_theme_font("font") == font, "enemy name and HP use the specified font")
	_expect(ui.log_panel.get_theme_font("normal_font") == font and ui.skill_list_popup.skill_list.get_theme_font("font") == font, "logs and ItemList use the specified font")
	var box: PanelContainer = ui._actor_bubble_boxes[ui._get_bubble_key_for_slot(ui.enemy_slots[1])]
	ui._position_bubble_on_portrait(ui.enemy_slots[1], box)
	var card_rect: Rect2 = ui.stage.card_screen_rect(second)
	_expect(box.global_position.x + box.size.x <= card_rect.position.x, "OS bubble sits beside its matching enemy without covering its card")
	_expect(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(Rect2(box.global_position, box.size)), "OS bubble remains inside the safe viewport")
	ui.pending_skill = {"target_scope": "single", "target_side": "enemy"}
	ui.pending_skill_user = actor
	ui.on_action_selection = false
	ui._start_target_select_for_skill(actor, ui.pending_skill)
	ui.target_picker.select_at(point)
	var f8 := InputEventKey.new()
	f8.keycode = KEY_F8
	f8.pressed = true
	root.push_input(f8, true)
	_expect(not ui.stage_enabled and not ui.target_picker.active and ui.pending_skill.is_empty() and ui.on_action_selection, "F8 during confirmation safely restores legacy commands without executing")
	_expect(ui.ally_slots[0].get_node("StatusUI/Name").get_theme_font("font") == font, "F8 legacy actor labels retain DotGothic16")
	root.push_input(f8, true)
	_expect(ui.stage_enabled, "F8 restores stage after cancelling the pending target")


func _check_battle_entrypoint_modes(state: Node, sentinel: Dictionary) -> void:
	# Exercise the production mode-selection hook without launching an encounter.
	state.remove_meta("pending_battle_context")
	var scene: PackedScene = load("res://scenes/battle_scene.tscn")
	for mode: int in [1, 0]:
		var battle: Node = scene.instantiate()
		battle.presentation_mode = mode
		root.add_child(battle)
		await process_frame
		await process_frame
		var battle_ui: Node = battle.get_node("BattleUILayer/BattleUI")
		var script_path: String = battle_ui.get_script().resource_path
		_expect(script_path.ends_with("/StageBattleUI.gd") if mode == 1 else script_path.ends_with("/BattleUI.gd"), "battle entry selects correct UI script for mode %d" % mode)
		var controller_path: String = battle.get_node("BattleController").get_script().resource_path
		_expect(controller_path.ends_with("/StageBattleController.gd") if mode == 1 else controller_path.ends_with("/BattleController.gd"), "battle entry selects correct controller for mode %d" % mode)
		battle.queue_free()
		await process_frame
	state.set_meta("pending_battle_context", sentinel)


func _check_real_command_cycle(fixture: Node) -> void:
	fixture.auto_start = true
	await fixture._restart_preview()
	var ui: Node = fixture.ui
	var controller: Node = fixture.controller
	ui.log_panel._chars_per_sec = 1000000.0
	var commands: Array[String] = ["inner_force", "defend", "skill"]
	var issued: int = 0
	var handoffs: Array = []
	ui.player_action_complete.connect(func(actor: Dictionary): handoffs.append(actor.id))
	var before_hp: int = int(controller.enemy_party[0].hp)
	var before_skill_mp: int = -1
	var deadline: int = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline and not controller.battle_finished:
		if ui._battle_opening_waiting_confirm:
			ui.battle_opening_confirmed.emit()
		if ui.log_panel._waiting_for_continue:
			ui._accept_checkpoint()
		if ui.log_panel.waiting_for_message_advance(): ui._accept_checkpoint()
		if ui.stage.input_enabled and ui._menu.is_empty() and issued < commands.size() and not ui.log_panel._typing:
			var command: String = commands[issued]
			var command_index: int = ui.stage.command_tray.COMMAND_IDS.find(command)
			var rect: Rect2 = ui.stage.command_tray.get_button_screen_rects(ui.stage.camera)[command_index]
			var click := InputEventMouseButton.new()
			click.position = rect.get_center()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			# Push viewport-local coordinates through normal GUI/unhandled routing;
			# headless has no OS window position for Input's screen conversion.
			root.push_input(click, true)
			var release := click.duplicate() as InputEventMouseButton
			release.pressed = false
			root.push_input(release, true)
			await create_timer(0.3).timeout
			_expect(ui._menu == command, "3D %s opens its production-backed submenu" % command)
			if ui._menu != command:
				break
			_expect(not ui._menu_description.text.is_empty(), "submenu has readable description")
			if command != "defend":
				_expect(ui._menu_list().item_count > 0, "production %s supplies eligible choices" % command)
				ui.select_stage_option(0)
			if command == "skill":
				before_skill_mp = int(ui.current_actor.mp)
			ui.select_stage_option(ui._option_actions.find("confirm"))
			if command == "skill":
				_expect(ui.target_picker.active and ui._menu == "target", "single enemy still requires target selection")
				_expect(int(ui.current_actor.mp) == before_skill_mp, "skill confirmation alone spends no MP")
				var point: Vector2 = ui.stage.card_screen_rect(controller.enemy_party[0]).get_center()
				ui.target_picker.select_at(point)
				_expect(ui.target_picker.state == ui.target_picker.State.CONFIRMING, "clicking target opens a separate confirmation")
				ui.target_picker.cancel_layer()
				_expect(ui.target_picker.state == ui.target_picker.State.PICKING and not ui.pending_skill.is_empty(), "confirmation cancellation retains the selected skill")
				ui.target_picker.cancel_layer()
				_expect(ui.skill_list_popup.visible and ui.skill_list_popup.selected_index == 0, "target cancellation restores selected ItemList entry")
				ui.skill_list_popup._on_Confirm_pressed()
				ui.target_picker.select_at(point)
				ui.target_picker.confirm_target()
			issued += 1
		if issued == 3 and handoffs.size() == 3 and not ui.stage.busy:
			break
		await process_frame
	_expect(issued == 3 and handoffs.size() == 3, "inner force, defense, skill each hand off exactly one real turn")
	# A legitimate roll can miss all three strikes. Resource cost + resolved
	# hit/miss logs prove execution without redefining the production hit formula.
	_expect(int(controller.player_party[0].mp) < before_skill_mp, "stage-selected skill pays its production MP cost")
	var resolved_logs: String = ui.log_panel.get_parsed_text()
	_expect(int(controller.enemy_party[0].hp) < before_hp or resolved_logs.contains("沒有命中"), "stage-selected skill resolves real hit/miss outcomes")
	_expect(not ui.btn_inner_force.visible and not ui.btn_item.visible, "ruleset cannot expose legacy buttons over stage")
	_expect(not ui.stage.command_tray._allowed.item, "preview inventory remains disabled")
	print("COMMAND CYCLE: issued=", issued, " handoffs=", handoffs.size())
	controller._begin_end_battle("victory")
