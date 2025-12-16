extends CharacterBody2D

const WALK_SPEED = 160
const RUN_SPEED = 400

var last_direction := Vector2(1, 1).normalized()
var direction := Vector2.ZERO
var can_move := true

@onready var animated_sprite := $AnimatedSprite2D
# 若角色腳底位置與 Sprite 原點不同，可調整這個偏移
@export var z_index_offset := 0

func _ready():
	last_direction = GlobalState.last_facing_direction
	animated_sprite.play(get_idle_anim_name(last_direction))

# ✅ 修正劉語塵在市集觀察事件中，未與NPC對話時 idle 方向過快復原的情況
# 👉 方法：我們在觀察階段暫時停用 `_physics_process()` 裡自動 idle 的動畫播放邏輯
# 👉 實作方式：新增一個 `override_idle_animation` flag 控制轉向動畫是否由事件接管

# --- 增補在原本角色控制腳本中 ---

# 加在你的變數區域
var override_idle_animation := false

# ✅ 替換 `_physics_process()` 中 idle 動畫的判斷
func _physics_process(delta):
	if not can_move:
		return

	direction = Vector2(
		int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left")),
		int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	).normalized()

	var is_running = Input.is_action_pressed("run")
	var speed = RUN_SPEED if is_running else WALK_SPEED
	var prefix = "run" if is_running else "walk"

	if direction != Vector2.ZERO:
		velocity = direction * speed
		last_direction = direction
		animated_sprite.play(get_anim_name(last_direction, prefix))
	else:
		velocity = Vector2.ZERO
		if not override_idle_animation:
			animated_sprite.play(get_idle_anim_name(last_direction))

	move_and_slide()
func get_anim_name(dir: Vector2, prefix: String) -> String:
	return _get_anim_by_vector(dir, prefix)

func get_idle_anim_name(dir: Vector2) -> String:
	return _get_anim_by_vector(dir, "idle")

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

# ✅ 修改 `play_idle_direction()` 讓事件控制 idle 時會設置 override flag
func play_idle_direction(direction_name: String):
	override_idle_animation = true

	var dir_map = {
		"up": Vector2(0, -1),
		"down": Vector2(0, 1),
		"left": Vector2(-1, 0),
		"right": Vector2(1, 0),
		"left_up": Vector2(-1, -1),
		"right_up": Vector2(1, -1),
		"left_down": Vector2(-1, 1),
		"right_down": Vector2(1, 1),
	}

	if dir_map.has(direction_name):
		last_direction = dir_map[direction_name].normalized()
		animated_sprite.play(get_idle_anim_name(last_direction))

# ✅ 加一個讓外部事件在結束時恢復正常 idle 控制的函式
func restore_idle_control():
	override_idle_animation = false

func _process(delta):
	if GlobalState.get_meta("menu_open", false):
		return  # 系統選單開啟時不讓角色動
	# 正常移動邏輯
	
	# 角色的 z_index 隨 y 座標更新（整數避免浮點亂序）
	z_index = int(global_position.y + z_index_offset)
