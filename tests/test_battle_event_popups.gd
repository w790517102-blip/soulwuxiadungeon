extends SceneTree
## Battle Event Presentation: damage numbers that accumulate over the strikes of one action (25 -> 50 -> 75 -> 100) and
## fall only after the last, MISS / 格擋 / 攔截 / 無效 instead of 0, status tags with an icon when the art exists and the
## word alone when it does not, announcements, healing, and one number per target in an area attack.
## Run: --headless --path . --script tests/test_battle_event_popups.gd

const BattleEvent = preload("res://scripts/presentation/BattleEvent.gd")
const Presenter = preload("res://scripts/presentation/BattleEventPresenter.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _wait(seconds: float) -> void:
	var start: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - start) < seconds * 1000.0:
		await process_frame


func _run() -> void:
	var fixture: Node = (load("res://scenes/presentation/card_stage_prototype.tscn") as PackedScene).instantiate()
	fixture.auto_start = false
	root.add_child(fixture)
	for frame: int in range(30):
		if fixture.prepared:
			break
		await process_frame
	_expect(fixture.prepared, "the card stage prepares")
	if fixture.prepared:
		_check_pure()
		await _check_presenter(fixture)
		await _check_stage(fixture)
		await _check_image_digits(fixture)
		await _check_sheath_strike(fixture)
		await _check_banners_and_motion(fixture)
		await _check_anchors(fixture)
		await _check_round_title(fixture)
	fixture.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS: battle event popups")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		quit(1)


## Data only: what each strike is, and the style that follows.
func _check_pure() -> void:
	var plan: Array = Presenter.plan_strikes([
		{"hit": true, "damage": 42},
		{"hit": false},
		{"hit": true, "blocked": true, "blocker_type": "substitute_talisman"},
		{"hit": true, "blocked": true, "blocker_type": "sheath_card"},
		{"hit": true, "damage_prevented": true, "damage": 0},
		{"hit": true, "damage": 0},
		{"hit": true, "damage": 120, "crit": true, "element_advantage": true},
	])
	var kinds: Array[String] = []
	for entry: Dictionary in plan:
		kinds.append(String(entry.kind))
	_expect(kinds == ["damage", "miss", "intercept", "block", "nullified", "nullified", "damage"], "strikes classify without ever making a 0: " + str(kinds))
	_expect(String(plan[6].result_type) == "CRITICAL_COUNTER", "crit + counter is one result type")
	var normal: Dictionary = Presenter.style_for(BattleEvent.NORMAL_HIT)
	var counter: Dictionary = Presenter.style_for(BattleEvent.COUNTER_HIT)
	var crit: Dictionary = Presenter.style_for(BattleEvent.CRITICAL_HIT)
	var both: Dictionary = Presenter.style_for(BattleEvent.CRITICAL_COUNTER_HIT)
	_expect(normal.color.r > 0.9 and normal.color.g > 0.85 and normal.color.b < 0.8 and normal.color.b > 0.4, "a normal hit is cream yellow, not pure white")
	_expect(counter.color.s > normal.color.s and counter.color.g > 0.75 and counter.color.b < 0.3, "a counter hit is saturated gold")
	_expect(crit.color.r > 0.9 and crit.color.g < 0.3 and int(crit.size) > int(normal.size) and float(crit.power) > float(normal.power), "a critical hit is red, bigger, with a stronger punch")
	_expect(both.color == crit.color and both.size == crit.size, "first version: crit + counter is drawn as a crit (red)")
	var stun: Dictionary = BattleEvent.status("stun", true)
	_expect(String(stun.primary_text) == "暈眩" and String(stun.icon_key) == "status_stun", "a status event reuses the status icon key and word: %s / %s" % [stun.primary_text, stun.icon_key])
	_expect(BattleEvent.texture_for("status_poison") != null, "an existing status icon is found")
	_expect(BattleEvent.texture_for("event_immune") == null, "event art that does not exist yet is simply absent")
	for key: String in ["event_type", "icon_key", "primary_text", "value", "target", "source", "priority", "duration"]:
		_expect(BattleEvent.make(BattleEvent.MISS).has(key), "an event carries " + key)


func _check_presenter(fixture: Node) -> void:
	var presenter: Node = Presenter.new()
	fixture.add_child(presenter)
	var foe_a: Dictionary = {"battle_uid": "pop_a", "name": "甲"}
	var foe_b: Dictionary = {"battle_uid": "pop_b", "name": "乙"}
	# Case B/C: four strikes, one popup: 25 -> 50 -> 75 -> 120 (third a counter, fourth a crit)
	var result: Dictionary = {"strikes": [
		{"hit": true, "damage": 25},
		{"hit": true, "damage": 25},
		{"hit": true, "damage": 25, "element_advantage": true},
		{"hit": true, "damage": 45, "crit": true},
	]}
	var sequence_id: String = presenter.schedule_strikes(foe_a, result, 0.05, 0.12)
	_expect(sequence_id != "", "a damaging action gets a sequence id")
	await _until(presenter, 1)
	_expect(presenter.current_number_text(sequence_id) == "25!", "first strike: 25 (got %s)" % presenter.current_number_text(sequence_id))
	await _until(presenter, 2)
	_expect(presenter.current_number_text(sequence_id) == "50!", "second strike updates the SAME number to 50 (got %s)" % presenter.current_number_text(sequence_id))
	_expect(presenter.open_sequence_count() == 1, "one sequence while the strikes come in")
	await _until(presenter, 3)
	_expect(presenter.current_number_text(sequence_id) == "75!", "third strike: 75")
	_expect(presenter.has_open_sequence(sequence_id), "...and it is still hanging, not falling")
	await _until(presenter, 4)
	_expect(not presenter.has_open_sequence(sequence_id), "the last strike closes the sequence (it falls from here)")
	var numbers: Array[String] = []
	var types: Array[String] = []
	for entry: Dictionary in presenter.history:
		numbers.append(String(entry.text))
		types.append(String(entry.get("result_type", "")))
	_expect(numbers == ["25!", "50!", "75!", "120!"], "25! -> 50! -> 75! -> 120! (cumulative): " + str(numbers))
	_expect(types == ["NORMAL", "NORMAL", "COUNTER", "CRITICAL"], "each strike's own look: " + str(types))
	_expect(bool(presenter.history[3].final) and not bool(presenter.history[2].final), "only the last strike is final")
	_expect(presenter.get_child_count() == 1, "one popup node for the whole action (%d)" % presenter.get_child_count())
	await _wait(1.9)
	_expect(presenter.get_child_count() == 0, "the number falls and fades away by itself (%d left)" % presenter.get_child_count())
	# Case A: a single strike is its own first and final
	presenter.history.clear()
	var single: String = presenter.schedule_strikes(foe_a, {"hit": true, "damage": 42}, 0.0, 0.0)
	_expect(single != "" and presenter.history.size() == 1 and String(presenter.history[0].text) == "42!" and bool(presenter.history[0].final), "a single strike: 42, first and final at once")
	_expect(not presenter.has_open_sequence(single), "...and nothing is left hanging")
	await _wait(1.9)
	# Case E / F: MISS, 攔截 and 格擋 show words, never 0
	presenter.history.clear()
	presenter.schedule_strikes(foe_a, {"hit": false}, 0.0, 0.0)
	presenter.schedule_strikes(foe_a, {"strikes": [{"blocked": true, "blocker_type": "substitute_talisman", "hit": false}]}, 0.0, 0.0)
	presenter.schedule_strikes(foe_b, {"strikes": [{"blocked": true, "blocker_type": "sheath_card", "hit": true}]}, 0.0, 0.0)
	var words: Array[String] = []
	for entry: Dictionary in presenter.history:
		words.append(String(entry.text))
	_expect(words == ["MISS", "攔截", "格擋"], "words instead of 0: " + str(words))
	_expect(not words.has("0"), "no 0 is ever shown")
	await _wait(1.5)
	# a mixed action: miss, hit, hit
	presenter.history.clear()
	presenter.schedule_strikes(foe_a, {"strikes": [{"hit": false}, {"hit": true, "damage": 30}, {"hit": true, "damage": 30}]}, 0.0, 0.0)
	var mixed: Array[String] = []
	for entry: Dictionary in presenter.history:
		mixed.append(String(entry.text))
	_expect(mixed == ["MISS", "30!", "60!"], "a miss does not disturb the count: " + str(mixed))
	await _wait(1.9)
	# Case G: statuses - the icon when the art exists, the word when it does not, never nothing
	presenter.history.clear()
	presenter.show_event(BattleEvent.status("poison", true, foe_a))
	presenter.show_event(BattleEvent.status("made_up_status", true, foe_a))
	_expect(presenter.history.size() == 2, "both statuses are shown")
	_expect(String(presenter.history[0].text) == "中毒" and String(presenter.history[0].icon) == "status_poison", "poison: icon + 中毒")
	_expect(String(presenter.history[1].text) == "made_up_status" and String(presenter.history[1].icon) == "", "no art: the word alone, still shown")
	_expect(presenter.get_child_count() == 2, "...and both have something on screen")
	await _wait(1.9)
	# Case H: an announcement is not a number popup
	presenter.history.clear()
	presenter.announce("第 3 回合開始")
	_expect(presenter.history.size() == 1 and String(presenter.history[0].type) == BattleEvent.ANNOUNCE and String(presenter.history[0].text) == "第 3 回合開始", "round start is an announcement")
	_expect(presenter.open_sequence_count() == 0, "...and opens no damage sequence")
	await _wait(2.0)
	# healing is a number of its own kind
	presenter.history.clear()
	presenter.show_heal(BattleEvent.heal_event(foe_a, 45))
	_expect(String(presenter.history[0].type) == BattleEvent.HEAL and String(presenter.history[0].text) == "+45", "healing reads +45")
	await _wait(1.6)
	# an area attack: each target its own number, no shared total
	presenter.history.clear()
	var entries: Array = []
	for pair: Array in [[foe_a, 40], [foe_b, 100], [foe_a, 35], [foe_b, 2]]:
		entries.append({"target": pair[0], "strike": {"hit": true, "damage": pair[1]}})
	var made: Dictionary = presenter.schedule_run(entries, 0.0, 0.0)
	_expect(made.size() == 2 and made["pop_a"] != made["pop_b"], "two targets, two sequences")
	var by_target: Dictionary = {}
	for entry: Dictionary in presenter.history:
		var name: String = String(entry.target.name)
		by_target[name] = (by_target.get(name, []) as Array) + [String(entry.text)]
	_expect(by_target.get("甲", []) == ["40!", "75!"] and by_target.get("乙", []) == ["100!", "102!"], "each target adds up on its own: " + str(by_target))
	await _wait(1.9)
	presenter.queue_free()


## Through the stage: an attack's result reaches the renderer by the attack's own timing, an intercepted attack says 攔截.
func _check_stage(fixture: Node) -> void:
	var ui: Node = fixture.ui
	var stage: Node3D = ui.stage
	_expect(ui.event_presenter != null and stage.event_presenter == ui.event_presenter, "the UI owns a presenter and gives it to the stage")
	var context: Dictionary = fixture.build_preview_context()
	var ally: Dictionary = (context.player_party[0] as Dictionary).duplicate(true)
	var foe: Dictionary = (context.enemy_party[0] as Dictionary).duplicate(true)
	ally["battle_uid"] = "pop_ally"
	foe["battle_uid"] = "pop_foe"
	foe["is_enemy"] = true
	ui.set_teams([ally], [foe])
	for frame: int in range(10):
		await process_frame
	var presenter: Node = ui.event_presenter
	presenter.history.clear()
	var skill: Dictionary = {"id": "x", "name": "測試連擊", "weapon_type": "劍"}
	var result: Dictionary = {"hit": true, "damage": 60, "strikes": [{"hit": true, "damage": 20}, {"hit": true, "damage": 20}, {"hit": true, "damage": 20}]}
	stage._show_attack_popups(foe, skill, result, {})
	await _wait(1.6)
	var texts: Array[String] = []
	for entry: Dictionary in presenter.history:
		texts.append(String(entry.text))
	_expect(texts == ["20!", "40!", "60!"], "the stage feeds a sword combo to the renderer: " + str(texts))
	_expect(stage._popup_timing(skill, result).x > 0.2, "the first blow of a sword arrives after the lunge")
	presenter.history.clear()
	stage._show_attack_popups(foe, skill, {"hit": false}, {"type": "substitute_talisman", "entity_id": "e"})
	await _wait(1.2)
	_expect(presenter.history.size() == 1 and String(presenter.history[0].text) == "攔截", "an intercepted attack says 攔截 (not 0)")
	presenter.history.clear()
	ui.play_heal_number(ally, 30)
	ui.play_heal_number(ally, 0)
	ui.play_status_event(foe, "stun", true)
	ui.announce_round(4)
	var shown: Array[String] = []
	for entry: Dictionary in presenter.history:
		shown.append(String(entry.text))
	_expect(shown == ["+30", "暈眩", "第 4 回合開始"], "the UI entry points feed the presenter (and a heal of 0 shows nothing): " + str(shown))
	await _wait(2.0)


## Waits until the presenter has shown `count` entries (the timers run on real time, so counting beats guessing a delay).
func _until(presenter: Node, count: int) -> void:
	var start: int = Time.get_ticks_msec()
	while presenter.history.size() < count and Time.get_ticks_msec() - start < 3000:
		await process_frame


## Image digits: used when the whole style set exists, the text label otherwise; never nothing.
func _check_image_digits(fixture: Node) -> void:
	var NumberFont: Script = load("res://scripts/presentation/BattleNumberFont.gd")
	var presenter: Node = Presenter.new()
	fixture.add_child(presenter)
	var foe: Dictionary = {"battle_uid": "img_a", "name": "丙"}
	_expect(NumberFont.can_render("normal", "25!") and NumberFont.can_render("heal", "+45!"), "the delivered sheet covers every style")
	NumberFont.directory = "user://test_numbers/"
	NumberFont.reset_cache()
	DirAccess.make_dir_recursive_absolute("user://test_numbers/normal")
	var image := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	for name: String in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "plus", "bang"]:
		image.save_png("user://test_numbers/normal/%s.png" % name)
	NumberFont.reset_cache()
	_expect(NumberFont.can_render("normal", "25!"), "with the set present the style renders as images")
	_expect(not NumberFont.can_render("crit", "25!"), "a style whose set is missing keeps the text fallback")
	presenter.schedule_strikes(foe, {"hit": true, "damage": 25}, 0.0, 0.0)
	var rows: int = 0
	for child: Node in presenter.get_children():
		for part: Node in child.get_children():
			for inner: Node in part.get_children():
				if inner is HBoxContainer:
					rows += 1
	_expect(rows == 1, "the popup holds one image row")
	NumberFont.enabled = false
	_expect(not NumberFont.can_render("normal", "25!"), "the switch forces text")
	NumberFont.enabled = true
	NumberFont.directory = "res://assets/UI/card_stage/numbers/"
	NumberFont.reset_cache()
	await _wait(1.9)
	presenter.queue_free()


class FakeSheath:
	var entity_id: String = "fake_sheath"


## A sheath card's blow (one strike of a 持鞘 combo) shows its damage too.
func _check_sheath_strike(fixture: Node) -> void:
	var ui: Node = fixture.ui
	var stage: Node3D = ui.stage
	var context: Dictionary = fixture.build_preview_context()
	var foe: Dictionary = (context.enemy_party[0] as Dictionary).duplicate(true)
	foe["battle_uid"] = "sheath_foe"
	foe["is_enemy"] = true
	var ally: Dictionary = (context.player_party[0] as Dictionary).duplicate(true)
	ally["battle_uid"] = "sheath_ally"
	ui.set_teams([ally], [foe])
	for frame: int in range(10):
		await process_frame
	var stub := Node3D.new()
	var stub_script := GDScript.new()
	stub_script.source_code = "extends Node3D
var home_position := Vector3.ZERO
"
	stub_script.reload()
	stub.set_script(stub_script)
	stage.add_child(stub)
	stage.entity_cards["fake_sheath"] = stub
	var presenter: Node = ui.event_presenter
	presenter.history.clear()
	stage.present_sheath_strike(FakeSheath.new(), foe, {"hit": true, "damage": 33})
	await _until(presenter, 1)
	_expect(presenter.history.size() == 1 and String(presenter.history[0].text) == "33!", "the sheath card's blow shows its damage: " + str(presenter.history))
	await _wait(2.0)
	stage.entity_cards.erase("fake_sheath")
	stub.queue_free()


## Banners: event art that carries its own word is shown as the picture alone; the number now rises from low and falls back
## with two bounces.
func _check_banners_and_motion(fixture: Node) -> void:
	var presenter: Node = Presenter.new()
	fixture.add_child(presenter)
	var foe: Dictionary = {"battle_uid": "ban_a", "name": "丁"}
	_expect(BattleEvent.texture_for("event_miss") != null and BattleEvent.texture_for("event_block") != null and BattleEvent.texture_for("event_intercept") != null and BattleEvent.texture_for("event_nullified") != null, "the four delivered banners are found")
	presenter.show_event(BattleEvent.make(BattleEvent.MISS, foe))
	_expect(presenter.get_child_count() == 1, "a banner is one picture")
	var holder: Node = presenter.get_child(0)
	_expect(holder.get_child_count() == 1 and holder.get_child(0) is TextureRect, "...with no extra word beside it")
	presenter.history.clear()
	presenter.show_event(BattleEvent.make(BattleEvent.IMMUNE, foe))
	_expect(presenter.get_child_count() == 2 and presenter.get_child(1).get_child_count() == 1 and presenter.get_child(1).get_child(0) is Label, "an event without art keeps its word")
	await _wait(1.8)
	# the number: struck out of a low spot, hangs at a modest height, lands where it was struck
	_expect(Presenter.STRIKE_Y > Presenter.HOVER_Y and Presenter.HOVER_Y > 0.0, "the number starts low and hangs below the top of the card")
	_expect(is_equal_approx(Presenter.GROUND_Y, Presenter.STRIKE_Y), "it lands where it was struck")
	var sequence_id: String = presenter.schedule_strikes(foe, {"hit": true, "damage": 10}, 0.0, 0.0)
	var wrapper: Control = presenter.get_child(0)
	var lowest: float = -INF
	var highest: float = INF
	var bounces: int = 0
	var rising: bool = false
	var last_y: float = wrapper.position.y
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 1700 and is_instance_valid(wrapper):
		await process_frame
		if not is_instance_valid(wrapper):
			break
		var y: float = wrapper.position.y
		if Time.get_ticks_msec() - start > 600:
			if y < last_y - 0.5 and not rising:
				rising = true
				bounces += 1
			elif y > last_y + 0.5:
				rising = false
		last_y = y
	_expect(bounces == 2, "after landing it bounces twice (counted %d)" % bounces)
	presenter.queue_free()


## 攔截 belongs to the charm that took the blow; nothing flies off the screen.
func _check_anchors(fixture: Node) -> void:
	var presenter: Node = Presenter.new()
	fixture.add_child(presenter)
	var asked: Array = []
	presenter.entity_anchor_provider = func(entity_id: String) -> Rect2:
		asked.append(entity_id)
		return Rect2(400, 300, 100, 150)
	presenter.anchor_provider = func(_target: Dictionary) -> Rect2:
		return Rect2(-900, -900, 120, 180)
	var foe: Dictionary = {"battle_uid": "anc_a", "name": "戊"}
	presenter.schedule_strikes(foe, {"strikes": [{"blocked": true, "blocker_type": "substitute_talisman", "blocker_entity_id": "sub1", "hit": false}]}, 0.0, 0.0)
	_expect(asked == ["sub1"], "an interception is placed on the substitute card (asked for: %s)" % str(asked))
	presenter.schedule_strikes(foe, {"strikes": [{"blocked": true, "blocker_type": "sheath_card", "blocker_entity_id": "sheath1", "hit": true}]}, 0.0, 0.0)
	_expect(asked == ["sub1"], "a block stays on the protected character")
	# a card far outside the screen: tags and banners are pulled back inside
	presenter.show_event(BattleEvent.status("poison", true, foe))
	presenter.show_event(BattleEvent.make(BattleEvent.MISS, foe))
	var screen: Rect2 = presenter.get_viewport_rect()
	for holder: Node in presenter.get_children():
		if holder is Control:
			_expect(screen.has_point((holder as Control).position), "popups are kept on screen: " + str((holder as Control).position))
	await _wait(1.8)
	presenter.queue_free()


## 第 X 回合 / 開始: its own title, two phases, skippable, with a text fallback when the art is missing.
func _check_round_title(fixture: Node) -> void:
	var Title: Script = load("res://scripts/presentation/BattleRoundTitle.gd")
	var presenter: Node = Presenter.new()
	fixture.add_child(presenter)
	_expect(Title.available(), "the three title pieces are found")
	presenter.announce_round(3)
	var title: Node = presenter.current_round_title()
	_expect(title != null, "a round start makes a title (not a tag, not a number)")
	_expect(presenter.history.size() == 1 and String(presenter.history[0].type) == BattleEvent.ANNOUNCE and String(presenter.history[0].text) == "第 3 回合開始", "it is recorded as an announcement")
	await _wait(0.6)
	_expect(title.phase == 1 and title.get_child_count() >= 1, "phase 1 (第 3 回合) is up")
	var started: int = Time.get_ticks_msec()
	while title.phase < 2 and Time.get_ticks_msec() - started < 5000:
		await process_frame
	var gap: float = float(Time.get_ticks_msec() - started + 600) / 1000.0
	_expect(title.phase == 2, "then 開始 follows")
	_expect(absf(gap - (Title.ROUND_TITLE_PHASE1_DURATION + Title.ROUND_TITLE_OUT_TIME + Title.ROUND_TITLE_GAP_DURATION)) < 0.5, "...at the set rhythm (%.2f s after the start)" % gap)
	var finished: Array = [false]
	title.finished.connect(func() -> void: finished[0] = true)
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	title._input(key)
	_expect(finished[0] and title.skipped, "space skips the title at once")
	await process_frame
	_expect(presenter.current_round_title() == null, "...and nothing is left on screen")
	for case: Array in [["esc", KEY_ESCAPE], ["click", 0]]:
		presenter.announce_round(4)
		var again: Node = presenter.current_round_title()
		if String(case[0]) == "esc":
			var escape := InputEventKey.new()
			escape.keycode = KEY_ESCAPE
			escape.pressed = true
			again._input(escape)
		else:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			again._input(click)
		_expect(again.skipped, "%s skips it too" % String(case[0]))
		await process_frame
	# a title that is replaced by the next round does not stack
	presenter.announce_round(5)
	var first: Node = presenter.current_round_title()
	presenter.announce_round(6)
	await process_frame
	_expect(is_instance_valid(first) == false or first.skipped, "a new round replaces a title still on screen")
	presenter.current_round_title().skip()
	await process_frame
	# missing art: plain text, and nothing waits on it
	Title._textures["round_di"] = null
	presenter.history.clear()
	var before: int = presenter.get_child_count()
	presenter.announce_round(7)
	_expect(not Title.available() and presenter.current_round_title() == null and presenter.get_child_count() == before + 1, "without the art it falls back to the text announcement")
	Title._textures.erase("round_di")
	await _wait(2.0)
	presenter.queue_free()
