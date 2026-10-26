extends Control

## 單行文字欄位：放得下就照常顯示；放不下時平常顯示前半段加「…」，滑鼠移上去（呼叫 start()）就用跑馬燈把剩下的內容跑出來，
## 跑到底停一下再回到開頭重跑，滑鼠移開（呼叫 stop()）就回到開頭。
## 這個節點本身不吃滑鼠（mouse_filter = IGNORE）：由外面（列按鈕、欄位區）決定什麼時候 start／stop。

const HOLD_START := 0.5
const HOLD_END := 0.7
const SPEED := 60.0            # 每秒捲動的邏輯 px

var _label: Label
var _tween: Tween
var _text := ""

func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_label)

## font／size／color 與一般 Label 相同；outline > 0 時加黑色外框
func setup(text: String, area: Vector2, font: Font, font_size: int, color: Color, outline := 0) -> void:
	_text = text
	size = area
	custom_minimum_size = area
	_label.text = text
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", color)
	if outline > 0:
		_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_label.add_theme_constant_override("outline_size", outline)
	stop()

func _measure() -> float:
	var font := _label.get_theme_font("font")
	return font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _label.get_theme_font_size("font_size")).x if font != null else 0.0

func overflows() -> bool:
	return _measure() > size.x + 0.5

func is_scrolling() -> bool:
	return _tween != null and _tween.is_valid()

func start() -> void:
	if not overflows():
		return
	stop()
	_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_label.size = Vector2(_measure() + 4.0, size.y)
	_label.position = Vector2.ZERO
	var travel := _label.size.x - size.x + 6.0
	var dur := maxf(0.4, travel / SPEED)
	_tween = create_tween().set_loops()
	_tween.tween_interval(HOLD_START)
	_tween.tween_property(_label, "position:x", -travel, dur)
	_tween.tween_interval(HOLD_END)
	_tween.tween_property(_label, "position:x", 0.0, 0.0)

func stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label.position = Vector2.ZERO
	_label.size = Vector2(size.x, size.y)
