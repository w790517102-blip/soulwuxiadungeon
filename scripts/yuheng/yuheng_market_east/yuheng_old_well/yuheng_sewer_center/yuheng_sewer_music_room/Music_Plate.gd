extends Node2D
class_name MusicPlate

@export_enum("gong", "shang", "jue", "zhi", "yu") var note_id := "gong"
@export var interact_action := "interact"
@export var manager_path: NodePath
@export var audio_player_path: NodePath

@onready var interact_area: Area2D = $Area2D

var player_inside := false
var interaction_locked := false
var manager: MusicRoomManager
var audio_player: AudioStreamPlayer2D
var player_ref: Node = null
var _space_was_down := false


func _ready() -> void:
	manager = _resolve_manager()
	audio_player = _resolve_audio_player()

	if interact_area:
		if not interact_area.body_entered.is_connected(_on_body_entered):
			interact_area.body_entered.connect(_on_body_entered)
		if not interact_area.body_exited.is_connected(_on_body_exited):
			interact_area.body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if player_inside and not interaction_locked and _is_interact_pressed():
		await interact()


func interact() -> void:
	if manager == null:
		manager = _resolve_manager()

	if manager == null:
		push_warning("MusicPlate 找不到 MusicRoomManager")
		return

	interaction_locked = true
	_set_player_movable(false)

	_play_note_sound()
	await manager.try_press_plate(note_id)

	_set_player_movable(true)
	interaction_locked = false


func _play_note_sound() -> void:
	if audio_player == null:
		audio_player = _resolve_audio_player()

	if audio_player and audio_player.stream:
		audio_player.stop()
		audio_player.play()
	else:
		print("踩下石板：", note_id)


func _on_body_entered(body: Node) -> void:
	if _is_player(body):
		player_inside = true
		player_ref = body


func _on_body_exited(body: Node) -> void:
	if _is_player(body):
		player_inside = false
		if player_ref == body:
			player_ref = null


func _is_player(body: Node) -> bool:
	return body.name == "Player" or body.name == "LiuYu" or body.is_in_group("player")


func _is_interact_pressed() -> bool:
	var pressed_by_action := false
	if InputMap.has_action(interact_action):
		pressed_by_action = Input.is_action_just_pressed(interact_action)

	var space_down := Input.is_key_pressed(KEY_SPACE)
	var pressed_by_space := space_down and not _space_was_down
	_space_was_down = space_down

	return pressed_by_action or pressed_by_space


func _set_player_movable(value: bool) -> void:
	var target := player_ref
	if target == null:
		target = get_node_or_null("/root/GameRoot/LiuYu")
	if target == null:
		target = get_node_or_null("/root/Player")

	if target:
		target.set("can_move", value)


func _resolve_manager() -> MusicRoomManager:
	if manager_path != NodePath():
		var node := get_node_or_null(manager_path)
		if node is MusicRoomManager:
			return node

	var parent := get_parent()
	while parent:
		var found := parent.get_node_or_null("MusicRoomManager")
		if found is MusicRoomManager:
			return found

		parent = parent.get_parent()

	return null


func _resolve_audio_player() -> AudioStreamPlayer2D:
	if audio_player_path != NodePath():
		var node := get_node_or_null(audio_player_path)
		if node is AudioStreamPlayer2D:
			return node

	var direct := get_node_or_null("AudioStreamPlayer2D")
	if direct is AudioStreamPlayer2D:
		return direct

	for child in get_children():
		if child is AudioStreamPlayer2D:
			return child

	return null
