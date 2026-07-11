extends Node2D

@export var yuheng_market_west : String = "res://scenes/yuheng/yuheng_market_west/yuheng_market_west.tscn"
@export var ZueYue_teashop : String = "res://scenes/yuheng/zueyue_teashop/zue_yue_teashop.tscn"
@export var yuheng_outside : String = "res://scenes/yuheng/yuheng_outside.tscn"
@export var yuheng_old_well : String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_old_well.tscn"
@onready var overlay := $BlackOverlay
@export var music_tag := "yuheng"
@export var map_display_name: String = "玉衡鎮市集東邊"


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

func _on_to_yuheng_outside_body_entered(body: Node2D):
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_market_east"
		get_node("/root/GameRoot").change_map_to(yuheng_outside)

func _on_zue_yue_entry_body_entered(body: Node2D):
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_market_east"
		get_node("/root/GameRoot").change_map_to(ZueYue_teashop)

func _on_to_yuheng_market_west_body_entered(body: Node2D):
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_market_east"
		get_node("/root/GameRoot").change_map_to(yuheng_market_west)


func _on_to_yuheng_old_well_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_market_east"
		get_node("/root/GameRoot").change_map_to(yuheng_old_well)
