# 夜晚玉衡鎮 forbidden 入口共用腳本
# 掛載位置：各個 forbidden Area2D，例如：
# - bai_jian_jue_forbidden
# - yuheng_weapon_shop_forbidden
# - pharmacy_forbidden
# - Bamboo_Grove_Suburb_forbidden
# 功能：玩家夜晚想進入非主線設施時，播放劉語塵獨白，不切換場景。

extends Area2D

@export var dialog_manager_path: NodePath = "/root/GameRoot/DialogManager"
@export var player_path: NodePath = "/root/GameRoot/LiuYu"
@export var liuyu_portrait_path := "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"
@export var empty_portrait_path := "res://assets/sprites/empty.png"
@export var liuyu_speaker_id := 2
@export var narration_speaker_id := 0

# 留空時使用預設台詞；白箋居可在 Inspector 填入專用台詞。
@export_multiline var custom_lines_text := ""

# 若填入旗標，只有此旗標為 true 時才會阻擋；夜晚副本通常可留空。
@export var required_flag := "main_yh_go_to_zuiyue_huiyin"

var dialog_manager: Node = null
var player: Node = null
var is_talking := false


func _ready() -> void:
	dialog_manager = get_node_or_null(dialog_manager_path)
	player = get_node_or_null(player_path)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if is_talking:
		return
	if body.name != "LiuYu":
		return
	if required_flag != "" and not GlobalState.get_flag(required_flag):
		return
	if dialog_manager == null:
		push_warning("[夜晚禁止入口] 找不到 DialogManager：%s" % str(dialog_manager_path))
		return
	if dialog_manager.dialog_active:
		return

	is_talking = true
	player = body
	if player:
		player.set("can_move", false)

	dialog_manager.show_dialog_sequence(_build_lines(), self)
	await dialog_manager.dialog_sequence_finished

	if player:
		player.set("can_move", true)
	is_talking = false


func reset_dialog_state() -> void:
	if player:
		player.set("can_move", true)
	is_talking = false


func _build_lines() -> Array:
	var raw_lines: Array[String] = []

	if custom_lines_text.strip_edges() != "":
		for line in custom_lines_text.split("\n"):
			var clean := String(line).strip_edges()
			if clean != "":
				raw_lines.append(clean)
	else:
		raw_lines = [
			"現在不是去那裡的時候。",
			"紅徽音的琴聲還在前方……先去醉月茶坊。",
		]

	var lines: Array = []
	for text in raw_lines:
		lines.append(_l(text, liuyu_speaker_id, liuyu_portrait_path))
	return lines


func _l(text: String, speaker: int, portrait: String = "") -> Dictionary:
	return {
		"text": text,
		"speaker": speaker,
		"portrait": portrait if portrait != "" else empty_portrait_path,
	}
