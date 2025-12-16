# ✅ 玉衡市集琴音事件觸發腳本（支援 BGM 淡入淡出、琴音延遲）
extends Node2D

var triggered := false
@onready var dialog_manager := get_node("/root/GameRoot/DialogManager")
@onready var player := get_node("/root/GameRoot/LiuYu")
@onready var area := $Area2D
@onready var liuyu_path := $LiuyuMarketMelody/PathFollow2D
@onready var audio_player := $QinSound
@onready var music_player := get_node("/root/GameRoot/MusicPlayer")

func _ready():
	if GlobalState.get_flag("event_yuheng_market_melody"):
		queue_free()
		return
	area.body_entered.connect(_on_player_entered)

func _on_player_entered(body):
	if triggered or not body.name == "LiuYu":
		return
	triggered = true
	player.can_move = false
	
	await _move_liuyu_along_path()
	await get_tree().create_timer(0.5).timeout
	
	dialog_manager.show_dialog_sequence([
		{ "text": "這裡就是玉衡鎮的市集對吧。", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "人多口雜,我應該更能打聽到左飲的情報。", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "(打量四周)...", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "但是,我怎麼覺得這街氣氛有點怪?", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "(你發現鎮上的人表情平靜、口不多言,安靜地在做自己的事情\n只有不遠處輕柔的琴聲薄薄地覆蓋在整條街上)", "speaker": 2, "portrait": "res://assets/sprites/empty.png" },
	])
	await dialog_manager.dialog_sequence_finished
	await _fade_music(-30, 2.0)  # 淡出 BGM
	audio_player.play()
	dialog_manager.show_choice([
		{ "text": "仔細觀察", "callback": Callable(self, "_observe_area") },
		{ "text": "徑直前行", "callback": Callable(self, "_skip_scene") }
	])

func _observe_area():
	dialog_manager.choice_box.hide_choices()
	player.animated_sprite.play(player.get_idle_anim_name(Vector2(0, -1)))
	await get_tree().create_timer(0.5).timeout
	player.animated_sprite.play(player.get_idle_anim_name(Vector2(-1, 0)))
	await get_tree().create_timer(0.5).timeout
	player.animated_sprite.play(player.get_idle_anim_name(Vector2(1, 0)))
	await get_tree().create_timer(0.5).timeout
	player.animated_sprite.play(player.get_idle_anim_name(Vector2(0, -1)))
	await get_tree().create_timer(0.5).timeout
	dialog_manager.show_dialog_sequence([
		
		{ "text": "是我的錯覺嗎?明明市集應該要人聲鼎沸,但為什麼大家如此\n輕聲細語只剩悠悠琴音繚繞整個街道?", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "不過...這琴音...聽了之後內心的確是平靜不少", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "...不對!這個感覺", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "是內力!有高人將內力注入琴音以壓制人心!", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "到底是誰?為什麼要這麼做呢?", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "也許我該留意一下這個琴音對鎮民的影響...", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "也順便追查琴音的來源好了。", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
	])
	await dialog_manager.dialog_sequence_finished
	GlobalState.set_flag("event_market_choice_observe", true)
	GlobalState.set_flag("event_yuheng_market_melody", true)
	audio_player.stop()
	await _fade_music(0, 1.2)  # 淡入 BGM
	player.can_move = true
	queue_free()

func _skip_scene():
	dialog_manager.choice_box.hide_choices()
	dialog_manager.show_dialog_sequence([
		{ "text": "……（內心一陣悸動，但仍決定無視）", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "市集中的氣氛怪怪的……但也許只是我想太多。", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "不過我滿在意這琴音的", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "有空去看看是誰有那般雅致，奏這曲。", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "（遠方微弱的琴聲若有似無，村民喃喃自語）", "speaker": 2, "portrait": "res://assets/sprites/empty.png" },
		{ "text": "路人甲：……茶坊的那位女伶……總是靜靜地……", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
		{ "text": "路人乙：唉，最近雖然脾氣好像變好了，但也不知道\n為什麼有些提不起勁……", "speaker": 1 },
	])
	await dialog_manager.dialog_sequence_finished

	GlobalState.set_flag("event_yuheng_market_melody", true)
	audio_player.stop()
	await _fade_music(0, 1.5)  # 淡入 BGM
	player.can_move = true
	queue_free()

func _move_liuyu_along_path():
	var duration := 1.2
	var timer := 0.0
	while timer < duration:
		timer += get_process_delta_time()
		liuyu_path.progress_ratio = timer / duration
		player.global_position = liuyu_path.global_position
		player.animated_sprite.play("walk_right_up")
		await get_tree().process_frame
	player.animated_sprite.play(player.get_idle_anim_name(Vector2(1, -1)))

func _fade_music(target_volume: float, duration: float):
	if not music_player:
		return
	var tween := create_tween()
	tween.tween_property(music_player, "volume_db", target_volume, duration)
	await tween.finished
