extends Node2D

@export var yuheng_bamboo_outskirts: String = "res://scenes/yuheng/yuheng_bamboo_outskirts/yuheng_bamboo_outskirts.tscn"
@export var yuheng_market_west: String = "res://scenes/yuheng/yuheng_market_west/yuheng_market_west.tscn"
@export var yuheng_market_west_richman_event: String = "res://scenes/yuheng/yuheng_market_west/yuheng_market_west_scene1.tscn"
@onready var overlay := $BlackOverlay
@export var music_tag := "bamboo_path_to_manor"
@export var map_display_name: String = "玉衡鎮竹林郊區"


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

func _on_to_yuheng_market_west_body_entered(body: Node2D) -> void:
	if MapTransitionGuard.can_transition(body, get_node_or_null("to_yuheng_market_west")):
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_Bamboo_Grove_Suburb"
		var destination := yuheng_market_west_richman_event if _should_route_to_richman_scene() else yuheng_market_west
		get_node("/root/GameRoot").change_map_to(destination)


func _should_route_to_richman_scene() -> bool:
	var quest_manager := get_node_or_null("/root/QuestManager")
	if quest_manager == null or not quest_manager.has_method("get_main_quest_state"):
		return false
	var main_quest := quest_manager.call("get_main_quest_state") as Dictionary
	return String(main_quest.get("id", "")) == "main_001" \
		and GlobalState.get_flag("main_yh_manor_closed") \
		and not GlobalState.get_flag("event_baijianju_richman_done")


func _on_to_yuheng_bamboo_jungle_body_entered(body: Node2D) -> void:
	if MapTransitionGuard.can_transition(body, get_node_or_null("to_yuheng_bamboo_jungle")):
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_Bamboo_Grove_Suburb"
		get_node("/root/GameRoot").change_map_to(yuheng_bamboo_outskirts)
