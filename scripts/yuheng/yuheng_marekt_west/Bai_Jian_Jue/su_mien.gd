extends CharacterBody2D

const ShopUI = preload("res://scripts/ui/ShopUI.gd")

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/NPC/Yuheng/Su_Mien_headshot1.png"
@export var speaker_id := 1
@export var shop_id: String = "bai_jian_jue_bookstore"
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
		push_warning("[TeaGirl] DialogManager 沒抓到！")
	# 若主線已超過 1，視為已遇過（僅用於避免場內重播初見）
	var main_stage := _get_main_stage_safely()
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
	var main_stage := _get_main_stage_safely()
	if _can_open_shop() and stage >= 2:
		_open_shop()
		return
	
	if stage == 1:
		var met_A := GlobalState.get_flag("met_bai_jian_jue_guestA")
		var met_B := GlobalState.get_flag("met_bai_jian_jue_guestB")
		var met_C := GlobalState.get_flag("met_bai_jian_jue_guestC")
		if met_A and met_B and met_C:
			GlobalState.set_flag("met_Su_Mien", true)
			dialog_lines = [
				{ "text": "（櫃台後的女子輕輕將筆擱下，語氣淡淡）「我方才都聽見了。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "女子：「這些話，不是第一次聽見，也不會是最後一次。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "女子：「少俠，忘了跟你介紹，小女子名喚書眠」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "劉語塵：「書眠姑娘你好，在下劉語塵。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "劉語塵：「實在是對不住，書軒本是靜心讀卷的所在。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "劉語塵：「然而我卻如此粗魯大聲嚷嚷，吵到您了。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "書眠：(露出微笑，輕輕搖頭)「沒關係的，我不是在責怪劉少俠。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "書眠：「我只是被你說的話給吸引住了。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "劉語塵：「?」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "書眠：「我曾經相信，詩可以安慰人心——哪怕只是一瞬的共鳴，\n也足夠讓人願意活下去。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "書眠：（語氣低下來）「可現在，每個人都說『你寫得好令人感動，\n真讓人涕淚縱橫』，卻沒有人……真心的笑，真心的哭。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "劉語塵：（沉默片刻）「妳……是因為這樣，才停止寫詩的嗎？」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "書眠：「我不是停筆，只是寫出來的東西……連我自己都感覺\n不到了。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "（她望向遠方，彷彿穿過了書架與人群）", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "書眠：「也許，玉衡鎮不是缺詩；而是……沒有人能夠讓自己再次\n動情了。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "書眠：「我不知道要怎麼寫出一首能讓人哭的詩……當每個人都\n自認『不該』哭的時候。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "劉語塵：「果然……看樣子這鎮真被那琴聲搞得烏煙瘴氣!」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "劉語塵：「在這節骨眼，也絲毫不見左飲的作為……」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "書眠：「…」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "書眠：「你誤會了，劉少俠…」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "書眠：「這鎮會這樣……都是因為我…」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "劉語塵：「?」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "劉語塵：「此話怎說?」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "書眠：(不說話，只是輕輕地搖了搖頭)「你想要見左飲是吧?」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "書眠：「其實左飲他四海皆兄弟，來者不拒。只是為了試探來者的\n真心，他設有一道試煉。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "書眠：「關鍵在於飲月山莊的門衛，如果你能說服得了門衛，那麼\n你就能夠見到左飲。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "書眠：「你可能會想說，這樣豈不是變成要討好門衛而本末倒置了?」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "書眠：「恰恰相反，他反而可以從『你怎麼說服門衛』而得知你是\n怎樣的人。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "劉語塵：「…謝謝書眠姑娘的提點。不過為何你要這樣幫我呢?」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "書眠：(輕閉上眼，露出微笑)「因為我也想讓左飲認識你。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "書眠：「而且，如果是你的話，或許有辦法…」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "書眠：(話未說完)「算了…沒事~」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "劉語塵：「…」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "劉語塵：(拱手作揖)「再次謝過，告辭了，書眠姑娘。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "(點頭，再次露出微笑，但這次她的眼神更柔和了許多)", "speaker": speaker_id, "portrait": portrait_path },
			]
			show_dialog_sequence(dialog_lines)
			QuestManager.advance_main_quest(2, "想辦法說服飲月山莊的門衛")

		else:
			dialog_lines = [
				{ "text": "（櫃台後的女子專心的在書寫）", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "劉語塵：「(看樣子他正在忙著。)」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "劉語塵：「(一時半刻我也不知道來這裡能做啥，此刻我又不需要\n買書。)」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "劉語塵：「(還是先去找店內的客人聊聊好了。)」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			]
			show_dialog_sequence(dialog_lines)
	
	elif stage == 2:
		dialog_lines = [
			{ "text": "書眠：「加油，你一定可以的。」", "speaker": speaker_id, "portrait": portrait_path },
			{ "text": "劉語塵：「...多謝」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "劉語塵：「(先想辦法說服飲月山莊的門衛吧。)」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		]
		show_dialog_sequence(dialog_lines)

	elif stage >= 3:
		dialog_lines = [
			{ "text": "辛苦你了!", "speaker": speaker_id, "portrait": portrait_path }
		]
		show_dialog_sequence(dialog_lines)


func _can_open_shop() -> bool:
	return bool(GlobalState.get_flag("met_Su_Mien")) and _get_main_stage_safely() >= 2


func _open_shop() -> void:
	var liuyu := get_node_or_null("/root/GameRoot/LiuYu")
	if liuyu == null:
		return
	is_talking = true
	liuyu.can_move = false
	await ShopUI.open_shop(shop_id, liuyu)
	liuyu.can_move = true
	is_talking = false

func _get_main_stage_safely() -> int:
	# AutoLoad 版本（建議）
	var qm := get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("get_main_quest_state"):
		var s: Dictionary = qm.get_main_quest_state()
		return int(s.get("stage", 1))

	# 場景內 GameRoot 備援版本
	qm = get_node_or_null("/root/GameRoot/QuestManager")
	if qm and qm.has_method("get_main_quest_state"):
		var s2: Dictionary = qm.get_main_quest_state()
		return int(s2.get("stage", 1))

	push_warning("[TeaGirl] 找不到 QuestManager，主線階段以 1 代替。")
	return 1

func _advance_main_quest_to_2():
	var qm := get_node_or_null("/root/QuestManager")
	if qm == null:
		qm = get_node_or_null("/root/GameRoot/QuestManager")
	if qm and qm.has_method("advance_main_quest"):
		qm.advance_main_quest(2, "想辦法說服飲月山莊的門衛")
	else:
		push_warning("[TeaGirl] QuestManager 不存在或缺 advance_main_quest()，無法推進主線。")

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = true
		print("流語客進入互動區域")

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = false
		print("流語客離開互動區域")

func _unhandled_input(event):
	if not can_interact:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if is_talking:
			return
		is_talking = true

		# ✅ 鎖住劉語塵
		var liuyu := get_node("/root/GameRoot/LiuYu")
		liuyu.can_move = false

		face_towards(liuyu.global_position)
		_on_interact()

		# ✅ 等對話結束
		await dialog_manager.dialog_finished

		# ✅ 解鎖
		liuyu.can_move = true
		is_talking = false

		

func reset_dialog_state():
	is_talking = false
	has_recently_talked = false
