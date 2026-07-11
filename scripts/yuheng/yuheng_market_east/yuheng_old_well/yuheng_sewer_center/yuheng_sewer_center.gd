extends Node2D

@onready var yuheng_old_well: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_old_well.tscn"
@onready var yuheng_sewer_secret_room: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_secret_room/yuheng_sewer_secret_room.tscn"
@onready var yuheng_sewer_talisman_room: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_talisman_room/yuheng_sewer_talisman_room.tscn"
@onready var yuheng_sewer_alchemy_room: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_alchemy_room/yuheng_sewer_alchemy_room.tscn"
@onready var yuheng_sewer_final_room: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_final_room/yuheng_sewer_final_room.tscn"
@onready var overlay := $BlackOverlay
@export var music_tag := "yuheng"
@export var map_display_name: String = "玉衡鎮下水道中央"


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

func _on_to_yuheng_old_well_body_entered(body: Node2D):
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_sewer_center"
		get_node("/root/GameRoot").change_map_to(yuheng_old_well)


func _on_to_yuheng_sewer_secrect_room_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_sewer_center"
		get_node("/root/GameRoot").change_map_to(yuheng_sewer_secret_room)


func _on_to_yuheng_sewer_talisman_room_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_sewer_center"
		get_node("/root/GameRoot").change_map_to(yuheng_sewer_talisman_room)


func _on_to_yuheng_sewer_alchemy_room_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_sewer_center"
		get_node("/root/GameRoot").change_map_to(yuheng_sewer_alchemy_room)


func _on_to_yuheng_sewer_final_room_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_sewer_center"
		get_node("/root/GameRoot").change_map_to(yuheng_sewer_final_room)
