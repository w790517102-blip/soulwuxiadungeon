extends CharacterBody2D

class_name TalkableNPC

@export var face_target: NodePath
@export var move_enabled := true

@onready var _animation_tree: AnimationTree = $AnimationTree
@onready var _area_2d: Area2D = $Area2D
#@onready var _tween: Tween = $Tween
@onready var _label_timer: Timer = $LabelTimer

var _default_speed := 20.0
var _direction := Vector2.ZERO
var _player_in_area := false

func _ready():
	if face_target:
		face_towards(get_node(face_target).global_position)

	_area_2d.body_entered.connect(_on_body_entered)
	_area_2d.body_exited.connect(_on_body_exited)

func _physics_process(delta):
	if move_enabled and not _player_in_area:
		_wander(delta)
	else:
		velocity = Vector2.ZERO
		move_and_slide()

func _wander(delta):
	# NPC 自由行走邏輯可放這裡（可自訂）
	pass

func _on_body_entered(body):
	if body.name == "劉語塵":
		_player_in_area = true
		face_towards(body.global_position)

func _on_body_exited(body):
	if body.name == "劉語塵":
		_player_in_area = false

func face_towards(target_position: Vector2):
	var direction = (target_position - global_position).normalized()
	_direction = direction
	_update_animation_by_direction(direction)

func _update_animation_by_direction(dir: Vector2):
	var anim = _get_anim_by_vector(dir, "idle")
	_animation_tree.set("parameters/State/current", anim)

func _get_anim_by_vector(dir: Vector2, prefix: String) -> String:
	if abs(dir.x) > abs(dir.y):
		return prefix + ("_right" if dir.x > 0 else "_left")
	else:
		return prefix + ("_down" if dir.y > 0 else "_up")
