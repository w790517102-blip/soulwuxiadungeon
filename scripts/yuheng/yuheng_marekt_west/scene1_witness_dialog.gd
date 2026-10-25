extends CharacterBody2D

@export_enum("sugar_kid", "scholar", "outlander", "blacksmith") var witness_id := "sugar_kid"
@export var portrait_path := "res://assets/sprites/empty.png"
@export var speaker_id := 1
@export var z_index_offset := 0

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

var dialog_manager: Node
var can_interact := false
var is_talking := false


func _ready() -> void:
	dialog_manager = get_node_or_null("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[暴發戶事件圍觀者] 找不到 DialogManager：%s" % witness_id)


func _process(_delta: float) -> void:
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
	if not GlobalState.get_flag("event_baijianju_richman_done"):
		return
	if bool(dialog_manager.get("dialog_active")) or bool(GlobalState.get_meta("menu_locked", false)):
		return
	if not (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		return

	is_talking = true
	var player := get_node_or_null("/root/GameRoot/LiuYu") as CharacterBody2D
	if player:
		player.set("can_move", false)
		player.velocity = Vector2.ZERO
		_face_towards(player.global_position)
	await dialog_manager.call("show_dialog_sequence", _build_lines(), self)


func reset_dialog_state() -> void:
	is_talking = false
	var player := get_node_or_null("/root/GameRoot/LiuYu") as CharacterBody2D
	if player:
		player.velocity = Vector2.ZERO
		player.set("can_move", true)


func _build_lines() -> Array:
	match witness_id:
		"sugar_kid":
			return [
				_l("大哥哥，你剛剛好帥喔！"),
				_l("那個有錢大叔的臉一下紅、一下白，好像一隻捏麵人喔！"),
			]
		"scholar":
			return [
				_l("唉，偏有人將詩書當作炫耀門面的擺設。"),
				_l("少俠方才那番話，倒替我們說出了想說、卻不敢直言的道理。"),
			]
		"outlander":
			return [
				_l("希望那位土財主，別壞了玉衡鎮對我們這些外鄉人的印象才好……"),
				_l("我們來此做客，多數還是懂得尊重人家規矩的。"),
			]
		"blacksmith":
			return [
				_l("唷！少俠方才那股氣勢，可真像一柄出鞘的龍泉劍！"),
				_l("不必動手，光憑幾句話便逼得人節節後退。好鋒口！"),
			]
	return []


const WITNESS_NAMES := {
	"sugar_kid": "小孩",
	"scholar": "書生",
	"outlander": "外地客",
	"blacksmith": "鐵匠",
}


func _l(text: String) -> Dictionary:
	var who: String = WITNESS_NAMES.get(witness_id, "路人")
	return {"text": "%s：「%s」" % [who, text], "speaker": speaker_id, "portrait": portrait_path}


func _face_towards(target_position: Vector2) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	var direction := (target_position - global_position).normalized()
	var anim_name := _get_anim_by_vector(direction, "idle")
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)


func _get_anim_by_vector(direction: Vector2, prefix: String) -> String:
	var angle := direction.angle()
	if angle >= -PI * 7.0 / 8.0 and angle < -PI * 5.0 / 8.0:
		return "%s_left_up" % prefix
	if angle < -PI * 3.0 / 8.0:
		return "%s_up" % prefix
	if angle < -PI * 1.0 / 8.0:
		return "%s_right_up" % prefix
	if angle < PI * 1.0 / 8.0:
		return "%s_right" % prefix
	if angle < PI * 3.0 / 8.0:
		return "%s_right_down" % prefix
	if angle < PI * 5.0 / 8.0:
		return "%s_down" % prefix
	if angle < PI * 7.0 / 8.0:
		return "%s_left_down" % prefix
	return "%s_left" % prefix
