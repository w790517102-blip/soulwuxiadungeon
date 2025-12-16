# 武器店老闆腳本（已修正避免中斷他人對話時卡死）
extends CharacterBody2D

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/empty.png"
@export var speaker_id := 1
@onready var animated_sprite := $AnimatedSprite2D

var dialog_manager: Node = null
var can_interact := false
var dialog_lines: Array = []
var has_recently_talked := false
var is_talking := false
var _after_dialog_action := ""

func _ready():
	dialog_manager = get_node("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[NPC] DialogManager 沒抓到！")

func _process(_delta):
	z_index = int(global_position.y + z_index_offset)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = true

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = false
		has_recently_talked = false

func _unhandled_input(event):
	if not can_interact or is_talking:
		return
	if dialog_manager and dialog_manager.dialog_active:
		return  # 如果已有人在說話了，就不要投入

	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		is_talking = true
		var player = get_node("/root/GameRoot/LiuYu")
		player.can_move = false
		face_towards(player.global_position)
		show_intro_dialog()

func show_intro_dialog():
	dialog_lines = [
		{ "text": "「老規矩，先看藥再談價。補氣、止痛、回神…你要哪一類？」", "speaker": speaker_id, "portrait": portrait_path }
	]
	dialog_manager.dialog_sequence_finished.connect(_on_intro_finished)
	dialog_manager.show_dialog_sequence(dialog_lines, self)

func _on_intro_finished(npc_node):
	if npc_node != self:
		return
	dialog_manager.dialog_sequence_finished.disconnect(_on_intro_finished)
	is_talking = false
	dialog_manager.show_choice([
		{ "text": "交易", "callback": Callable(self, "_dealing") },
		{ "text": "閒聊", "callback": Callable(self, "_chat") }
	])

func _dealing():
	dialog_manager.choice_box.hide_choices()
	is_talking = true
	dialog_lines = [
		{ "text": "「唉…最近大家有事都悶在心裡，深怕說出來會亂了鎮上和謐。」", "speaker": speaker_id, "portrait": portrait_path },
		{ "text": "「但病悶著反倒更傷元氣。」", "speaker": speaker_id, "portrait": portrait_path }
	]
	dialog_manager.dialog_sequence_finished.connect(_on_done_reset)
	dialog_manager.show_dialog_sequence(dialog_lines, self)

func _chat():
	dialog_manager.choice_box.hide_choices()
	is_talking = true
	dialog_lines = [
		{ "text": "劉語塵:「最近在鎮上聽人提起邪典，本以為會有不少人急著來\n把個脈、問個藥……」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "劉語塵:「怎地這藥鋪反倒冷清，半個人影也沒見著？」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },

		{ "text": "藥翁：「哼，這你就不懂了。邪典不是風寒發熱那路，它是從心底\n滲出來的東西。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "藥翁：「可現在醉月茶坊的琴壓著全鎮的情緒，人人表面平靜如水，\n心裡怎麼樣也說不上來。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "藥翁：「本來人哪裡不舒服，知道該來看病；但現在連『不舒服』\n這感覺都沒了，還會想來醫館嗎？」", "speaker": 1, "portrait": portrait_path },
		{ "text": "藥翁：「情緒悶著，病灶藏著，心也懶得動——這病啊，就越養越深了。」", "speaker": 1, "portrait": portrait_path },

		{ "text": "(一名小孩端著藥盤走過，低聲自言自語）「簡單說啦～大家現在連哪裡痛\n都不想知道，還怎麼吃藥咧～」", "speaker": 1, "portrait": portrait_path },

		{ "text": "藥翁：「豆芽！沒大沒小……你當這是在講相聲、唱雙簧麼！」", "speaker": 1, "portrait": portrait_path },
		{ "text": "藥翁：「（轉向你）唉……讓客倌見笑了，這是我那不成材的小徒兒。」", "speaker": 1, "portrait": portrait_path },

		{ "text": "劉語塵：「無妨，小孩子話直倒是點得透。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "劉語塵：「（輕聲）不過……要是有哪個人的情緒真冒出頭來了，\n反倒容易被當成異樣……那時候才真正麻煩吧？」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },

		{ "text": "藥翁：「（沉聲）正是這道理。氣順了、情卻悶，病難診，藥難開。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "藥翁：「到時不是藥醫病，而是病拖心，人還沒發熱，先被困在\n自己裡頭了。」", "speaker": 1, "portrait": portrait_path },

		{ "text": "豆芽：「（小聲）所以說嘛……心病最難醫。」", "speaker": 1, "portrait": portrait_path }

	]
	dialog_manager.dialog_sequence_finished.connect(_on_done_reset)
	dialog_manager.show_dialog_sequence(dialog_lines, self)

func _on_done_reset(npc_node):
	if npc_node != self:
		return
	dialog_manager.dialog_sequence_finished.disconnect(_on_done_reset)
	is_talking = false
	has_recently_talked = true
	get_node("/root/GameRoot/LiuYu").can_move = true

func face_towards(target_position: Vector2):
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
