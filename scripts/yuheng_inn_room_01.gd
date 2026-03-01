extends Node2D

@export var next_scene_path : String = "res://scenes/yuheng_inn_room_02.tscn"
@export var yuheng_inn : String = "res://scenes/yuheng_inn.tscn"
@export var map_display_name: String = "玉衡鎮客棧房間"

var dialogue_lines = [
	"劉語塵: 「……」",
	"劉語塵: 「飲月山莊的左飲……」",
	"劉語塵: 「玉衡鎮最有頭有臉的人物，傳聞手眼通天、消息靈通……」",
	"劉語塵: 「若真有人知道『那物』的下落，非他莫屬。」",
	"劉語塵: 「可是，我不過一介過客，冒然上門，怕是吃閉門羹吧……」",
	"「...」",
	"劉語塵: 「看樣子我得先在這鎮好好打聽他的情報…」",
	"劉語塵: 「畢竟沒有人比這些鎮民更了解他了。」"
]

@onready var dialogue_ui = $DialogueUI
@onready var dialogue_box = $DialogueUI/DialogueBox
@onready var dialogue_label = $DialogueUI/DialogueBox/Label
@onready var headshot = $DialogueUI/LiuYu_headshot
@onready var mission_popup = $MissionUpdate
@onready var overlay = $BlackOverlay
@onready var overlay2 = $BlackOverlay2

var current_index = 0
var is_typing = false
var skip_typing = false
var is_dialogue_active = true
var fade_in_finished = false
var tween : Tween

func _ready():
	
	# ❗不再實例化流語客，GameRoot 已持有他
	overlay.visible = true
	overlay2.visible = false
	overlay2.modulate.a = 0.0
	overlay.modulate.a = 1.0
	tween = create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, 1.0)

	if not GlobalState.has_meta("intro_done"):
		GlobalState.set_meta("intro_done", false)
		get_node("/root/GameRoot/LiuYu").can_move = false
	if GlobalState.get_meta("intro_done"):
		dialogue_ui.queue_free()
		fade_overlay_in()
		show_map_name()
		return

	dialogue_box.visible = false
	headshot.visible = false
	

	fade_overlay_in()
	await get_tree().create_timer(1.2).timeout
	_start_dialogue()

func fade_overlay_in():
	var tween = overlay.create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, 1.0)

func _start_dialogue():
	dialogue_box.visible = true
	headshot.visible = true
	dialogue_box.modulate.a = 0.0
	headshot.modulate.a = 0.0

	var tween = get_tree().create_tween()
	tween.tween_property(dialogue_box, "modulate:a", 1.0, 0.5)
	tween.tween_property(headshot, "modulate:a", 1.0, 0.4)
	await tween.finished

	fade_in_finished = true
	_show_next_line()

func _show_next_line():
	if current_index >= dialogue_lines.size():
		_end_dialogue()
		return

	is_typing = true
	skip_typing = false
	dialogue_label.text = ""

	var full_text = dialogue_lines[current_index]
	current_index += 1

	for i in full_text.length():
		if skip_typing:
			break
		dialogue_label.text += full_text[i]
		await get_tree().create_timer(0.03).timeout

	dialogue_label.text = full_text
	is_typing = false

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if tween and tween.is_running():
			tween.kill()
			overlay.modulate.a = 0.0

	if not is_dialogue_active or not fade_in_finished:
		return

	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		if is_typing:
			skip_typing = true
		else:
			_show_next_line()

func _end_dialogue():
	get_node("/root/GameRoot/LiuYu").can_move = true
	var tween = get_tree().create_tween() 
	tween.tween_property(dialogue_box, "modulate:a", 0.0, 0.4)
	tween.tween_property(headshot, "modulate:a", 0.0, 0.4)
	await tween.finished
	dialogue_box.visible = false
	headshot.visible = false

	GlobalState.set_meta("intro_done", true)
	var mission_popup = get_node_or_null("CanvasLayer/MissionUpdate")
	# ✅ 推進主線
	if not GlobalState.get_meta("mission_01_updated"):
		QuestManager.advance_main_quest(1, "到飲月山莊拜訪左飲")

		mission_popup.visible = true
	
		mission_popup.modulate.a = 0.0
		tween = get_tree().create_tween()
		tween.tween_property(mission_popup, "modulate:a", 1.0, 0.5)
		await tween.finished

		await get_tree().create_timer(3.0).timeout
		tween = get_tree().create_tween()
		tween.tween_property(mission_popup, "modulate:a", 0.0, 0.5)
		await tween.finished
		mission_popup.visible = false

		GlobalState.set_meta("mission_01_updated", true)
		
	is_dialogue_active = false

func _on_room_exit_body_entered(body):
	if body.name == "LiuYu":
		overlay2.visible = true
		overlay2.modulate.a = 0.0
		var tween = overlay2.create_tween()
		tween.tween_property(overlay2, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_intro_room"
		get_node("/root/GameRoot").change_map_to(next_scene_path)

func get_map_display_name() -> String:
	return map_display_name

func show_map_name():
	var map_popup = get_node_or_null("CanvasLayer/MapNamePopup")
	if map_popup:
		map_popup.text = map_display_name
		map_popup.visible = true
		map_popup.modulate.a = 1.0
		await get_tree().create_timer(2.0).timeout
		var popup_tween = map_popup.create_tween()
		popup_tween.tween_property(map_popup, "modulate:a", 0.0, 1.5)
		await popup_tween.finished
		map_popup.visible = false
	else:
		push_warning("MapNamePopup 找不到！請確認 CanvasLayer 裡有加 Label")


func _on_room_out_body_entered(body: Node2D):
	if body.name == "LiuYu":
		overlay2.visible = true
		overlay2.modulate.a = 0.0
		var tween = overlay2.create_tween()
		tween.tween_property(overlay2, "modulate:a", 1.0, 0.5)
		await tween.finished
		var game_root = get_node_or_null("/root/GameRoot")
		if game_root != null:
			game_root.spawn_point_name = "from_yuheng_inn_room"
			game_root.change_map_to(yuheng_inn)
		else:
			push_warning("[切換場景] GameRoot 尚未載入或不存在！")
