extends CharacterBody2D

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/empty.png"
@export var speaker_id := 1
@export var wander_range := 240
@export var wander_interval := 1.5
@export var wander_speed := 60.0
@export var use_path_patrol := true
@export var path_node: NodePath

@onready var animated_sprite := $AnimatedSprite2D
var dialog_manager: Node = null
var can_interact := false
var dialog_lines: Array = []
var wander_target := Vector2.ZERO
var wander_timer := 0.0
var last_direction := Vector2.DOWN
var last_idle_direction := Vector2.DOWN
var is_talking: bool = false
var has_recently_talked: bool = false
var patrol_progress := 0.0
var path_ref: PathFollow2D = null
var previous_position: Vector2 = Vector2.ZERO

func _ready():
	dialog_manager = get_node("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[NPC] DialogManager 沒抓到！")

	if use_path_patrol:
		path_ref = get_node_or_null(path_node)
		if path_ref == null:
			push_warning("[NPC] PathFollow2D 沒有設定或找不到：" + str(path_node))

	previous_position = global_position

	dialog_lines = [
		{ "text": "「趁今天天氣好，趕快把衣服洗乾淨曬起來。」", "speaker": speaker_id, "portrait": portrait_path },
	]

func _process(delta):
	z_index = int(global_position.y + z_index_offset)

	if is_talking or has_recently_talked:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if use_path_patrol and path_ref:
		# 路徑復視點移動
		patrol_progress += wander_speed * delta
		path_ref.progress = patrol_progress
		var new_position = path_ref.global_position
		var movement_dir = (new_position - previous_position).normalized()
		global_position = new_position
		_play_directional_anim(movement_dir)
		previous_position = new_position
		return
	else:
		# 隨機移動模式
		wander_timer -= delta
		if wander_timer <= 0.0:
			wander_timer = wander_interval
			wander_target = global_position + Vector2(
				randi_range(-wander_range, wander_range),
				randi_range(-wander_range, wander_range))

		var dir = (wander_target - global_position).normalized()
		velocity = dir * wander_speed

		if velocity.length() > 1:
			_play_directional_anim(dir)
		else:
			velocity = Vector2.ZERO
			if last_direction.distance_to(last_idle_direction) > 0.1:
				last_idle_direction = last_direction
			var idle_anim = _get_anim_by_vector(last_idle_direction, "idle")
			if animated_sprite.sprite_frames.has_animation(idle_anim):
				animated_sprite.play(idle_anim)

		move_and_slide()

func _play_directional_anim(dir: Vector2):
	if dir.length() < 0.1:
		return
	last_direction = dir
	var anim_name = _get_anim_by_vector(dir, "walk")
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
	else:
		animated_sprite.play("idle_down")

func _get_anim_by_vector(dir: Vector2, prefix: String) -> String:
	var angle = dir.angle()
	if angle >= -PI * 7/8 and angle < -PI * 5/8:
		return "%s_left_up" % prefix
	elif angle >= -PI * 5/8 and angle < -PI * 3/8:
		return "%s_up" % prefix
	elif angle >= -PI * 3/8 and angle < -PI * 1/8:
		return "%s_right_up" % prefix
	elif angle >= -PI * 1/8 and angle < PI * 1/8:
		return "%s_right" % prefix
	elif angle >= PI * 1/8 and angle < PI * 3/8:
		return "%s_right_down" % prefix
	elif angle >= PI * 3/8 and angle < PI * 5/8:
		return "%s_down" % prefix
	elif angle >= PI * 5/8 and angle < PI * 7/8:
		return "%s_left_down" % prefix
	else:
		return "%s_left" % prefix

func face_towards(target_position: Vector2) -> void:
	var direction = (target_position - global_position).normalized()
	last_direction = direction
	last_idle_direction = direction
	var anim_name = _get_anim_by_vector(direction, "idle")
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = true

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = false

func _unhandled_input(event):
	if not can_interact:
		return
	if dialog_manager.dialog_active:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		get_node("/root/GameRoot/LiuYu").can_move = false
		var player_pos = get_node("/root/GameRoot/LiuYu").global_position
		face_towards(player_pos)
		if dialog_lines.size() > 0:
			dialog_manager.show_dialog_sequence(dialog_lines, self)
		is_talking = true

func reset_dialog_state():
	get_node("/root/GameRoot/LiuYu").can_move = true
	is_talking = false
