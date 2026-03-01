extends Node2D

@export var in_room : String = "res://scenes/intro_room.tscn"
@export var left_path : String = "res://scenes/yuheng/Bamboo_Grove_Suburb/Bamboo_Grove_Suburb.tscn"
@export var right_path : String = "res://scenes/yuheng_inn_room_03.tscn"
@export var map_display_name: String = "測試房間"
@onready var overlay := $BlackOverlay

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
		await get_tree().create_timer(3.0).timeout
		var popup_tween = map_popup.create_tween()
		popup_tween.tween_property(map_popup, "modulate:a", 0.0, 1.5)
		await popup_tween.finished
		map_popup.visible = false
	else:
		push_warning("MapNamePopup 找不到！請確認 CanvasLayer 裡有加 Label")

func _on_room_exit_body_entered(body):
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_test_room"
		get_node("/root/GameRoot").change_map_to(in_room)

func _on_room_exit_left_body_entered(body):
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_market_west"
		get_node("/root/GameRoot").change_map_to(left_path)
