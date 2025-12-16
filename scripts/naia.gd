extends CharacterBody2D

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/Naia/Naia headshot.png"
@export var speaker_id := 1
@onready var animated_sprite := $AnimatedSprite2D

@export var wander_range := 240
@export var wander_interval := 1.5
@export var wander_speed := 40.0

var can_show_choices := true
var just_declined := false
var dialog_manager: Node = null
var can_interact := false
var wander_target := Vector2.ZERO
var wander_timer := 0.0
var last_direction := Vector2.DOWN
var last_idle_direction := Vector2.DOWN
var is_talking: bool = false
var has_recently_talked: bool = false

func _ready():
	dialog_manager = get_node("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[警告] DialogManager 沒有抓到")

	wander_target = global_position

	if not SideQuestManager.get_quest("find_cat").has("quest_id"):
		SideQuestManager.register_quest("find_cat", {
			"quest_id": "find_cat",
			"stage": 0,
			"is_finished": false,
			"relationship": 0,
			"flags": {}
		})

func _process(delta):
	z_index = int(global_position.y + z_index_offset)

	if is_talking or has_recently_talked:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = wander_interval
		wander_target = global_position + Vector2(
			randi_range(-wander_range, wander_range),
			randi_range(-wander_range, wander_range))

	var dir = (wander_target - global_position).normalized()
	velocity = dir * wander_speed

	if velocity.length() > 1:
		last_direction = dir
		var anim_name = _get_anim_by_vector(dir, "walk")
		if animated_sprite.sprite_frames.has_animation(anim_name):
			animated_sprite.play(anim_name)
		else:
			animated_sprite.play("idle_down")
	else:
		velocity = Vector2.ZERO
		if last_direction.distance_to(last_idle_direction) > 0.1:
			last_idle_direction = last_direction
		var idle_anim = _get_anim_by_vector(last_idle_direction, "idle")
		if animated_sprite.sprite_frames.has_animation(idle_anim):
			animated_sprite.play(idle_anim)

	move_and_slide()

func face_towards(target_position: Vector2) -> void:
	var direction = (target_position - global_position).normalized()
	last_direction = direction
	last_idle_direction = direction
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

func show_dialog_sequence(lines: Array) -> void:
	if dialog_manager:
		is_talking = true
		dialog_manager.dialog_sequence_finished.connect(_on_dialog_finished)
		dialog_manager.show_dialog_sequence(lines, self)

func _on_dialog_finished(npc_node: Node2D) -> void:
	if npc_node == self:
		is_talking = false
		has_recently_talked = true
		dialog_manager.dialog_sequence_finished.disconnect(_on_dialog_finished)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = true
		print("流語客進入互動區域")

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = false
		has_recently_talked = false
		print("流語客離開互動區域")

func _unhandled_input(event):
	if not can_interact:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		var player_pos = get_node("/root/GameRoot/LiuYu").global_position
		face_towards(player_pos)
		var quest = SideQuestManager.get_quest("find_cat")
		var stage = int(quest.get("stage", 0))

		if stage == 0:
			if GlobalState.get_flag("declined_find_cat"):
				# 小奈記得你上次拒絕她惹～
				dialog_manager.dialog_sequence_finished.connect(_on_intro_finished)
				show_dialog_sequence([
					{ "text": "哼，你上次說要忙，現在有空理我了嗎？", "speaker": speaker_id, "portrait": portrait_path }
				])
			else:
				dialog_manager.dialog_sequence_finished.connect(_on_intro_finished)
				show_dialog_sequence([
					{ "text": "嗚嗚嗚……我的貓咪不見了，你能幫我找嗎？", "speaker": speaker_id, "portrait": portrait_path }
				])
		elif stage == 1:
			show_dialog_sequence([
				{ "text": "拜託你了！牠叫小花，是一隻白底橘斑的小貓。", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "白底橘斑……嗯？", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" }
			])
		elif stage == 2:
			show_dialog_sequence([
				{ "text": "你真的找到了！謝謝你，太感謝了……", "speaker": speaker_id, "portrait": portrait_path }
			])
			SideQuestManager.complete_quest("find_cat")
			GlobalState.set_flag("found_cat_early", true)
			print("[FLAG] 記錄：提早找到貓咪 found_cat_early = true")


func _on_intro_finished(npc_node: Node2D) -> void:
	if npc_node != self:
		return
	dialog_manager.dialog_sequence_finished.disconnect(_on_intro_finished)

	dialog_manager.show_choice([
		{ "text": "沒問題，交給我！", "callback": Callable(self, "_accept_cat_quest") },
		{ "text": "我有點忙……", "callback": Callable(self, "_decline_cat_quest") },
	])

func _accept_cat_quest():
	dialog_manager.choice_box.hide_choices()
	show_dialog_sequence([
		{ "text": "沒問題，包在我身上", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "我就知道你對我最好了～", "speaker": speaker_id, "portrait": portrait_path },
		{ "action": { "target": "$AnimatedSprite2D", "anim": "happy" } },
		{ "wait": 0.3 },
		{ "text": "拜託你了！牠叫小花，是一隻白底橘斑的小貓！", "speaker": speaker_id, "portrait": portrait_path }
	])
	SideQuestManager.advance_quest("find_cat", 1)

func _decline_cat_quest():
	if just_declined:
		return
	just_declined = true
	GlobalState.set_flag("declined_find_cat", true)
	dialog_manager.choice_box.hide_choices()
	await dialog_manager.show_safe_dialog_sequence([
		{ "text": "我現在有點忙，等等再幫你找嘿", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "好吧～那你要快一點喔～", "speaker": speaker_id, "portrait": portrait_path }
	], self)
	# 把 is_talking 設為 true，直到最後一句講完才釋放
	is_talking = true
	has_recently_talked = false


func reset_dialog_state():
	is_talking = false
	has_recently_talked = false
	just_declined = false
