extends Node2D

@export var Bamboo_Grove_Suburb: String = "res://scenes/yuheng/Bamboo_Grove_Suburb/Bamboo_Grove_Suburb.tscn"
@export var Bai_Jian_Jue: String = "res://scenes/yuheng/yuheng_market_west/Bai_Jian_Jue/bai_jian_jue.tscn"
@export var yuheng_pharmacy: String = "res://scenes/yuheng/yuheng_market_west/yuheng_pharmacy/yuheng_pharmacy.tscn"
@export var yuheng_market_east: String = "res://scenes/yuheng/yuheng_market_east/yuheng_market_east.tscn"
@export var yuheng_weapon_shop: String = "res://scenes/yuheng/yuheng_market_west/yuheng_weapon_shop/yuheng_weapon_shop.tscn"
@onready var overlay := $BlackOverlay
@export var music_tag := "yuheng"


func _ready():
	overlay.modulate.a = 1.5
	var tween_in = overlay.create_tween()
	tween_in.tween_property(overlay, "modulate:a", 0.0, 1.5)
	await tween_in.finished
	
	show_map_name()

func show_map_name():
	var map_popup = get_node_or_null("CanvasLayer/MapNamePopup")
	if map_popup:
		map_popup.text = "玉衡鎮市集西邊"
		map_popup.visible = true
		map_popup.modulate.a = 1.0
		await get_tree().create_timer(2.0).timeout
		var popup_tween = map_popup.create_tween()
		popup_tween.tween_property(map_popup, "modulate:a", 0.0, 1.5)
		await popup_tween.finished
		map_popup.visible = false
	else:
		push_warning("MapNamePopup 找不到！請確認 CanvasLayer 裡有加 Label")

func _on_to_yuheng_market_east_body_entered(body: Node2D):
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_market_west"
		get_node("/root/GameRoot").change_map_to(yuheng_market_east)


func _on_to_yuheng_weapon_shop_body_entered(body: Node2D):
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_market_west"
		get_node("/root/GameRoot").change_map_to(yuheng_weapon_shop)


func _on_pharmacy_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_market_west"
		get_node("/root/GameRoot").change_map_to(yuheng_pharmacy)


func _on_to_bai_jian_jue_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_market_west"
		get_node("/root/GameRoot").change_map_to(Bai_Jian_Jue)


func _on_to_bamboo_grove_suburb_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_market_west"
		get_node("/root/GameRoot").change_map_to(Bamboo_Grove_Suburb)
