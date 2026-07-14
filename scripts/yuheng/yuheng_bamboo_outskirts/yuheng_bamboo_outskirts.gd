extends Node2D

@export var Bamboo_Grove_Suburb: String = "res://scenes/yuheng/Bamboo_Grove_Suburb/Bamboo_Grove_Suburb.tscn"
@export var YinYueManor: String = "res://scenes/yuheng/YinYueManor/yin_yue_manor.tscn"
@onready var overlay := $BlackOverlay
@export var music_tag := "station_stillwind"
@export var battle_bgm_path := "res://assets/BGM/battle_1.ogg"
@export var map_display_name: String = "郊外竹林叢"

const BAMBOO_OUTSKIRTS_ZONE_ID := "yuheng_bamboo_outskirts"
const BAMBOO_OUTSKIRTS_ENCOUNTER_CONFIG := {
	"distance_threshold": 540.0,
	"chance": 0.25,
	"cooldown_distance": 320.0,
	"intro_key": "yuheng_bamboo_outskirts_random"
}
const BAMBOO_OUTSKIRTS_ENCOUNTER_TABLE := [
	{"w": 35, "enemies": ["bamboo_macaque", "bamboo_macaque"]},
	{"w": 30, "enemies": ["bamboo_macaque", "bamboo_bobcat"]},
	{"w": 20, "enemies": ["bamboo_wild_boar"]},
	{"w": 10, "enemies": ["bamboo_poison_snake", "bamboo_poison_snake"]},
	{"w": 5, "enemies": ["bamboo_bobcat", "bamboo_poison_snake"]}
]


func _ready():
	overlay.modulate.a = 1.5
	var tween_in = overlay.create_tween()
	tween_in.tween_property(overlay, "modulate:a", 0.0, 1.5)
	await tween_in.finished
	
	show_map_name()

func get_map_display_name() -> String:
	return map_display_name

func get_encounter_zone_config(zone_id: String) -> Dictionary:
	if zone_id == BAMBOO_OUTSKIRTS_ZONE_ID:
		return BAMBOO_OUTSKIRTS_ENCOUNTER_CONFIG.duplicate(true)
	return {}

func get_encounter_table(zone_id: String) -> Array:
	if zone_id == BAMBOO_OUTSKIRTS_ZONE_ID:
		return BAMBOO_OUTSKIRTS_ENCOUNTER_TABLE.duplicate(true)
	return []

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

func _on_to_bamboo_grove_suburb_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_bamboo_outskirts"
		get_node("/root/GameRoot").change_map_to(Bamboo_Grove_Suburb)

func _on_to_yin_yue_manor_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_bamboo_outskirts"
		get_node("/root/GameRoot").change_map_to(YinYueManor)
