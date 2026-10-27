extends "res://scripts/inventory/StudyPageBase.gd"
# 系統頁：書房卷軸版。四個入口：儲存進度、讀取進度（開《江湖行跡錄》）、選項、回標題畫面。按鈕對齊卷軸板塊的中心，不是畫面中心。
# 「回標題畫面」會先跳出確認視窗（提醒未存進度會遺失），確認後回到主選單（SystemMenu.return_to_title）。

const StudyForegrounds = preload("res://scripts/inventory/StudyForegrounds.gd")
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
	StudyForegrounds.add_lore(self)      # 前景沿用見聞頁的（墨筆、詩集）
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
			3: b.pressed.connect(_ask_return_to_title)
	var back := _tex_button(Vector2(165, 38), Vector2(494, 586), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16)
	back.text = "返回"
	back.pressed.connect(func(): close_requested.emit())
	_build_toast()
	_build_overlay()

func _foreground_preset() -> String:
	return "none"      # 前景用見聞頁的（見 _ready）

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


## 回標題前的確認視窗：卷軸攤開當視窗（字避開竹子與山水）
func _ask_return_to_title() -> void:
	_clear_overlay()
	_overlay.visible = true
	var pos := Vector2(216, 124)
	var size_ := Vector2(720, 400)
	var scroll := _image("scroll_body", pos, size_, _overlay)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_label("確定要回標題畫面嗎？", pos + Vector2(130, 50), Vector2(size_.x - 260, 36), 24, Color("#5A3208"), HORIZONTAL_ALIGNMENT_LEFT, _overlay)
	var b := _label("目前尚未儲存的遊戲進度將會遺失。\n\n要保留的話，請先按「取消」，再使用「儲存進度」。", pos + Vector2(130, 106), Vector2(size_.x - 300, 150), 18, INK, HORIZONTAL_ALIGNMENT_LEFT, _overlay)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var ok := _tex_button(Vector2(160, 40), pos + Vector2(130, size_.y - 78), "btn_primary_normal", "btn_primary_hover", "btn_primary_pressed", "btn_primary_disabled", 48, 16, _overlay)
	ok.text = "回標題畫面"
	var cancel := _tex_button(Vector2(160, 40), pos + Vector2(310, size_.y - 78), "btn_normal", "btn_hover", "btn_pressed", "btn_disabled", 48, 16, _overlay)
	cancel.text = "取消"
	ok.pressed.connect(func():
		_close_overlay()
		SystemMenu.call_deferred("return_to_title"))
	cancel.pressed.connect(_close_overlay)
