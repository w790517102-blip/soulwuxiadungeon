extends Area2D

var can_interact := false
var has_found_cat := false

var lines := [
	{ "text": "白底橘斑...這隻貓該不會？", "speaker": 2, "portrait": "res://assets/sprites/player_portrait.png" },
	{ "text": "(這八成就是小奈的貓貓──小花吧？)", "speaker": 2, "portrait": "res://assets/sprites/player_portrait.png" },
	{ "text": "找到了!我得趕緊把她帶回小奈身邊。", "speaker": 2, "portrait": "res://assets/sprites/player_portrait.png" }
]

@onready var dialog_manager := get_node("/root/GameRoot/DialogManager")
@onready var hint_label := get_tree().get_current_scene().get_node("CanvasLayer/HintLabel")
@onready var meow_label := $meowLabel

func _ready():
	meow_label.visible = true

func _on_body_entered(body):
	if body.name == "LiuYu" and not has_found_cat:
		can_interact = true
		show_hint("喵～")

func _on_body_exited(body):
	if body.name == "LiuYu":
		can_interact = false
		hide_hint()

func _unhandled_input(event):
	if not can_interact or has_found_cat:
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		var quest = SideQuestManager.get_quest("find_cat")
		var stage = int(quest.get("stage", 0))

		if stage == 0:
			await dialog_manager.show_main_story_dialog("好可愛的貓貓啊...還是別打擾牠吧。", "res://assets/sprites/player_portrait.png", 2, self)
			return

		# ✅ 正式進入支線流程
		has_found_cat = true
		hide_hint()
		await dialog_manager.show_dialog_sequence(lines, self)
		SideQuestManager.advance_quest("find_cat", 2)
		meow_label.visible = false

func show_hint(text):
	if hint_label:
		hint_label.text = text
		hint_label.visible = true

func hide_hint():
	if hint_label:
		hint_label.visible = false
