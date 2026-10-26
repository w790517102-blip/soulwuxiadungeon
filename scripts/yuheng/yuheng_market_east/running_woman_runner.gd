extends CharacterBody2D
## 跑龍套的跑步婦人：沿路徑跑來跑去，沒有台詞，也不跟主角互動。
## （秋嬸的支線「一把四季豆」是洗衣婦人 Wash_woman 的事，邏輯在 running_woman.gd。）

@export var z_index_offset := 0
@export var wander_speed := 60.0
@export var path_node: NodePath

@onready var animated_sprite := $AnimatedSprite2D
var path_ref: PathFollow2D = null
var patrol_progress := 0.0
var previous_position: Vector2 = Vector2.ZERO
var last_direction := Vector2.DOWN


func _ready() -> void:
	path_ref = get_node_or_null(path_node)
	if path_ref == null:
		push_warning("[NPC] 跑步婦人的 PathFollow2D 沒有設定或找不到：" + str(path_node))
	previous_position = global_position


func _process(delta: float) -> void:
	z_index = int(global_position.y + z_index_offset)
	if path_ref == null:
		return
	patrol_progress += wander_speed * delta
	path_ref.progress = patrol_progress
	var new_position := path_ref.global_position
	var movement_dir := (new_position - previous_position).normalized()
	global_position = new_position
	_play_walk_anim(movement_dir)
	previous_position = new_position


func _play_walk_anim(dir: Vector2) -> void:
	if dir.length() < 0.1:
		return
	last_direction = dir
	var anim_name := _anim_for(dir, "walk")
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
	else:
		animated_sprite.play("idle_down")


func _anim_for(dir: Vector2, prefix: String) -> String:
	var angle := dir.angle()
	if angle >= -PI * 7 / 8 and angle < -PI * 5 / 8:
		return "%s_left_up" % prefix
	elif angle >= -PI * 5 / 8 and angle < -PI * 3 / 8:
		return "%s_up" % prefix
	elif angle >= -PI * 3 / 8 and angle < -PI * 1 / 8:
		return "%s_right_up" % prefix
	elif angle >= -PI * 1 / 8 and angle < PI * 1 / 8:
		return "%s_right" % prefix
	elif angle >= PI * 1 / 8 and angle < PI * 3 / 8:
		return "%s_right_down" % prefix
	elif angle >= PI * 3 / 8 and angle < PI * 5 / 8:
		return "%s_down" % prefix
	elif angle >= PI * 5 / 8 and angle < PI * 7 / 8:
		return "%s_left_down" % prefix
	return "%s_left" % prefix
