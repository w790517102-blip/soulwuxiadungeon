# 客棧用路人 NPC 通用腳本模板
extends CharacterBody2D

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/empty.png"
@export var speaker_id := 1
@onready var animated_sprite := $AnimatedSprite2D

var dialog_manager: Node = null
var can_interact := false
var dialog_lines: Array = []

func _ready():
	dialog_manager = get_node("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[阿婆] DialogManager 沒抓到！")
		
	dialog_lines = [
				{ "text": "劉語塵：「……」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"},
				{ "text": "劉語塵：「這地方雖不算荒僻，但山路來往難測。老人家獨自在此睡著，未免危險。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"},
				{ "text": "劉語塵：「這位老太，醒醒。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"},
				{ "text": "「唔……嗯？」", "speaker": 1, "portrait": portrait_path },#同時切換yuheng_grand_ma動畫為:wake_up
				{ "text": "「誰？！」", "speaker": 1, "portrait": portrait_path },#同時切換yuheng_grand_ma動畫為:confuse
				{ "text": "「你站那麼近做什麼？想偷我籃子啊？」", "speaker": 1, "portrait": portrait_path },#同時切換yuheng_grand_ma動畫為:shout
				{ "text": "劉語塵：「若要偷，方才便不會叫醒你。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"},
				{ "text": "「哼，巧言令色鮮矣仁。」", "speaker": 1, "portrait": portrait_path },
				{ "text": "劉語塵：「這倒是真的。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"},
				{ "text": "「……」", "speaker": 1, "portrait": portrait_path },
				{ "text": "「你這小子，怎麼連反駁都懶得反駁？」", "speaker": 1, "portrait": portrait_path },#同時切換yuheng_grand_ma動畫為:confuse
#	一、竹林郊外：發現阿婆打瞌睡

#場景：玉衡鎮通往飲月山莊的竹林郊外。
#阿婆坐在樹下打瞌睡，旁邊放著竹籃與便當。

#劉語塵：
#「……」

#劉語塵：
#「這地方雖不算荒僻，但山路來往難測。老人家獨自在此睡著，未免危險。」

#劉語塵：
#「阿婆，醒醒。」

#阿婆：
#「唔……嗯？」

#阿婆：
#「誰？！」

#阿婆：
#「你站那麼近做什麼？想偷我籃子啊？」

#劉語塵：
#「若要偷，方才便不會叫醒你。」

#阿婆：
#「哼，巧言令色鮮矣仁。」

#劉語塵：
#「這倒是真的。」

#阿婆：
#「……」

#阿婆：
#「你這小子，怎麼連反駁都懶得反駁？」

#劉語塵：
#「我只是提醒阿婆，野外打瞌睡不太安全。」

#阿婆：
#「我那是打瞌睡嗎？我那是在……閉目養神。」

#劉語塵：
#「養得挺沉。」

#阿婆：
#「你——」

#阿婆：
#「唉……人老了，連生氣都嫌費力。」

#阿婆：
#「少俠，你別站得那麼筆直……我看了就更來氣。」

#二、阿婆說出便當委託

#劉語塵：
#「阿婆可是遇上難事？」

#阿婆：
#「難事？哼，是蠢事。我那個兒子——」

#阿婆：
#「……算了。你不是本地人吧？眼神像在找路，又像在找人。」

#劉語塵：
#「我想去飲月山莊。」

#阿婆：
#「飲月山莊……你也要去那裡？」

#阿婆：
#「好！你要去正好！」

#劉語塵：
#「？」

#阿婆：
#「我那笨兒子在飲月山莊當門衛，今早出門像被狗追，便當忘了帶！」

#阿婆：
#「他那個死腦筋，值勤就是值勤，餓肚子也不肯回來拿！」

#分歧 A：若玩家未調查市集琴音

#直接接一般委託。

#劉語塵：
#「阿婆要我替你送去？」

#阿婆：
#「我才不是求你！我是——委託。」
#「江湖人不是最講這個嗎？有來有往，兩不相欠。」
#阿婆：
#「竹林那段路，對我這把老骨頭太折騰了。你幫我跑一趟，算我……記你一份好。」

#分歧 B：若玩家曾調查市集琴音

#追加異常感。

#劉語塵：
#「他既是山莊門衛，做事應該謹慎。怎會連便當都忘？」

#阿婆：
#「……你這話，倒問到我心裡去了。」

#阿婆：
#「顧石從前再趕，也不會忘飯。可這幾日，他像是把自己也當成門閂，站著、守著、硬撐著。」

#劉語塵：
#「阿婆是說，他變了？」

#阿婆：
#「我說不上。做娘的只知道，人若真的盡責，不該連怎麼照顧自己都不會。」

#劉語塵：
#「……」

#阿婆：
#「罷了，這些話說了也沒用。你若真要去飲月山莊，就替我把這便當帶去。」

#三、阿婆說明顧石與山莊門檻

#劉語塵：
#「門衛會因此放我進去？」

#阿婆：
#「少做夢。我那兒子要是連便當和規矩都分不清，就不是我養大的。」

#劉語塵：
#「我還以為這便當能當通行令。」

#阿婆：
#「便當是便當，規矩是規矩。」

#阿婆：
#「那孩子不壞，就是死板。你若只想討方便，他一眼就看穿。」

#阿婆：
#「但你若真有事要見左先生……就別只說漂亮話。」

#劉語塵：
#「那該說什麼？」

#阿婆：
#「說人話。」

#劉語塵：
#「……我明白了。」

#阿婆：
#「拿著。別摔了，摔了我會更生氣。」

#系統提示：
#取得物品：阿婆的便當
#接取任務：阿婆的便當

#七、回報阿婆，取得竹徑香包

#場景：竹林郊外或山道下方。

#劉語塵：
#「便當已交到顧石手上。」

#阿婆：
#「哼。算他還沒笨到連飯都不接。」

#劉語塵：
#「他讓我回來看一眼，確認阿婆是否安好。」

#阿婆：
#「那孩子……嘴上不說，心裡倒還記得我這把老骨頭。」

#劉語塵：
#「他記得。只是說得少。」

#阿婆：
#「說得少也好，少說少錯。可飯不能少吃。」

#劉語塵：
#「他也讓我回去等通報。若左飲願見，他會帶我入莊。」

#阿婆：
#「那不是因為便當。」

#劉語塵：
#「阿婆知道？」

#阿婆：
#「我兒子我還不知道？」

#阿婆：
#「便當只能讓他抬眼看你一眼。能不能進門，還得看你是不是個會把人當人的人。」

#劉語塵：
#「阿婆方才說的人情——」

#阿婆：
#「我不欠你，我是記著。」

#阿婆：
#「拿去。竹林路上野物多，這香包裡放了些鎮上老人常用的草。」

#阿婆：
#「人聞著刺鼻，獸聞著嫌煩。」

#劉語塵：
#「能避獸？」

#阿婆：
#「不能保你一世平安，至少能少些麻煩。」

#阿婆：
#「你這少俠，眼神不張揚，心倒還沒冷。」

#阿婆：
#「別在江湖裡把自己磨鈍了。」

#系統提示：
#獲得飾品：竹徑香包
#完成任務：阿婆的便當

#劉語塵心想：

#「顧石既讓我回來報平安，想必也該趁此時通報左飲了。」

#「算算時候，差不多該回飲月山莊了。」

#「希望這次，山門能開。」

#系統提示：
#主線目標更新：回到飲月山莊，等待顧石答覆。
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
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		get_node("/root/GameRoot/LiuYu").can_move = false
		var player_pos = get_node("/root/GameRoot/LiuYu").global_position
		face_towards(player_pos)
		if dialog_lines.size() > 0:
			dialog_manager.show_dialog_sequence(dialog_lines, self)

func reset_dialog_state():
	get_node("/root/GameRoot/LiuYu").can_move = true
	animated_sprite.play("idle_left_down")
