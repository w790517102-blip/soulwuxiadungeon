
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
var _mark_flag_after_close := false  # 對話結束時才落旗

func _ready():
	dialog_manager = get_node("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[NPC] DialogManager 沒抓到！")

	if use_path_patrol:
		path_ref = get_node_or_null(path_node)
		if path_ref == null:
			push_warning("[NPC] PathFollow2D 沒有設定或找不到：" + str(path_node))
	previous_position = global_position

	var main_stage := _get_main_stage_safely()
	dialog_lines = _build_lines_for_stage(main_stage)

func _build_lines_for_stage(main_stage: int) -> Array:
	var met := GlobalState.get_flag("met_yuheng_dreaming_kid")
	# ❶ 主線前期：首輪完整版 / 其後走精簡循環

	if not met:
		return [
				{ "text": "「大哥哥，我昨晚夢到井裡有條魚跟我說話耶！」", "speaker": 1, "portrait": portrait_path },
				{ "text": "「牠說『快撐不住語魅了、情緒會反噬整個鎮』，我也不知道是什麼意思……」", "speaker": 1, "portrait": portrait_path },
				{ "text": "「後來聽到醉月茶坊的姐姐在彈琴，我就醒了。媽媽還叫我別亂講夢話……」", "speaker": 1, "portrait": portrait_path },
				{ "text": "「可是那魚兒看起來好像真的好急喔……」", "speaker": 1, "portrait": portrait_path },
			]
	else:
		return [
				{ "text": "「不知道夢裡的那條魚兒過得怎樣了?」", "speaker": 1, "portrait": portrait_path },
		]
	if main_stage >= 2:
		return [
				{ "text": "「大哥哥，我又夢到井裡的魚了!!」", "speaker": 1, "portrait": portrait_path },
				{ "text": "「他說‘已經沒事了…‘然後看上去心情很好呢!」", "speaker": 1, "portrait": portrait_path },
			]

	# ❷ 主線中期：對琴音的觀感（循環）
	elif main_stage <= 6:
		return [
			{ "text": "琴聲善，善亦有度。善若過度，亦成執。", "speaker": 1, "portrait": portrait_path },
			{ "text": "此地群情雖平，卻像風停於谷，久之易悶。", "speaker": 1, "portrait": portrait_path },
		]

	# ❸ 主線後期：拿到白鳶橫天之後（循環）
	else:
		return [
			{ "text": "白鳶橫天，像給谷口開了一道風眼。", "speaker": 1, "portrait": portrait_path },
			{ "text": "願君持衡，弦不傷人，心不傷己。", "speaker": 1, "portrait": portrait_path },
		]

func _process(delta):
	z_index = int(global_position.y + z_index_offset)

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
		if is_talking:
			return
		is_talking = true
		var liuyu := get_node("/root/GameRoot/LiuYu")
		liuyu.can_move = false
		face_towards(liuyu.global_position)

		# ✅ 這行是關鍵：在互動瞬間依目前旗標/主線重新組台詞
		var main_stage := _get_main_stage_safely()
		dialog_lines = _build_lines_for_stage(main_stage)

		dialog_manager.show_dialog_sequence(dialog_lines, self)
		_mark_flag_after_close = not GlobalState.get_flag("met_yuheng_dreaming_kid")
func reset_dialog_state():
	get_node("/root/GameRoot/LiuYu").can_move = true
	is_talking = false
	if _mark_flag_after_close:
		GlobalState.set_flag("met_yuheng_dreaming_kid", true)
		_mark_flag_after_close = false
		# 旗標落地後，重建成「精簡循環版」
		dialog_lines = _build_lines_for_stage(_get_main_stage_safely())

func _get_main_stage_safely() -> int:
	var qm := get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("get_main_quest_state"):
		var s: Dictionary = qm.get_main_quest_state()
		return int(s.get("stage", 1))
	qm = get_node_or_null("/root/GameRoot/QuestManager")
	if qm and qm.has_method("get_main_quest_state"):
		var s2: Dictionary = qm.get_main_quest_state()
		return int(s2.get("stage", 1))
	return 1
