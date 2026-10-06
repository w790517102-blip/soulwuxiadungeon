extends Control
## "第 X 回合 / 開始": the round-start title, a stage announcement of its own (not a message popup, not an event tag).
## Phase 1 shows 第 + the round number + 回合, flipped up with a little overshoot, holds, and floats away; after a pause
## phase 2 punches in 開始 and holds a beat. The art is the delivered ink-and-gold pieces (assets/UI/card_stage/title/)
## and the number is built from the number sheet (BattleNumberFont). If any piece of art is missing `available()` is
## false and the caller shows plain text instead; nothing here ever waits on a texture.
## Skip: space, ESC or the left mouse button ends it at once (the input is not consumed: it still does its own job).
## Presentation only; it never blocks the battle.

const BattleNumberFont = preload("res://scripts/presentation/BattleNumberFont.gd")

# All timings in seconds, so the rhythm can be tuned in one place.
## Phase 1 (第 X 回合): from the start of its entrance to the start of its exit.
const ROUND_TITLE_PHASE1_DURATION := 1.2
## Pause between phase 1 being gone and 開始 appearing.
const ROUND_TITLE_GAP_DURATION := 1.0
## Phase 2 (開始): from its punch-in to the start of its exit.
const ROUND_TITLE_PHASE2_DURATION := 0.8
const ROUND_TITLE_IN_TIME := 0.2
const ROUND_TITLE_OUT_TIME := 0.35

const DIR := "res://assets/UI/card_stage/title/"
const PIECES: Array[String] = ["round_di", "round_huihe", "round_kaishi"]
## Height of the title pieces on screen as a fraction of the screen height (開始 is a little bigger).
const PIECE_HEIGHT := 0.24
const BEGIN_HEIGHT := 0.30
const NUMBER_STYLE := "counter"
const NUMBER_HEIGHT := 0.24
const CENTER_Y := 0.34

signal finished

static var _textures: Dictionary = {}

var round_number: int = 1
var skipped: bool = false
var phase: int = 0   # 0 not started, 1 第 X 回合, 2 開始, 3 done
var _timeline: Tween = null
var _phase1: Control = null
var _phase2: Control = null


static func texture_for(piece: String) -> Texture2D:
	if _textures.has(piece):
		return _textures[piece]
	var texture: Texture2D = null
	var path: String = "%s%s.png" % [DIR, piece]
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_textures[piece] = texture
	return texture


## True when every piece of title art is there.
static func available() -> bool:
	for piece: String in PIECES:
		if texture_for(piece) == null:
			return false
	return true


func _init() -> void:
	name = "BattleRoundTitle"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func play(number: int) -> void:
	round_number = number
	phase = 0
	_timeline = create_tween()
	_timeline.tween_callback(_enter_phase1)
	_timeline.tween_interval(ROUND_TITLE_PHASE1_DURATION)
	_timeline.tween_callback(_exit_phase1)
	_timeline.tween_interval(ROUND_TITLE_OUT_TIME + ROUND_TITLE_GAP_DURATION)
	_timeline.tween_callback(_enter_phase2)
	_timeline.tween_interval(ROUND_TITLE_PHASE2_DURATION)
	_timeline.tween_callback(_exit_phase2)
	_timeline.tween_interval(ROUND_TITLE_OUT_TIME)
	_timeline.tween_callback(_finish)


## Ends the title at once.
func skip() -> void:
	if phase == 3:
		return
	skipped = true
	_finish()


func _input(event: InputEvent) -> void:
	if phase == 3:
		return
	var pressed: bool = false
	if event is InputEventKey:
		var key: InputEventKey = event
		pressed = key.pressed and not key.echo and (key.keycode == KEY_SPACE or key.keycode == KEY_ESCAPE)
	elif event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		pressed = mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if pressed:
		skip()


func _finish() -> void:
	if phase == 3:
		return
	phase = 3
	if _timeline != null and _timeline.is_valid():
		_timeline.kill()
	finished.emit()
	queue_free()


# --- Layout ---------------------------------------------------------------------------------------------------------

func _center() -> Vector2:
	var screen: Vector2 = get_viewport_rect().size
	return Vector2(screen.x * 0.5, screen.y * CENTER_Y)


func _piece(piece: String, height: float) -> TextureRect:
	var texture: Texture2D = texture_for(piece)
	var image := TextureRect.new()
	image.texture = texture
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var aspect: float = float(texture.get_width()) / maxf(float(texture.get_height()), 1.0)
	image.size = Vector2(height * aspect, height)
	return image


## The round number from the number sheet; plain text in the same gold if the sheet is not there.
func _number(height: float) -> Control:
	var text: String = str(round_number)
	var row: Control = BattleNumberFont.build_row(NUMBER_STYLE, text, height, Vector2(height * 0.5 * float(text.length()) + 24.0, height * 1.1))
	if row != null:
		return row
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(height * 0.7))
	label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	label.add_theme_constant_override("outline_size", 10)
	label.size = Vector2(height * 0.6 * float(text.length()), height)
	return label


## 第 [X] 回合 as one block centred on its own origin (so scaling and turning it works from the middle).
func _build_phase1() -> Control:
	var screen: Vector2 = get_viewport_rect().size
	var height: float = screen.y * PIECE_HEIGHT
	var di: TextureRect = _piece("round_di", height)
	var huihe: TextureRect = _piece("round_huihe", height)
	var number: Control = _number(screen.y * NUMBER_HEIGHT)
	var number_width: float = number.size.x
	var gap: float = height * 0.02
	var total: float = di.size.x + gap + number_width + gap + huihe.size.x
	var block := Control.new()
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.size = Vector2(total, height)
	block.pivot_offset = block.size * 0.5
	block.position = _center() - block.size * 0.5
	var x: float = 0.0
	di.position = Vector2(x, 0.0)
	block.add_child(di)
	x += di.size.x + gap
	# the number sits centred on the pieces' middle line (the holder of an image row is centred on its own origin)
	if number.get_child_count() > 0 and number.get_child(0) is HBoxContainer:
		number.position = Vector2(x, (height - number.size.y) * 0.5)
	else:
		number.position = Vector2(x, (height - number.size.y) * 0.5)
	block.add_child(number)
	x += number_width + gap
	huihe.position = Vector2(x, 0.0)
	block.add_child(huihe)
	add_child(block)
	return block


func _build_phase2() -> Control:
	var screen: Vector2 = get_viewport_rect().size
	var begin: TextureRect = _piece("round_kaishi", screen.y * BEGIN_HEIGHT)
	begin.position = _center() - begin.size * 0.5
	begin.pivot_offset = begin.size * 0.5
	add_child(begin)
	return begin


# --- Phases ---------------------------------------------------------------------------------------------------------

## 第 X 回合: flips up from a little below and a little turned, overshoots, settles; a faint larger afterimage fades behind it.
func _enter_phase1() -> void:
	phase = 1
	_phase1 = _build_phase1()
	var ghost: Control = _build_phase1()
	ghost.modulate = Color(1.0, 0.9, 0.6, 0.0)
	move_child(ghost, 0)
	for block: Control in [_phase1, ghost]:
		block.scale = Vector2(0.72, 0.72)
		block.rotation = -0.10
		block.position.y += 46.0
		block.modulate.a = 0.0
	var rise: Tween = create_tween().set_parallel(true)
	rise.tween_property(_phase1, "modulate:a", 1.0, ROUND_TITLE_IN_TIME * 0.6)
	rise.tween_property(_phase1, "scale", Vector2(1.07, 1.07), ROUND_TITLE_IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.tween_property(_phase1, "rotation", 0.0, ROUND_TITLE_IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.tween_property(_phase1, "position:y", _phase1.position.y - 46.0, ROUND_TITLE_IN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rise.chain().tween_property(_phase1, "scale", Vector2.ONE, 0.1)
	# the afterimage: larger, pale, gone quickly
	var echo: Tween = create_tween().set_parallel(true)
	echo.tween_property(ghost, "modulate:a", 0.35, ROUND_TITLE_IN_TIME * 0.5)
	echo.tween_property(ghost, "scale", Vector2(1.16, 1.16), ROUND_TITLE_IN_TIME * 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	echo.tween_property(ghost, "rotation", 0.0, ROUND_TITLE_IN_TIME)
	echo.tween_property(ghost, "position:y", ghost.position.y - 46.0, ROUND_TITLE_IN_TIME)
	echo.chain().tween_property(ghost, "modulate:a", 0.0, ROUND_TITLE_IN_TIME * 1.5)
	echo.chain().tween_callback(ghost.queue_free)


func _exit_phase1() -> void:
	if _phase1 == null or not is_instance_valid(_phase1):
		return
	var away: Tween = create_tween().set_parallel(true)
	away.tween_property(_phase1, "position:y", _phase1.position.y - 30.0, ROUND_TITLE_OUT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	away.tween_property(_phase1, "modulate:a", 0.0, ROUND_TITLE_OUT_TIME)
	away.tween_property(_phase1, "scale", Vector2(1.05, 1.05), ROUND_TITLE_OUT_TIME)
	away.chain().tween_callback(_phase1.queue_free)


## 開始: punches in big, rebounds, flashes, and shakes once like a hit.
func _enter_phase2() -> void:
	phase = 2
	_phase2 = _build_phase2()
	var home: Vector2 = _phase2.position
	_phase2.scale = Vector2(1.7, 1.7)
	_phase2.modulate = Color(2.4, 2.1, 1.6, 0.0)
	var punch: Tween = create_tween()
	punch.tween_property(_phase2, "modulate:a", 1.0, 0.04)
	punch.parallel().tween_property(_phase2, "scale", Vector2(0.9, 0.9), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	punch.tween_property(_phase2, "scale", Vector2(1.04, 1.04), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	punch.parallel().tween_property(_phase2, "modulate", Color.WHITE, 0.22)
	punch.tween_property(_phase2, "scale", Vector2.ONE, 0.08)
	var shake: Tween = create_tween()
	shake.tween_interval(0.1)
	for offset: Vector2 in [Vector2(9, -5), Vector2(-7, 4), Vector2(5, -3), Vector2(-3, 2), Vector2.ZERO]:
		shake.tween_property(_phase2, "position", home + offset, 0.035)


func _exit_phase2() -> void:
	if _phase2 == null or not is_instance_valid(_phase2):
		return
	var away: Tween = create_tween().set_parallel(true)
	away.tween_property(_phase2, "modulate:a", 0.0, ROUND_TITLE_OUT_TIME)
	away.tween_property(_phase2, "scale", Vector2(1.12, 1.12), ROUND_TITLE_OUT_TIME)
	away.chain().tween_callback(_phase2.queue_free)
