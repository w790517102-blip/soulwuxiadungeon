extends Control
## Battle Event Presentation - the renderer. Gameplay says WHAT happened (BattleEvent records); this decides how it
## moves, what colour it is and when it goes away. Nothing in here changes a battle result or waits for the battle:
## numbers and tags are fire-and-forget, and the tail of a popup (fall, bounce, fade) never holds up the next action.
##
## Numeric  - damage accumulates over the strikes of ONE action into one popup that is knocked up on the first
##            strike, hops on each following strike and only falls after the last (25 -> 50 -> 75 -> 100).
##            Healing is a quieter number that rises from low and fades.
## Event    - MISS / 格擋 / 攔截 / 免疫 / 無效 / status applied or removed: an icon (if the art exists) and a short
##            word beside the target; no icon is never an empty tag.
## Announce - "第 3 回合開始": centred, larger, no icon.
## The persistent status row on the cards and Card Inspect are separate layers and are not touched here.

const BattleEventScript = preload("res://scripts/presentation/BattleEvent.gd")
const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const BattleNumberFont = preload("res://scripts/presentation/BattleNumberFont.gd")

const COLOR_NORMAL := Color(0.97, 0.91, 0.66)
const COLOR_COUNTER := Color(1.0, 0.82, 0.12)
const COLOR_CRITICAL := Color(1.0, 0.17, 0.14)
const COLOR_HEAL := Color(0.55, 0.98, 0.76)
const COLOR_OUTLINE := Color(0.06, 0.04, 0.03, 0.95)
const COLOR_BUFF := Color(0.62, 0.9, 1.0)
const COLOR_DEBUFF := Color(1.0, 0.55, 0.48)

const NUMBER_SIZE := 38
const CRIT_SIZE := 50
const TAG_SIZE := 24
const TAG_ICON := 26.0
const ANNOUNCE_SIZE := 50
## Where on the target card (fractions of its screen rectangle, from the top) the number is struck out of, hovers, and lands.
const STRIKE_Y := 0.55
const HOVER_Y := -0.04
const GROUND_Y := 0.50
## A sequence nobody has updated for this long lets go (a strike that never came must not leave a number hanging).
const STALE_SECONDS := 3.0
## After the last strike the number holds for this long (so the final value can be read), then falls.
const SETTLE_SECONDS := 0.34

## Callable(target: Dictionary) -> Rect2 (screen rectangle of the target's card).
var anchor_provider: Callable = Callable()

var _sequences: Dictionary = {}
var _next_sequence: int = 0
var _tag_stacks: Dictionary = {}   # target uid -> {"count": int, "stamp": int}
## What was shown, newest last (for tests and for a future event log): {"type", "text", "icon", "target"}.
var history: Array = []


func _init() -> void:
	name = "BattleEventPresenter"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	for sequence_id: Variant in _sequences.keys():
		var sequence: Dictionary = _sequences[sequence_id]
		if float(now - int(sequence.stamp)) / 1000.0 > STALE_SECONDS:
			_finish(String(sequence_id))


func new_sequence_id(target: Dictionary) -> String:
	_next_sequence += 1
	return "action%d:%s" % [_next_sequence, _uid(target)]


static func _uid(target: Dictionary) -> String:
	return String(target.get("battle_uid", target.get("id", target.get("name", "?"))))


func _rect_of(target: Dictionary) -> Rect2:
	if anchor_provider.is_valid():
		var rect: Rect2 = anchor_provider.call(target)
		if rect.size.x > 1.0:
			return rect
	var screen: Vector2 = get_viewport_rect().size
	return Rect2(screen * 0.5 - Vector2(60, 90), Vector2(120, 180))


func _make_label(text: String, size: int, color: Color, outline: int = 7) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	label.add_theme_constant_override("outline_size", outline)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


# --- Damage: one accumulating popup per action and target ---------------------------------------------------------

## Colour, glow and size of the number for the latest strike of the sequence.
static func style_for(result_type: String) -> Dictionary:
	match result_type:
		BattleEventScript.CRITICAL_COUNTER_HIT, BattleEventScript.CRITICAL_HIT:
			# First version: critical wins over counter (the data keeps both; a double mark can come later).
			return {"color": COLOR_CRITICAL, "glow": Color(COLOR_CRITICAL, 0.55), "size": CRIT_SIZE, "power": 1.0, "suffix": "!"}
		BattleEventScript.COUNTER_HIT:
			return {"color": COLOR_COUNTER, "glow": Color(COLOR_COUNTER, 0.5), "size": NUMBER_SIZE + 4, "power": 0.7, "suffix": "!"}
	return {"color": COLOR_NORMAL, "glow": Color(0, 0, 0, 0), "size": NUMBER_SIZE, "power": 0.5, "suffix": "!"}


## One strike of a damage sequence (BattleEvent.damage_hit). The first strike makes the popup, later ones update it,
## the final one lets it fall.
func show_damage(event: Dictionary) -> void:
	var target: Dictionary = event.target
	var sequence_id: String = String(event.sequence_id)
	var style: Dictionary = style_for(String(event.result_type))
	var sequence: Dictionary = _sequences.get(sequence_id, {})
	var first: bool = sequence.is_empty()
	if first:
		sequence = _spawn_number(target, style)
		_sequences[sequence_id] = sequence
	sequence["stamp"] = Time.get_ticks_msec()
	var label: Label = sequence.label
	var glow: Label = sequence.glow
	var text: String = "%s%s" % [str(event.cumulative_value), String(style.suffix)]
	history.append({"type": BattleEventScript.DAMAGE, "text": text, "icon": "", "target": target, "result_type": String(event.result_type), "final": bool(event.is_final_hit)})
	label.text = text
	glow.text = text
	_apply_style(sequence, style)
	_sync_image(sequence, BattleNumberFont.style_key(String(event.result_type)), text, style)
	if first:
		_play_first_strike(sequence, style)
	else:
		_play_hop(sequence, style)
	if bool(event.is_final_hit):
		_schedule_fall(sequence_id, sequence, style, first)


func _spawn_number(target: Dictionary, style: Dictionary) -> Dictionary:
	var rect: Rect2 = _rect_of(target)
	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.size = Vector2.ZERO
	wrapper.position = Vector2(rect.get_center().x, rect.position.y + rect.size.y * STRIKE_Y)
	add_child(wrapper)
	var glow: Label = _make_label("", NUMBER_SIZE, Color(0, 0, 0, 0), 12)
	var label: Label = _make_label("", NUMBER_SIZE, COLOR_NORMAL)
	for item: Label in [glow, label]:
		item.size = Vector2(240, 80)
		item.position = Vector2(-120, -40)
		item.pivot_offset = Vector2(120, 40)
		wrapper.add_child(item)
	return {
		"wrapper": wrapper, "label": label, "glow": glow, "target": target, "stamp": Time.get_ticks_msec(),
		"hover": Vector2(rect.get_center().x, rect.position.y + rect.size.y * HOVER_Y),
		"ground": Vector2(rect.get_center().x, rect.position.y + rect.size.y * GROUND_Y),
		"hop": null, "move": null,
	}


## The parts of a number that are animated together: the glow and label (text mode) or the image row (image mode).
func _items(sequence: Dictionary) -> Array:
	var items: Array = []
	for key: String in ["glow", "label", "row"]:
		var part: Variant = sequence.get(key, null)
		if part is Control and is_instance_valid(part) and (part as Control).visible:
			items.append(part)
	return items


## Image digits when the art for this style exists, the font label otherwise (never both, never nothing).
func _sync_image(sequence: Dictionary, style_key: String, text: String, style: Dictionary) -> void:
	var wrapper: Control = sequence.wrapper
	var old: Variant = sequence.get("row", null)
	if old is Control and is_instance_valid(old):
		(old as Control).queue_free()
	sequence["row"] = null
	var row: Control = BattleNumberFont.build_row(style_key, text, float(style.size) * 1.9, Vector2(240, 80))
	var label: Label = sequence.label
	var glow: Label = sequence.glow
	if row == null:
		label.visible = true
		glow.visible = (style.glow as Color).a > 0.01
		return
	label.visible = false
	glow.visible = false
	wrapper.add_child(row)
	sequence["row"] = row


func _apply_style(sequence: Dictionary, style: Dictionary) -> void:
	var label: Label = sequence.label
	var glow: Label = sequence.glow
	label.add_theme_font_size_override("font_size", int(style.size))
	label.add_theme_color_override("font_color", style.color)
	glow.add_theme_font_size_override("font_size", int(style.size))
	var glow_color: Color = style.glow
	# The glow is the same number drawn under the main one with a fat translucent outline.
	glow.add_theme_color_override("font_color", Color(glow_color, glow_color.a * 0.6))
	glow.add_theme_color_override("font_outline_color", glow_color)
	glow.visible = glow_color.a > 0.01


## The first strike: the number is knocked up out of the spot that was hit, with a scale punch, and hangs there.
func _play_first_strike(sequence: Dictionary, style: Dictionary) -> void:
	var wrapper: Control = sequence.wrapper
	var label: Label = sequence.label
	var glow: Label = sequence.glow
	var power: float = float(style.power)
	var rise: float = 1.0 + 0.35 * power
	for item: Control in _items(sequence):
		item.modulate = Color(1, 1, 1, 0)
		item.scale = Vector2(0.5, 0.5)
	var move: Tween = create_tween()
	move.tween_property(wrapper, "position", sequence.hover - Vector2(0, 18.0 * rise), 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	move.tween_property(wrapper, "position", sequence.hover, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sequence["move"] = move
	var punch: Tween = create_tween().set_parallel(true)
	var peak: float = 1.3 + 0.35 * power
	for item: Control in _items(sequence):
		punch.tween_property(item, "modulate:a", 1.0, 0.04)
		punch.tween_property(item, "scale", Vector2(peak, peak), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		punch.chain().tween_property(item, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	sequence["hop"] = punch


## A following strike: the same number, higher, hops once and flashes. It does not replay the entrance.
func _play_hop(sequence: Dictionary, style: Dictionary) -> void:
	var label: Label = sequence.label
	var glow: Label = sequence.glow
	var previous: Variant = sequence.get("hop", null)
	if previous is Tween and (previous as Tween).is_valid():
		(previous as Tween).kill()
	var power: float = float(style.power)
	var height: float = 10.0 + 10.0 * power
	var peak: float = 1.16 + 0.12 * power
	for item: Control in _items(sequence):
		item.position = Vector2(-120, -40)
		item.scale = Vector2.ONE
		item.modulate = Color(2.0, 2.0, 1.8, 1.0) if item != glow else Color.WHITE
	var hop: Tween = create_tween().set_parallel(true)
	for item: Control in _items(sequence):
		hop.tween_property(item, "position:y", -40.0 - height, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hop.tween_property(item, "scale", Vector2(peak, peak), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hop.chain().tween_property(item, "position:y", -40.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		hop.parallel().tween_property(item, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for item: Control in _items(sequence):
		hop.parallel().tween_property(item, "modulate", Color.WHITE, 0.14)
	sequence["hop"] = hop


## After the last strike: hold so the final value can be read, then fall, bounce, shudder and fade. The sequence is
## closed at once, so the next action makes a new number; the tail below runs by itself.
func _schedule_fall(sequence_id: String, sequence: Dictionary, style: Dictionary, just_spawned: bool = false) -> void:
	_sequences.erase(sequence_id)
	var wrapper: Control = sequence.wrapper
	var label: Label = sequence.label
	var glow: Label = sequence.glow
	var delay: float = SETTLE_SECONDS + (0.22 if just_spawned else 0.0)
	var fall: Tween = create_tween()
	fall.tween_interval(delay)
	fall.tween_property(wrapper, "position", sequence.ground, 0.52).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	fall.tween_callback(_shudder.bind(sequence, 5.0 + 4.0 * float(style.power)))
	fall.tween_interval(0.24)
	fall.tween_property(wrapper, "modulate:a", 0.0, 0.36)
	fall.tween_callback(wrapper.queue_free)


func _shudder(sequence: Dictionary, amplitude: float) -> void:
	var wrapper: Control = sequence.wrapper
	if not is_instance_valid(wrapper):
		return
	for item: Control in _items(sequence):
		var sequence_tween: Tween = create_tween()
		sequence_tween.tween_property(item, "position:x", -120.0 + amplitude, 0.03)
		sequence_tween.tween_property(item, "position:x", -120.0 - amplitude, 0.05)
		sequence_tween.tween_property(item, "position:x", -120.0 + amplitude * 0.5, 0.05)
		sequence_tween.tween_property(item, "position:x", -120.0, 0.04)


## Lets go of a sequence that never got its final strike: it falls as it is.
func _finish(sequence_id: String) -> void:
	var sequence: Dictionary = _sequences.get(sequence_id, {})
	if sequence.is_empty():
		return
	_schedule_fall(sequence_id, sequence, {"power": 0.5})


## True while a damage number of this action is still hanging, waiting for its next strike (for tests).
func has_open_sequence(sequence_id: String) -> bool:
	return _sequences.has(sequence_id)


func open_sequence_count() -> int:
	return _sequences.size()


func current_number_text(sequence_id: String) -> String:
	var sequence: Dictionary = _sequences.get(sequence_id, {})
	return String((sequence.get("label", null) as Label).text) if not sequence.is_empty() else ""


# --- Healing -------------------------------------------------------------------------------------------------------

## "+45": not a blow. It appears low on the card, rises gently, settles with a small bounce and fades.
func show_heal(event: Dictionary) -> void:
	var target: Dictionary = event.target
	history.append({"type": BattleEventScript.HEAL, "text": String(event.primary_text), "icon": "", "target": target})
	var rect: Rect2 = _rect_of(target)
	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.position = Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.62)
	add_child(wrapper)
	var label: Label = _make_label(String(event.primary_text), NUMBER_SIZE, COLOR_HEAL)
	label.size = Vector2(240, 80)
	label.position = Vector2(-120, -40)
	label.pivot_offset = Vector2(120, 40)
	label.modulate = Color(1, 1, 1, 0)
	wrapper.add_child(label)
	# Image digits when the heal set exists, otherwise the label.
	var visual: Control = label
	var image_row: Control = BattleNumberFont.build_row("heal", String(event.primary_text), NUMBER_SIZE * 1.9, Vector2(240, 80))
	if image_row != null:
		label.visible = false
		wrapper.add_child(image_row)
		visual = image_row
		visual.modulate = Color(1, 1, 1, 0)
	var rise: Tween = create_tween()
	rise.tween_property(visual, "modulate:a", 1.0, 0.18)
	rise.parallel().tween_property(wrapper, "position:y", wrapper.position.y - rect.size.y * 0.22, 0.62).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	rise.tween_property(visual, "scale", Vector2(1.1, 1.1), 0.1)
	rise.tween_property(visual, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	rise.tween_interval(0.35)
	rise.tween_property(visual, "modulate:a", 0.0, 0.4)
	rise.tween_callback(wrapper.queue_free)


# --- Status / event tags ---------------------------------------------------------------------------------------------

func _tag_color(event: Dictionary) -> Color:
	match String(event.event_type):
		BattleEventScript.STATUS_APPLIED:
			return COLOR_DEBUFF if bool(event.get("is_debuff", false)) else COLOR_BUFF
		BattleEventScript.STATUS_REMOVED:
			return Color(0.82, 0.9, 0.8)
		BattleEventScript.INTERCEPT:
			return Color(1.0, 0.78, 0.35)
		BattleEventScript.BLOCK:
			return Color(0.72, 0.84, 1.0)
		BattleEventScript.IMMUNE, BattleEventScript.NULLIFIED:
			return Color(0.88, 0.88, 0.95)
		BattleEventScript.MISS:
			return Color(0.9, 0.9, 0.86)
	return Color.WHITE


## An event beside its target: [icon] word. The icon is optional; the word is always there.
func show_event(event: Dictionary) -> void:
	var target: Dictionary = event.get("target", {}) if typeof(event.get("target", {})) == TYPE_DICTIONARY else {}
	var texture: Texture2D = BattleEventScript.texture_for(String(event.get("icon_key", "")))
	history.append({"type": String(event.event_type), "text": String(event.primary_text), "icon": String(event.icon_key) if texture != null else "", "target": target})
	if String(event.event_type) == BattleEventScript.ANNOUNCE:
		_show_announcement(event)
		return
	var rect: Rect2 = _rect_of(target)
	var stack: int = _claim_tag_slot(target)
	var color: Color = _tag_color(event)
	var word: Label = _make_label(String(event.primary_text), TAG_SIZE, color, 6)
	var word_size: Vector2 = FONT.get_string_size(word.text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_SIZE)
	var icon_width: float = TAG_ICON + 6.0 if texture != null else 0.0
	var total: float = icon_width + word_size.x
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = Vector2(rect.get_center().x - total * 0.5, rect.position.y + rect.size.y * 0.26 + float(stack) * (TAG_ICON + 8.0))
	add_child(holder)
	if texture != null:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(TAG_ICON, TAG_ICON)
		holder.add_child(icon)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	word.position = Vector2(icon_width, -2.0)
	word.size = Vector2(word_size.x + 4.0, TAG_ICON + 4.0)
	holder.add_child(word)
	holder.modulate = Color(1, 1, 1, 0)
	var life: float = float(event.get("duration", 1.0))
	var tag: Tween = create_tween()
	tag.tween_property(holder, "modulate:a", 1.0, 0.1)
	tag.parallel().tween_property(holder, "position:y", holder.position.y - 12.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tag.tween_interval(maxf(life - 0.4, 0.2))
	tag.tween_property(holder, "modulate:a", 0.0, 0.3)
	tag.tween_callback(holder.queue_free)


## Tags on the same target stack downwards while the earlier ones are still up; the stack resets when they are gone.
func _claim_tag_slot(target: Dictionary) -> int:
	var key: String = _uid(target)
	var now: int = Time.get_ticks_msec()
	var entry: Dictionary = _tag_stacks.get(key, {"count": 0, "stamp": 0})
	if now - int(entry.stamp) > 1200:
		entry["count"] = 0
	var slot: int = int(entry.count)
	entry["count"] = slot + 1
	entry["stamp"] = now
	_tag_stacks[key] = entry
	return mini(slot, 3)


func _show_announcement(event: Dictionary) -> void:
	var screen: Vector2 = get_viewport_rect().size
	var label: Label = _make_label(String(event.primary_text), ANNOUNCE_SIZE, Color(0.98, 0.94, 0.8), 10)
	label.size = Vector2(screen.x, 90)
	label.position = Vector2(0, screen.y * 0.16)
	label.pivot_offset = label.size * 0.5
	label.modulate = Color(1, 1, 1, 0)
	label.scale = Vector2(0.92, 0.92)
	add_child(label)
	var life: float = float(event.get("duration", 1.6))
	var fade: Tween = create_tween()
	fade.tween_property(label, "modulate:a", 1.0, 0.25)
	fade.parallel().tween_property(label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade.tween_interval(maxf(life - 0.55, 0.3))
	fade.tween_property(label, "modulate:a", 0.0, 0.3)
	fade.tween_callback(label.queue_free)


# --- Whole actions: the strikes of one skill on one target ------------------------------------------------------------

## Reads the strikes of an action's result for one target and shows each at its moment (see schedule_run).
## Returns the sequence id of the damage number ("" if nothing was damaged).
func schedule_strikes(target: Dictionary, result: Dictionary, first_delay: float, gap: float, sequence_id: String = "") -> String:
	var strikes: Array = result.get("strikes", [])
	if strikes.is_empty():
		strikes = [result]
	var entries: Array = []
	for strike: Variant in strikes:
		entries.append({"target": target, "strike": strike})
	var ids: Dictionary = schedule_run(entries, first_delay, gap, sequence_id)
	return String(ids.get(_uid(target), ""))


## A run of blows, possibly on several targets, in the order they land: {"target", "strike"} per blow. The blow with
## index i lands at first_delay + i * gap. Each target gets its own accumulating number (never one total across
## targets); a landed blow feeds it, while a miss / block / interception / nullified blow shows its word instead of a 0.
## `first_delay` is when the first blow arrives (the attacker's wind-up) and `gap` the time between blows; both depend
## on the weapon's animation and are tuned by the stage. Returns {target uid: sequence id} for the numbers it made.
func schedule_run(entries: Array, first_delay: float, gap: float, sequence_id: String = "") -> Dictionary:
	var groups: Dictionary = {}
	for entry_any: Variant in entries:
		var entry: Dictionary = entry_any
		var uid: String = _uid(entry.target)
		if not groups.has(uid):
			groups[uid] = {"strikes": [], "plan": [], "cursor": 0, "cumulative": 0, "landed": 0, "landed_seen": 0, "sequence": ""}
		(groups[uid].strikes as Array).append(entry.strike)
	var made: Dictionary = {}
	for uid: Variant in groups.keys():
		var group: Dictionary = groups[uid]
		group["plan"] = plan_strikes(group.strikes)
		for item: Dictionary in group.plan:
			if String(item.kind) == "damage":
				group["landed"] = int(group.landed) + 1
		if int(group.landed) > 0:
			group["sequence"] = sequence_id if sequence_id != "" else new_sequence_id(_target_of(entries, String(uid)))
			made[uid] = group.sequence
	for index: int in range(entries.size()):
		var target: Dictionary = (entries[index] as Dictionary).target
		var group: Dictionary = groups[_uid(target)]
		var item: Dictionary = group.plan[int(group.cursor)]
		group["cursor"] = int(group.cursor) + 1
		var event: Dictionary
		if String(item.kind) == "damage":
			group["landed_seen"] = int(group.landed_seen) + 1
			group["cumulative"] = int(group.cumulative) + int(item.damage)
			event = BattleEventScript.damage_hit(String(group.sequence), target, int(group.landed_seen), int(group.landed), int(item.damage), int(group.cumulative), String(item.result_type), int(group.landed_seen) == int(group.landed))
		else:
			event = BattleEventScript.make(String(item.kind), target)
		var delay: float = first_delay + float(index) * gap
		if delay <= 0.0:
			_dispatch(event)
		else:
			get_tree().create_timer(delay).timeout.connect(_dispatch.bind(event))
	return made


static func _target_of(entries: Array, uid: String) -> Dictionary:
	for entry_any: Variant in entries:
		if _uid((entry_any as Dictionary).target) == uid:
			return (entry_any as Dictionary).target
	return {}


func _dispatch(event: Dictionary) -> void:
	if String(event.event_type) == BattleEventScript.DAMAGE:
		show_damage(event)
	elif String(event.event_type) == BattleEventScript.HEAL:
		show_heal(event)
	else:
		show_event(event)


## What each strike is: {"kind": "damage"|miss|block|intercept|nullified, "damage", "result_type"}. Pure data, no nodes.
static func plan_strikes(strikes: Array) -> Array:
	var plan: Array = []
	for strike_any: Variant in strikes:
		var strike: Dictionary = strike_any
		var blocker: String = String(strike.get("blocker_type", ""))
		if bool(strike.get("blocked", false)):
			plan.append({"kind": BattleEventScript.INTERCEPT if blocker == "substitute_talisman" else BattleEventScript.BLOCK})
		elif bool(strike.get("damage_prevented", false)):
			plan.append({"kind": BattleEventScript.NULLIFIED})
		elif not bool(strike.get("hit", true)):
			plan.append({"kind": BattleEventScript.MISS})
		elif int(strike.get("damage", 0)) <= 0:
			plan.append({"kind": BattleEventScript.NULLIFIED})
		else:
			plan.append({
				"kind": "damage", "damage": int(strike.get("damage", 0)),
				"result_type": BattleEventScript.result_type(bool(strike.get("crit", false)), bool(strike.get("element_advantage", false))),
			})
	return plan


func announce(text: String) -> void:
	show_event(BattleEventScript.announcement(text))
