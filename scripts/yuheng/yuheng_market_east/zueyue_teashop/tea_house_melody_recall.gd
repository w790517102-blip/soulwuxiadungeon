# 📜 檔名建議：tea_house_melody_recall.gd
# 掛在醉月茶坊地圖的某個 Area2D 下
extends Node2D

@onready var dialog_manager := get_node("/root/GameRoot/DialogManager")
@onready var player := get_node("/root/GameRoot/LiuYu")
@onready var area := $Area2D

var triggered := false

func _ready():
	# 若市集未選擇「觀察」，或事件已觸發過，則不執行
	if not GlobalState.get_flag("event_market_choice_observe") or GlobalState.get_flag("event_tea_house_melody_recall"):
		queue_free()
		return
	area.body_entered.connect(_on_player_entered)

func _on_player_entered(body):
	if triggered or body.name != "LiuYu":
		return
	triggered = true
	player.can_move = false
	player.animated_sprite.play(player.get_idle_anim_name(Vector2(1, 1)))
	await get_tree().create_timer(1.5).timeout
	dialog_manager.show_dialog_sequence([
		{ "text": "…", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "這琴聲!果然是從這裡傳出的。", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "鎮上的情緒……被它壓得很穩。", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "不只是音律技藝，而是一種封印——將話、情緒、甚至靈魂……\n壓入音中。", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "這琴功…不,是內功爐火純青,才能讓做到壓制整個玉衡鎮的人,\n心卻絲毫不紊亂的境界", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "但我總覺得有什麼東西，被壓在那旋律裡更深的地方…", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
	])
	await dialog_manager.dialog_sequence_finished

	GlobalState.set_flag("event_tea_house_melody_recall", true)
	player.can_move = true
	queue_free()
