extends CharacterBody2D

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/NPC/Yuheng/xiaoming.png"
@export var speaker_id := 1
@onready var animated_sprite := $AnimatedSprite2D

var dialog_manager: Node = null
var can_interact := false
var dialog_lines := []
var stage := 0
var is_talking: bool = false
var has_recently_talked: bool = false

func _ready():
	dialog_manager = get_node("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[警告] DialogManager 沒抓到！請確認路徑")

func _process(_delta):
	z_index = int(global_position.y + z_index_offset)

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

func show_dialog_sequence(lines: Array) -> void:
	if dialog_manager:
		dialog_manager.show_dialog_sequence(lines)
	else:
		push_warning("[警告] DialogManager 為 null，無法顯示對話。")

func _on_interact():
	stage = QuestManager.get_main_quest_state()["stage"]
	face_towards(get_node("/root/GameRoot/LiuYu").global_position)

	if stage == 1:
		if GlobalState.get_flag("found_cat_early"):
			dialog_lines = [
				{ "text": "等等！你說你已經找到小奈的貓了！？", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "我們本來還在打賭你會不會找到呢...結果你早就找到了。", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "那幫我轉告小華一聲吧，就說你真的找到了貓！", "speaker": speaker_id, "portrait": portrait_path },
			]
			show_dialog_sequence(dialog_lines)
			QuestManager.advance_main_quest(2, "請找小華說話")
		else:
			dialog_lines = [
				{ "text": "小奈的貓不知道第幾次躲起來了", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "然後我這次在跟小華打賭,看你有沒有辦法幫小奈找回他的貓貓", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "怎麼呀?有沒有興趣加入我們賭局啊?你可以跟小華談談喔, 他會告訴你該怎麼進行這個遊戲~", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "你們要賭甚麼、怎麼賭無所謂,我只要能夠幫小奈找到貓貓就好", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			]
			show_dialog_sequence(dialog_lines)
			QuestManager.advance_main_quest(2, "請找小華說話")

	elif stage == 2:
		dialog_lines = [
			{ "text": "看來你是真心真意想要幫助小奈呢~那我提示一下:地圖上是否看到喵喵叫?", "speaker": speaker_id, "portrait": portrait_path },
			{ "text": "...多謝", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "(低頭思索)用看的啊", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		]
		show_dialog_sequence(dialog_lines)

	elif stage >= 3:
		dialog_lines = [
			{ "text": "辛苦你了!", "speaker": speaker_id, "portrait": portrait_path }
		]
		show_dialog_sequence(dialog_lines)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = true
		print("流語客進入互動區域")

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = false
		print("流語客離開互動區域")

func _unhandled_input(event):
	if can_interact and event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		print("空白鍵被按下，觸發互動")
		_on_interact()

func reset_dialog_state():
	is_talking = false
	has_recently_talked = false
