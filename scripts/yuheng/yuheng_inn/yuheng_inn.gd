extends Node2D

@export var go_out : String = "res://scenes/yuheng/yuheng_outside.tscn"
@export var in_room : String = "res://scenes/intro_room.tscn"
@onready var overlay := $BlackOverlay
@export var music_tag := "yuheng_inner"
@export var camera_bounds := Rect2(Vector2.ZERO, Vector2(1097, 815))
@export var camera_lock: bool = false  # 可選；true = 無論大小都鎖定鏡頭於中心
@export var map_display_name: String = "玉衡鎮客棧"

func _ready():
	_bind_exit_zones()
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
	if body.name == "LiuYu" and _exit_allowed(body):
		_leaving = true
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_inn"
		get_node("/root/GameRoot").change_map_to(in_room)


func _on_go_out_body_entered(body: Node2D):
	if body.name == "LiuYu" and _exit_allowed(body):
		_leaving = true
		overlay.visible = true
		overlay.modulate.a = 0.0
		var tween = overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished
		get_node("/root/GameRoot").spawn_point_name = "from_yuheng_inn1"
		get_node("/root/GameRoot").change_map_to(go_out)

## 滑鼠專用的出口（InteractionZones 底下）：點蛋黃區，劉語塵走進蛋白區就換場景，效果與踩進舊的 Into_Room／Go_Out 相同。
const EXIT_TARGETS := {
	"exit_into_room": "_on_into_room_body_entered",
	"exit_go_out": "_on_go_out_body_entered",
}
var _leaving := false

func _bind_exit_zones() -> void:
	var zones := get_node_or_null("InteractionZones")
	if zones == null:
		return
	for child in zones.get_children():
		var target := child as InteractionTarget
		if target == null or not EXIT_TARGETS.has(String(target.name)):
			continue
		var method: String = EXIT_TARGETS[String(target.name)]
		target.availability = func() -> bool: return not _leaving
		target.handler = func(player: Node2D) -> void:
			await call(method, player)

## 與其他場景的出口一致：交給 GameRoot 的出口防呆（剛換場景的冷卻時間、讀檔中、鎖定中都不能換）。
func _exit_allowed(body: Node) -> bool:
	if _leaving:
		return false
	var game_root := get_node_or_null("/root/GameRoot")
	if game_root == null or not game_root.has_method("can_use_map_transition"):
		return true
	return bool(game_root.call("can_use_map_transition", body, null))
