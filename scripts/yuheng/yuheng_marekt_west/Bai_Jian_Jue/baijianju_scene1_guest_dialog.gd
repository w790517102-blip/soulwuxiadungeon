extends CharacterBody2D

@export_enum("guest_a", "guest_b") var guest_id := "guest_a"
@export var portrait_path := "res://assets/sprites/empty.png"
@export var speaker_id := 1
@export var z_index_offset := 0

var can_interact := false
var is_talking := false
var dialog_manager: Node


func _ready() -> void:
	dialog_manager = get_node_or_null("/root/GameRoot/DialogManager")


func _process(_delta: float) -> void:
	# instance-local 對話腳本取代原客人腳本後，仍必須保留專案共用的逐幀 Y/Z 排序。
	z_index = int(global_position.y + z_index_offset)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = true


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = false


func _unhandled_input(event: InputEvent) -> void:
	if not can_interact or is_talking or dialog_manager == null:
		return
	if not GlobalState.get_flag("event_baijianju_richman_done") or GlobalState.get_flag("event_yinpingyu_done"):
		return
	if bool(GlobalState.get_meta("yinpingyu_cutscene_busy", false)):
		return
	if bool(GlobalState.get_meta("menu_locked", false)) or bool(dialog_manager.get("dialog_active")):
		return
	if not (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		return

	is_talking = true
	var player := get_node_or_null("/root/GameRoot/LiuYu") as CharacterBody2D
	if player:
		player.set("can_move", false)
		player.velocity = Vector2.ZERO
	await dialog_manager.call("show_dialog_sequence", _build_lines(), self)


func reset_dialog_state() -> void:
	is_talking = false
	var player := get_node_or_null("/root/GameRoot/LiuYu") as CharacterBody2D
	if player and not bool(GlobalState.get_meta("yinpingyu_cutscene_busy", false)):
		player.velocity = Vector2.ZERO
		player.set("can_move", true)


func _build_lines() -> Array:
	if guest_id == "guest_b":
		return [
			_l("大快人心啊！"),
			_l("那種仗著銀子便想逼人低頭的客人，早該被請出去了。"),
		]
	return [
		_l("書眠姑娘平日說話輕得像翻書。"),
		_l("方才那一句『請出去』，卻嚇得我整個人都坐直了。"),
	]


func _l(text: String) -> Dictionary:
	return {"text": "書客：「%s」" % text, "speaker": speaker_id, "portrait": portrait_path}
