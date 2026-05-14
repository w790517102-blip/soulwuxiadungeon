# 客棧用路人 NPC 通用腳本模板
extends CharacterBody2D

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/NPC/Yuheng/Zhe_yen_won_headshot.png"
@export var speaker_id := 1
@onready var animated_sprite := $AnimatedSprite2D

var dialog_manager: Node = null
var can_interact := false
var dialog_lines: Array = []
var _mark_flag_after_close := false

func _ready():
	dialog_manager = get_node("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[客棧路人] DialogManager 沒抓到！")
		
	dialog_lines = [
		{ "text": "「少俠，可曾聽過『邪典』之名？」", "speaker": 1, "portrait": portrait_path },
		{ "text": "劉語塵:「行走江湖，有所耳聞。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "「那可不是尋常鬼怪妖邪，而是比語魅更難防的東西。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "「怎麼說呢……你昨夜讀的詩集，隔日一翻，內容忽地變了\n字句還是熟悉的，但讀著讀著，就覺得心裡哪裡怪怪的。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "「再細看，你會發現它開始勸你做些奇怪的事……像是每天\n吞一片指甲，或是焚香拜影子。 更可怕的是，你會相信那\n就是對的。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "「這便是邪典之厲害——潛進你的思維，改你念頭，奪你人格，\n偏偏它不靠妖氣、不現形，只靠一頁頁文字，一句句語言。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "「更棘手的是，讀過的人若轉述給旁人，那偏執的情緒竟能\n感染聽者，讓你沒碰過那本書，也會走火入魔。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "「目前還沒什麼有效法子。最保險的，就是少讀書、少與\n偏執者言語。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "「不過話說回來……玉衡鎮這地兒，最出名的便是書。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "「理應早就邪典橫行才對，但你看，鎮子安安靜靜，書墨坊\n照開不誤……這其中啊，定有古怪。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "「凡安靜得過了頭，十有八九，不是有高人坐鎮，就是……\n怪事正在壓著不動。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "劉語塵:「(震驚)這玉衡鎮外表看似祥和，當真有這麼不平凡?」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "劉語塵:「(思索)嗯…還得處處留心便是。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "劉語塵:「(拱手作揖)謝前輩告誡。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
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
	if $AnimatedSprite2D.sprite_frames.has_animation(anim_name):
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
			_mark_flag_after_close = not bool(GlobalState.get_flag("met_zhe_yen_won"))
	if dialog_manager.dialog_active:
		return
func reset_dialog_state():
	if _mark_flag_after_close:
		GlobalState.set_flag("met_zhe_yen_won", true)
		_mark_flag_after_close = false
	get_node("/root/GameRoot/LiuYu").can_move = true
