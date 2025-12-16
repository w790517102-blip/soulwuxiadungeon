extends CharacterBody2D

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/NPC/Yuheng/xiaohua.png"
@export var speaker_id := 1
@onready var animated_sprite := $AnimatedSprite2D

var dialog_manager: Node = null
var can_interact := false
var dialog_lines := []
var is_talking: bool = false
var has_recently_talked: bool = false

func _ready():
	dialog_manager = get_node("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[小華腳本] 無法取得 DialogManager 節點，請檢查節點路徑是否正確")

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

func _on_interact():
	var stage: int = QuestManager.get_main_quest_state()["stage"]
	face_towards(get_node("/root/GameRoot/LiuYu").global_position)

	if stage == 1:
		dialog_lines = [
			{ "text": "真是的,小奈的貓又亂跑了...", "speaker": speaker_id, "portrait": portrait_path },
			{ "text": "我正在跟小明打賭,有沒有人有辦法找到小奈的貓", "speaker": speaker_id, "portrait": portrait_path },
			{ "text": "你可以去跟小明打聽一下我們的打賭規則是甚麼", "speaker": speaker_id, "portrait": portrait_path }
		]
		show_dialog_sequence(dialog_lines)

	elif stage == 2:
		if GlobalState.get_flag("found_cat_early"):
			dialog_lines = [
				{ "text": "你真的已經找到貓了！？我們都還沒賭完呢！", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "你的表現真是超乎我們預料！", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "那請你再去找小明一次，看看他怎麼說～", "speaker": speaker_id, "portrait": portrait_path },
			]
			show_dialog_sequence(dialog_lines)
			QuestManager.advance_main_quest(3, "主線任務已更新，請找小明確認新的對白")
		else:
			dialog_lines = [
				{ "text": "喔~你剛剛找了小明啊?", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "所以說你甚麼時候找到貓貓的時間點是很重要的喔", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "如果你回去找小明之後,沒有找到貓貓就來跟我說話,就代表你沒有成功幫小奈找到貓了", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "等等!為什麼我能不能成功找到貓,會與跟你們對話的時間點有關?", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "哎呀~你忘了這裡是RPG的世界嗎?這裡的時間推移取決於你甚麼時候觸發事件...", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "換言之,你甚麼時間跟甚麼人說話就決定了這個世界事情發生的先後順序", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "所以囉~加油!", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "...", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			]
			show_dialog_sequence(dialog_lines)
			QuestManager.advance_main_quest(3, "主線任務已更新，請找小明確認新的對白")

	elif stage >= 3:
		dialog_lines = [
			{ "text": "無論結果是如何,你都表現得很棒呢", "speaker": speaker_id, "portrait": portrait_path }
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
