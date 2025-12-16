# 客棧用路人 NPC 通用腳本模板 (支援 Gossip Flag)
extends CharacterBody2D

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/empty.png"
@export var speaker_id := 1
@export var gossip_flag := "heard_oldman_zuoyin" # 例："heard_oldman_leftyin"
@export var trigger_topic := "zuoyin" # 例："leftyin"
@onready var animated_sprite := $AnimatedSprite2D

var dialog_manager: Node = null
var can_interact := false
var dialog_lines: Array = []

func _ready():
	dialog_manager = get_node("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[NPC 通用模板] DialogManager 沒抓到！")

	if dialog_manager:
		dialog_manager.connect("dialog_sequence_finished", Callable(self, "_on_dialogue_finished"))

	if dialog_lines.is_empty():
		dialog_lines = [
			{ "text": "「這平臺啊... 曾經也是第一武堂賽的場地呢...」", "speaker": 1, "portrait": portrait_path },
			{ "text": "「現在少年們不喜歡武學，都去搞那什麼文墨了...」", "speaker": 1, "portrait": portrait_path },
			{ "text": "「嗯？你說左飲啊？我年輕時候和他們也總是在這練演武呢。」", "speaker": 1, "portrait": portrait_path },
			{ "text": "「唉，希望可以再看到一次他的燕行破風斬...」", "speaker": 1, "portrait": portrait_path },
		]

func _process(_delta):
	z_index = int(global_position.y + z_index_offset)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = true

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = false

func face_towards(target_position: Vector2) -> void:
	var direction = (target_position - global_position).normalized()
	var anim_name = _get_anim_by_vector(direction, "idle")
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)

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
			GlobalState.set_flag(gossip_flag, true)

func _on_dialogue_finished(npc_node):
	if npc_node != self:
		return

	# 🎯 這裡就是對話完全播完後的安全時機！
	_check_gossip_topic()


func _check_gossip_topic():
	if trigger_topic == "":
		return

	var flags := [
		"heard_wanderoldman_%s" % trigger_topic,
		"heard_waterwoman_%s" % trigger_topic,
		"heard_oldman_%s" % trigger_topic
	]

	var all_flags_ok := true
	for flag in flags:
		if not GlobalState.get_flag(flag):
			all_flags_ok = false
			break

	if all_flags_ok and not GlobalState.get_flag("triggered_%s_gossip_summary" % trigger_topic):
		GlobalState.set_flag("triggered_%s_gossip_summary" % trigger_topic, true)

		# 🎯 關鍵：等對話完後再播獨白！
		await get_tree().process_frame
		dialog_manager.show_dialog_sequence([
			{ "text": "（看來在鎮民的眼裡，左飲本來是位古道熱腸的俠義之士...）", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "（只是最近出於某些原因鮮少露面了）", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "嗯...", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "再繼續跟更多人打聽些左飲的消息好了。", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		], self)


func reset_dialog_state():
	get_node("/root/GameRoot/LiuYu").can_move = true
