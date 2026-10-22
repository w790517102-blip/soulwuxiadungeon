extends "res://scripts/inventory/StudyPageBase.gd"
# 系統頁：書房卷軸版。四個入口：儲存進度、讀取進度（開《江湖行跡錄》）、選項、回標題畫面。按鈕對齊卷軸板塊的中心，不是畫面中心。
# 「回標題畫面」舊頁的按鈕本來就沒有接任何功能（回標題會重設遊戲狀態，需要另外設計），這裡先放上同一顆鈕，按下去只提示尚未開放。

const OptionsPanelScript = preload("res://scripts/ui/OptionsPanel.gd")
const ENTRY_SIZE := Vector2(300, 58)
const ENTRY_X := 494.0                 # 卷軸板塊（x 158–1130）的水平中心 644 − 按鈕寬的一半
const ENTRY_Y0 := 192.0
const ENTRY_GAP := 16.0

var _note_btn: Button

func _ready() -> void:
	name = "SystemPage"
	set_meta("skip_menu_skin", true)
	soft_halo = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 1100
	_build_background(true)
	_build_nav("TabSystem")
	_label("系統", Vector2(494, 112), Vector2(300, 56), 40, INK, HORIZONTAL_ALIGNMENT_CENTER)
	var entries := [["儲存進度", "btn_primary"], ["讀取進度", "btn_primary"], ["選項", "btn"], ["回標題畫面", "btn"]]
	for i in entries.size():
		var p: String = entries[i][1]
		var b := _tex_button(ENTRY_SIZE, Vector2(ENTRY_X, ENTRY_Y0 + i * (ENTRY_SIZE.y + ENTRY_GAP)), p + "_normal", p + "_hover", p + "_pressed", p + "_disabled", 48, 16)
		b.text = String(entries[i][0])
		b.add_theme_font_size_override("font_size", 24)
		match i:
			0: b.pressed.connect(_open_chronicle.bind(ChronicleScreen.Mode.SAVE))
			1: b.pressed.connect(_open_chronicle.bind(ChronicleScreen.Mode.LOAD))
			2: b.pressed.connect(func(): OptionsPanelScript.open(get_tree().root if menu == null else menu.get_parent()))
			3: b.pressed.connect(func(): show_toast("回標題畫面功能尚未開放"))
	var back := _tex_button(Vector2(165, 38), Vector2(494, 586), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16)
	back.text = "返回"
	back.pressed.connect(func(): close_requested.emit())
	_build_toast()
	_build_overlay()

func _foreground_preset() -> String:
	return "demo"

func _open_chronicle(open_mode: int) -> void:
	# 掛在系統選單的上一層（UIRoot）：系統選單被關閉時（讀檔成功）由《江湖行跡錄》自己收掉
	var parent: Node = menu.get_parent() if menu != null and menu.get_parent() != null else get_tree().root
	ChronicleScreen.open(parent, open_mode)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_requested.emit()

