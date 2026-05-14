
extends CharacterBody2D

const ShopUI = preload("res://scripts/ui/ShopUI.gd")

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/empty.png"
@export var speaker_id := 1
@export var wander_range := 240
@export var wander_interval := 1.5
@export var wander_speed := 60.0
@export var use_path_patrol := true
@export var path_node: NodePath
@export var shop_id: String = "yuheng_general_store_d"

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
var _open_shop_after_dialog := false

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
	var met := GlobalState.get_flag("met_yuheng_store_keeper_d")
	var event_market_choice_observe := GlobalState.get_flag("event_market_choice_observe")
	var event_yuheng_market_melody := GlobalState.get_flag("event_yuheng_market_melody")
	# ❶ 主線前期：首輪完整版 / 其後走精簡循環
	if event_market_choice_observe and event_yuheng_market_melody:
		if not met:
			return [
				{ "text": "「火折子、細線、香包都有。少俠缺什麼喊一聲。」", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
  				{ "text": "劉語塵:「老闆，這琴音聽著心都靜了，不曉得有沒有影響到\n大伙的買心?」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "「少俠多慮了!!最近大家脾氣倒是不大，買東西也不殺價了，省心。」", "speaker": 1 },
				{ "text": "「只不過(小聲說道)…情緒像麻線，扯得太緊會斷，太鬆又散。」", "speaker": 1 },
				{ "text": "「琴聲把線攏住，但打結也要講方法，免得打死了，勒著…」", "speaker": 1 },
				{ "text": "「不過我的產品少俠你大可放心!!。」", "speaker": 1 },
				{ "text": "「輕巧好用不易打結，要不要考慮一下?」", "speaker": 1 },
				{ "text": "劉語塵:「...」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				
]
	if main_stage <= 2:
		if event_market_choice_observe and event_yuheng_market_melody and met:
			return [
				{ "text": "「總之繩線工具多備點在身。」", "speaker": 1, "portrait": portrait_path },
				{ "text": "「要實用的，別花俏；江湖路長，輕省要緊。」", "speaker": 1, "portrait": portrait_path },
			]
		else:
			return [
				{ "text": "「喲!小哥!行走江湖要帶點繩線工具嗎?」", "speaker": 1, "portrait": portrait_path },
				{ "text": "「都是實用的，不花俏；江湖路長，輕省要緊。」", "speaker": 1, "portrait": portrait_path },
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
		# ✅ 在 reset_dialog_state 裡落旗與重建台詞
		_mark_flag_after_close = not GlobalState.get_flag("met_yuheng_store_keeper_d")
		_open_shop_after_dialog = true

func reset_dialog_state():
	var liuyu = get_node("/root/GameRoot/LiuYu")
	liuyu.can_move = true
	is_talking = false
	if _mark_flag_after_close:
		GlobalState.set_flag("met_yuheng_store_keeper_d", true)
		_mark_flag_after_close = false
		# 旗標落地後，重建成「精簡循環版」
		dialog_lines = _build_lines_for_stage(_get_main_stage_safely())
	if _open_shop_after_dialog:
		_open_shop_after_dialog = false
		_dealing()

func _dealing():
	is_talking = true
	var liuyu = get_node("/root/GameRoot/LiuYu")
	liuyu.can_move = false
	await ShopUI.open_shop(shop_id, liuyu)
	is_talking = false
	liuyu.can_move = true


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
