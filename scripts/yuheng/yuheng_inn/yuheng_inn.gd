extends Node2D

@export var go_out : String = "res://scenes/yuheng/yuheng_outside.tscn"
@export var in_room : String = "res://scenes/intro_room.tscn"
@onready var overlay := $BlackOverlay
@export var music_tag := "yuheng_inner"
@export var camera_bounds := Rect2(Vector2.ZERO, Vector2(1097, 815))
@export var camera_lock: bool = false  # 可選；true = 無論大小都鎖定鏡頭於中心
@export var map_display_name: String = "玉衡鎮客棧"

func _ready():
	overlay.modulate.a = 1.5
	var tween_in = overlay.create_tween()
	tween_in.tween_property(overlay, "modulate:a", 0.0, 1.5)
	await tween_in.finished
	
	show_map_name()

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


func _on_into_room_body_entered(body: Node2D):
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_inn"
		get_node("/root/GameRoot").change_map_to(in_room)


func _on_go_out_body_entered(body: Node2D):
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_inn1"
		get_node("/root/GameRoot").change_map_to(go_out)
