extends Panel
# 系統選單「系統」分頁：只剩兩個入口，儲存進度／讀取進度。
# 實際的 99 格介面是共用的《江湖行跡錄》（scripts/chronicle/ChronicleScreen.gd），返回後就回到這個分頁。

const FONT := preload("res://assets/fonts/DotGothic16-Regular.ttf")

func _ready() -> void:
	var col := VBoxContainer.new()
	col.name = "EntryColumn"
	col.position = Vector2(386, 150)
	col.size = Vector2(280, 170)
	col.add_theme_constant_override("separation", 24)
	add_child(col)
	var save_btn := _make_entry_button("SaveEntryButton", "儲存進度")
	var load_btn := _make_entry_button("LoadEntryButton", "讀取進度")
	col.add_child(save_btn)
	col.add_child(load_btn)
	save_btn.pressed.connect(_open_chronicle.bind(ChronicleScreen.Mode.SAVE))
	load_btn.pressed.connect(_open_chronicle.bind(ChronicleScreen.Mode.LOAD))

func _make_entry_button(button_name: String, label: String) -> Button:
	var b := Button.new()
	b.name = button_name
	b.text = label
	b.custom_minimum_size = Vector2(280, 72)
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", Color(0.86, 0.72, 0.38))
	b.add_theme_color_override("font_hover_color", Color(1, 0.92, 0.7))
	b.add_theme_stylebox_override("normal", _box(Color(0.11, 0.09, 0.07, 0.95), Color(0.5, 0.4, 0.2)))
	b.add_theme_stylebox_override("hover", _box(Color(0.22, 0.06, 0.05, 0.98), Color(0.85, 0.68, 0.28)))
	b.add_theme_stylebox_override("pressed", _box(Color(0.16, 0.04, 0.04, 1.0), Color(0.85, 0.68, 0.28)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b

func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	return s

func _open_chronicle(open_mode: int) -> void:
	# 掛在系統選單的上一層（UIRoot）：系統選單被關閉時（讀檔成功）由《江湖行跡錄》自己收掉
	var menu_root: Node = self
	while menu_root.get_parent() != null and menu_root.name != "SystemMenu" and menu_root.get_parent() != get_tree().root:
		menu_root = menu_root.get_parent()
	var parent: Node = menu_root.get_parent() if menu_root.get_parent() != null else get_tree().root
	ChronicleScreen.open(parent, open_mode)
