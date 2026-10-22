extends Control
# 主選單：開始遊戲 → Game.tscn（序章文字 → 新遊戲專屬的 intro_room 開場）。
# 讀取遊戲 → 共用的《江湖行跡錄》（TITLE_LOAD）。教學模式、離開遊戲尚未開放，按下去只提示。

@onready var _notice: Label = $CanvasLayer/Notice

func _ready():
	$CanvasLayer/WhiteFlash.visible = false
	$CanvasLayer/BlackOverlay.visible = false
	_notice.modulate.a = 0.0
	$ButtonRow/StartButton.pressed.connect(_on_start_button_pressed)
	$ButtonRow/LoadButton.pressed.connect(_on_load_button_pressed)
	for node_name in ["TutorialButton", "ExitButton"]:
		($ButtonRow.get_node(node_name) as BaseButton).pressed.connect(_on_placeholder_pressed.bind(node_name))
	$ButtonRow/OptionButton.pressed.connect(_on_option_button_pressed)

## 選項：開啟與系統頁共用的選項視窗（音量、畫面）
func _on_option_button_pressed() -> void:
	load("res://scripts/ui/OptionsPanel.gd").open(self)

## 讀取遊戲：開啟共用的《江湖行跡錄》（TITLE_LOAD：只能讀，返回回到這個畫面）
func _on_load_button_pressed() -> void:
	ChronicleScreen.open(self, ChronicleScreen.Mode.TITLE_LOAD)

func _on_placeholder_pressed(_button_name: String) -> void:
	_notice.text = "尚未開放"
	_notice.modulate.a = 1.0
	_notice.create_tween().tween_property(_notice, "modulate:a", 0.0, 1.2).set_delay(0.6)

func _on_start_button_pressed() -> void:
	for b in $ButtonRow.get_children():
		(b as BaseButton).disabled = true
	var flash := $CanvasLayer/WhiteFlash
	flash.visible = true
	flash.modulate.a = 1.0
	flash.create_tween().tween_property(flash, "modulate:a", 0.0, 0.5)

	$SwordSound.play()
	await get_tree().create_timer(1.2).timeout

	var overlay := $CanvasLayer/BlackOverlay
	overlay.visible = true
	overlay.modulate.a = 0.0
	var tween := overlay.create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 1.0)

	# 🎵 BGM 淡出
	if $BGM:
		tween.tween_property($BGM, "volume_db", -80, 1.0)

	await get_tree().create_timer(2.0).timeout

	get_tree().change_scene_to_file("res://scenes/Game.tscn")
