# ✅ 白箋居詩人劇情：分段音樂控制版
extends CharacterBody2D

@export var portrait_path := "res://assets/sprites/empty.png"
@onready var MoonlightPlayer := $yuxin_moonlight_hint
@onready var QinSoundPlayer := $QinSound
@onready var animated_sprite := $AnimatedSprite2D
@onready var dialog_manager := get_node("/root/GameRoot/DialogManager")
@onready var music_player := get_node("/root/GameRoot/MusicPlayer")
@export var z_index_offset := 0

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

	MoonlightPlayer.stop()
	MoonlightPlayer.volume_db = -80
	QinSoundPlayer.stop()
	QinSoundPlayer.volume_db = -80

func _process(delta):
	z_index = int(global_position.y + z_index_offset)

	if is_talking or has_recently_talked:
		velocity = Vector2.ZERO
		return

func _unhandled_input(event):
	if not can_interact or is_talking:
		return
	if event.is_action_pressed("ui_accept"):
		if is_talking:
			return

		is_talking = true
		var liuyu := get_node("/root/GameRoot/LiuYu")
		liuyu.can_move = false
		face_towards(liuyu.global_position)

		var stage := _get_main_stage_safely()
		var met := GlobalState.get_flag("met_bai_jian_jue_guestA")

		if stage < 3 and not met:
			dialog_sequence_start()  # ✅ 讀詩 + 音樂劇情（完整版）
			GlobalState.set_flag("met_bai_jian_jue_guestA", true)

		elif stage < 3 and met:
			# ✅ 已讀過詩，劇情已壓制，重複對白（機械回應）
			await dialog_manager.show_dialog_sequence([
				{ "text": "(語氣平淡)「總之，少俠，有空在聊吧」", "speaker": 1, "portrait": portrait_path },
			], self)
			is_talking = false
			liuyu.can_move = true

		else:
			# ✅ 主線第3章以後，琴聲已鬆動，詩人回復神智
			await dialog_manager.show_dialog_sequence([
				{ "text": "「書眠又繼續寫詩了!」", "speaker": 1, "portrait": portrait_path },
				{ "text": "「而且街上的琴聲也換了個調，聽著也沒再覺得悶了。」", "speaker": 1, "portrait": portrait_path },
				{ "text": "「你還記得那天我念著《燈影欲語》，結果整個人突然\n什麼都說不出來嗎？」", "speaker": 1, "portrait": portrait_path },
				{ "text": "「那種…明明心裡很想哭，但眼淚就是被什麼壓住的感覺…」", "speaker": 1, "portrait": portrait_path },
				{ "text": "（他低頭摩挲著詩集的封面）「好像忽然之間，整座鎮都靜下來，只剩琴音。」", "speaker": 1, "portrait": portrait_path },
				{ "text": "「但最近…我好像可以再度聽見她的句子了。」", "speaker": 1, "portrait": portrait_path },
			], self)
			is_talking = false
			liuyu.can_move = true


func dialog_sequence_start():
	var liuyu := get_node("/root/GameRoot/LiuYu")
	liuyu.can_move = false
	await dialog_manager.show_dialog_sequence([
		{ "text": "「這篇《臨風寄影》，依舊是好句……只是配著琴聲讀起來，感覺沒有從前\n那樣澎湃了。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "「我記得初次讀她的詩，是在家母病榻前……那句『燈影欲語人未歸』，\n真是讓我……」", "speaker": 1, "portrait": portrait_path },
		{ "text": "（他輕嘆一聲）「只是現在，琴音日日不歇，情緒都平得像水。要落淚……\n反倒難了。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "（他將手上的詩集遞給你）「喏，你看。」", "speaker": 1, "portrait": portrait_path },
		{ "text": "(你接過了詩集，並仔細閱讀…)" , "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
	], self)

	await _fade_music(music_player, -50, 2.0)
	MoonlightPlayer.volume_db = 1
	MoonlightPlayer.play()
	await dialog_sequence_poetry()

func dialog_sequence_poetry():
	await dialog_manager.show_dialog_sequence([
		{ "text": "《臨風寄影》｜書眠著", "speaker": 1, "portrait": portrait_path },
		{ "text": "一、《入夜無聲》\n   月照街前石，聲息已無塵。\n   靜中尋舊夢，風過只驚魂。", "speaker": 1, "portrait": portrait_path },
		{ "text": "二、《燈下字緩》\n   墨起輕燈下，筆筆皆欲言。\n   無人問稿尾，自候夜微寒。", "speaker": 1, "portrait": portrait_path },
		{ "text": "三、《檐雨記》\n   檐前雨落薄，簷後思難平。\n   魂似草間滴，緩緩入壺聲。", "speaker": 1, "portrait": portrait_path },
		{ "text": "四、《重讀》\n   詩往復再讀，意卻不同初。\n   是誰昨日淚，今朝不敢書。", "speaker": 1, "portrait": portrait_path },
		{ "text": "五、《空堂聽雪》\n   空堂白雪厚，氣冷不進杯。\n   我欲添火暖，薪盡心亦灰。", "speaker": 1, "portrait": portrait_path },
		{ "text": "六、《燈影欲語》\n   書燈未滅時，影動似人回。\n   欲語人未歸，餘暖倚窗猜。", "speaker": 1, "portrait": portrait_path },
		{ "text": "七、《臨風寄影》\n   一身不敢響，風中寄影行。\n   若逢知我者，且替我聞聲。", "speaker": 1, "portrait": portrait_path },
		{ "text": "(將詩讀完之後，你沉默了一會…)" , "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "劉語塵：「…」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "劉語塵：「這詩句，如同月光穿透紙窗，朦朧卻明亮…」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "劉語塵：「有種『想把內心的感受寫出來，卻窮盡千字萬言\n也無法真實道出』的那種酸楚」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "(正當你沉浸在感動的氛圍時)", "speaker": 1, "portrait": portrait_path },
		{ "text": "(話還沒說完，你便自覺注意力漸漸地被屋外街上琴聲吸引過去…)", "speaker": 1, "portrait": portrait_path },
	], self)

	MoonlightPlayer.stop()
	await _fade_music(music_player, -50, 1.5)
	QinSoundPlayer.volume_db = -1
	QinSoundPlayer.play()
	await dialog_sequence_qin()

func dialog_sequence_qin():
	await dialog_manager.show_dialog_sequence([
		{ "text": "(琴音逐漸覆蓋了你剛剛讀完詩句之後，殘留在內心的感動餘韻…)", "speaker": 1, "portrait": portrait_path },
		{ "text": "劉語塵：「唔!太詭異了!本來街上的琴音應當是柔和的，\n怎麼突然聽起來像是浪濤一樣」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "劉語塵：「正在…一點一滴的…把剛剛讀完詩集的感受給…」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "(你的心跳被旋律壓制而不再悸動，剛剛的感動彷彿不存在似的)", "speaker": 1, "portrait": portrait_path },
	], self)

	QinSoundPlayer.stop()
	await _fade_music(music_player, 0, 1.5)
	await dialog_sequence_final()

func dialog_sequence_final():
	await dialog_manager.show_dialog_sequence([
		{ "text": "(你望著手上的詩集，頓時覺得它不過是普通的書本而已)", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "劉語塵：「怎麼回事?這就是琴音壓制內心的狀況嗎?人還在，\n但感情突然被消除，頓時對剛剛還在為詩句感動的自己十分陌生」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "劉語塵：「像是人格被抽離一樣…」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "(你抬頭看著面前剛剛遞詩集給你的詩人。)", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "「…」", "speaker": 1, "portrait": portrait_path },
		{ "text": "「奇怪，我們在做甚麼呢?」", "speaker": 1, "portrait": portrait_path },
		{ "text": "(他將你手中的詩集拿回去)「總之，少俠，有空在聊吧」", "speaker": 1, "portrait": portrait_path },
		{ "text": "(他的頭別了過去，只留下錯愕的你)」", "speaker": 1, "portrait": portrait_path },
	], self)
	var liuyu := get_node("/root/GameRoot/LiuYu")
	liuyu.can_move = true  # ✅ 解鎖
	is_talking = false

func _fade_music(player: Node, target_volume: float, duration: float) -> void:
	if not player or not (player is AudioStreamPlayer or player is AudioStreamPlayer2D):
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", target_volume, duration)
	await tween.finished

func face_towards(target_position: Vector2):
	var direction = (target_position - global_position).normalized()
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

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = true

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = false
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
