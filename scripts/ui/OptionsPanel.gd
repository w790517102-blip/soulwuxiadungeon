extends "res://scripts/inventory/StudyPageBase.gd"
# 選項視窗（全畫面壓暗＋卷軸攤開）：聲音（音樂、音效、語音：滑桿＋靜音）、畫面（視窗／無框視窗／全螢幕、視窗解析度）。
# 系統頁與主選單共用。設定由 GameSettings（自動載入）保存。視窗內容避開卷軸的竹子（右上、左下）與山水（右下）。

signal closed

const OPT_POS := Vector2(176, 74)
const OPT_SIZE := Vector2(800, 500)

var _opt_sliders: Dictionary = {}
var _opt_values: Dictionary = {}
var _opt_mutes: Dictionary = {}
var _opt_modes: Dictionary = {}
var _opt_res: Dictionary = {}

func _ready() -> void:
	name = "OptionsPanel"
	set_meta("skip_menu_skin", true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 3000
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.62)
	add_child(dim)
	_opt_sliders.clear()
	_opt_values.clear()
	_opt_mutes.clear()
	_opt_modes.clear()
	_opt_res.clear()
	var scroll := _image("scroll_body", OPT_POS, OPT_SIZE, self)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var x0 := OPT_POS.x + 140.0
	_label("選項", Vector2(x0, OPT_POS.y + 44), Vector2(300, 40), 28, Color("#5A3208"), HORIZONTAL_ALIGNMENT_LEFT, self)
	_label("聲音", Vector2(x0, OPT_POS.y + 96), Vector2(120, 26), 18, Color("#5A3208"), HORIZONTAL_ALIGNMENT_LEFT, self)
	var y := OPT_POS.y + 128.0
	for bus in GameSettings.BUSES:
		_label(GameSettings.BUS_LABELS[bus], Vector2(x0, y), Vector2(64, 30), 18, INK, HORIZONTAL_ALIGNMENT_LEFT, self)
		var s := HSlider.new()
		s.min_value = 0
		s.max_value = 100
		s.step = 1
		s.position = Vector2(x0 + 70, y + 6)
		s.size = Vector2(210, 20)
		s.focus_mode = Control.FOCUS_NONE
		_style_slider(s)
		add_child(s)
		var v := _label("", Vector2(x0 + 290, y), Vector2(46, 30), 16, INK, HORIZONTAL_ALIGNMENT_RIGHT, self)
		var m := _tex_button(Vector2(74, 28), Vector2(x0 + 346, y + 1), "btn_normal", "btn_hover", "btn_primary_normal", "btn_disabled", 48, 16, self)
		m.text = "靜音"
		m.toggle_mode = true
		m.add_theme_font_size_override("font_size", 14)
		_opt_sliders[bus] = s
		_opt_values[bus] = v
		_opt_mutes[bus] = m
		s.value_changed.connect(func(val: float): GameSettings.set_volume(bus, int(val)))
		m.toggled.connect(func(on: bool): GameSettings.set_muted(bus, on))
		y += 40.0
	_label("畫面", Vector2(x0, y + 8), Vector2(120, 26), 18, Color("#5A3208"), HORIZONTAL_ALIGNMENT_LEFT, self)
	var mx := x0
	for mode in GameSettings.MODES:
		var b := _tex_button(Vector2(104, 32), Vector2(mx, y + 40), "btn_normal", "btn_hover", "btn_primary_normal", "btn_disabled", 48, 16, self)
		b.text = GameSettings.MODE_LABELS[mode]
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(func(): GameSettings.set_display_mode(mode))
		_opt_modes[mode] = b
		mx += 112.0
	_label("視窗大小", Vector2(x0, y + 82), Vector2(100, 26), 15, INK_DIM, HORIZONTAL_ALIGNMENT_LEFT, self)
	var rx := x0
	for res in GameSettings.RESOLUTIONS:
		var rb := _tex_button(Vector2(100, 30), Vector2(rx, y + 112), "btn_normal", "btn_hover", "btn_primary_normal", "btn_disabled", 48, 16, self)
		rb.text = "%d×%d" % [res.x, res.y]
		rb.add_theme_font_size_override("font_size", 14)
		rb.pressed.connect(func(): GameSettings.set_resolution(res))
		_opt_res[res] = rb
		rx += 106.0
	var close := _tex_button(Vector2(150, 38), Vector2(OPT_POS.x + 140, OPT_POS.y + OPT_SIZE.y - 70), "btn_primary_normal", "btn_primary_hover", "btn_primary_pressed", "btn_primary_disabled", 48, 16, self)
	close.text = "完成"
	close.pressed.connect(_close)
	_refresh_options()
	GameSettings.settings_changed.connect(_refresh_options)

func _refresh_options() -> void:
	if _opt_sliders.is_empty():
		return
	for bus in GameSettings.BUSES:
		var s: HSlider = _opt_sliders[bus]
		if is_instance_valid(s):
			s.set_value_no_signal(float(GameSettings.volume[bus]))
			(_opt_values[bus] as Label).text = "%d" % int(GameSettings.volume[bus])
			(_opt_mutes[bus] as Button).set_pressed_no_signal(bool(GameSettings.muted[bus]))
	for mode in GameSettings.MODES:
		var b: Button = _opt_modes[mode]
		if is_instance_valid(b):
			_mark_selected(b, mode == GameSettings.display_mode)
	for res in GameSettings.RESOLUTIONS:
		var rb: Button = _opt_res[res]
		if is_instance_valid(rb):
			rb.disabled = not GameSettings.resolution_enabled()
			rb.modulate = Color(1, 1, 1, 1.0 if GameSettings.resolution_enabled() else 0.4)      # 只有「視窗」模式能選解析度
			_mark_selected(rb, res == GameSettings.resolution and GameSettings.resolution_enabled())

## 被選中的選項用主按鈕（金邊）的樣子，其餘是一般按鈕
func _mark_selected(b: Button, on: bool) -> void:
	var p := "btn_primary" if on else "btn"
	for pair in [["normal", p + "_normal"], ["hover", p + "_hover"], ["pressed", p + "_pressed"], ["hover_pressed", p + "_pressed"], ["disabled", "btn_disabled"]]:
		var bx := _box(pair[1], 48, 16)
		b.add_theme_stylebox_override(pair[0], bx if bx != null else StyleBoxEmpty.new())

func _style_slider(s: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#3A2A14")
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#B88A3A")
	fill.set_corner_radius_all(4)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var img := Image.create(22, 22, false, Image.FORMAT_RGBA8)
	for yy in 22:
		for xx in 22:
			var d := Vector2(xx - 10.5, yy - 10.5).length()
			var col := Color(0, 0, 0, 0)
			if d <= 10.0:
				col = Color("#F0D890") if d <= 7.5 else Color("#5A3208")
			img.set_pixel(xx, yy, col)
	var tex := ImageTexture.create_from_image(img)
	s.add_theme_icon_override("grabber", tex)
	s.add_theme_icon_override("grabber_highlight", tex)
	s.add_theme_icon_override("grabber_disabled", tex)

func _close() -> void:
	if GameSettings.settings_changed.is_connected(_refresh_options):
		GameSettings.settings_changed.disconnect(_refresh_options)
	closed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

## 開在任何節點之上
static func open(parent: Node) -> Control:
	var p = load("res://scripts/ui/OptionsPanel.gd").new()
	parent.add_child(p)
	return p
