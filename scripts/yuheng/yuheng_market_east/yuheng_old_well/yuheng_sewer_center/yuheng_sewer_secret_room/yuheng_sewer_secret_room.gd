extends Node2D

@onready var yuheng_sewer_center: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_center.tscn"
@onready var overlay := $BlackOverlay
@export var music_tag := "yuheng_sewer"
@export var map_display_name: String = "玉衡鎮下水道密室"

const SEWER_ZONE_ID := "yuheng_sewer"
const SEWER_SECRET_ROOM_ENCOUNTER_CONFIG := {
	"encounter_region_id": "yuheng_sewer",
	"encounter_profile_id": "yuheng_sewer_pressure_v1",
	"distance_threshold": 240.0,
	"chance": 0.30,
	"cooldown_distance": 280.0,
	"intro_key": "yuheng_sewer_secret_random"
}
const SEWER_SECRET_ROOM_ENCOUNTER_TABLE := [
	{"w": 28, "enemies": ["yumei_sewer_rat", "yumei_sewer_rat"]},
	{"w": 22, "enemies": ["yumei_sewer_rat", "yumei_sewer_bat"]},
	{"w": 14, "enemies": ["yumei_sewer_bat", "yumei_sewer_bat"]},
	{"w": 12, "enemies": ["yumei_sewer_rat", "yumei_sewer_rat", "yumei_sewer_rat"]},
	{"w": 10, "enemies": ["yumei_sewer_rat", "yumei_sewer_rat", "yumei_sewer_bat"]},
	{"w": 8, "enemies": ["turbid_tone_phantom", "yumei_sewer_rat"]},
	{"w": 4, "enemies": ["turbid_tone_phantom", "yumei_sewer_bat"]},
	{"w": 2, "enemies": ["turbid_tone_phantom"]}
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
	if zone_id == SEWER_ZONE_ID:
		return SEWER_SECRET_ROOM_ENCOUNTER_CONFIG.duplicate(true)
	return {}

func get_encounter_table(zone_id: String) -> Array:
	if zone_id == SEWER_ZONE_ID:
		return SEWER_SECRET_ROOM_ENCOUNTER_TABLE.duplicate(true)
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

func _on_to_yuheng_sewer_center_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_sewer_secret_room"
		get_node("/root/GameRoot").change_map_to(yuheng_sewer_center)
