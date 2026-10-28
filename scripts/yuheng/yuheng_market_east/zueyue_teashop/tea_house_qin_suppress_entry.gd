# 醉月茶坊門口：《臨風寄影》壓情之後、白書眠解釋之前，玩家先跑來茶坊時的特殊演出（只播一次）。
# 掛在醉月茶坊（白天）地圖，跟 tea_house_melody_recall 同一個進門區域；條件與流程見 TeaHouseQinSuppress.gd。
extends Node2D

const Suppress = preload("res://scripts/yuheng/yuheng_market_east/zueyue_teashop/TeaHouseQinSuppress.gd")

@onready var dialog_manager := get_node("/root/GameRoot/DialogManager")
@onready var player := get_node("/root/GameRoot/LiuYu")
@onready var area := $Area2D

var triggered := false


func _ready() -> void:
	if not Suppress.entry_pending():
		queue_free()
		return
	area.body_entered.connect(_on_player_entered)


func _on_player_entered(body: Node) -> void:
	if triggered or body.name != "LiuYu":
		return
	triggered = true
	player.can_move = false
	player.animated_sprite.play(player.get_idle_anim_name(Vector2(1, 1)))
	await get_tree().create_timer(1.5).timeout
	dialog_manager.show_dialog_sequence(Suppress.entry_part1())
	await dialog_manager.dialog_sequence_finished
	dialog_manager.show_dialog_sequence(Suppress.entry_part2())
	await dialog_manager.dialog_sequence_finished

	GlobalState.set_flag(Suppress.F_ENTRY_DONE, true)
	GlobalState.set_flag(Suppress.F_MELODY_RECALL, true)   # 琴音已親耳聽過；舊的「循聲而來」演出不用再播
	player.can_move = true
	queue_free()
