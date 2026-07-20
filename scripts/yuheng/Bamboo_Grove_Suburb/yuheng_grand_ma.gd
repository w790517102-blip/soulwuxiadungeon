# 竹林郊外：阿婆 NPC
extends CharacterBody2D

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/empty.png"
@export var speaker_id := 1
@export var liuyu_portrait_path := "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"
@export var liuyu_speaker_id := 2

@onready var animated_sprite := $AnimatedSprite2D

const ITEM_LUNCHBOX := "item_gushi_lunchbox"
const F_MET_GUSHI := "met_gushi"
const F_LUNCHBOX_RECEIVED := "main_yh_lunchbox_received"
const F_LUNCHBOX_DELIVERED := "main_yh_lunchbox_delivered"
const F_GUSHI_REQUEST_REPORT_GRANDMA := "main_yh_gushi_request_report_grandma"
const F_GRANDMA_REPORTED := "main_yh_grandma_reported"
const OBJECTIVE_DELIVER_LUNCHBOX := "將阿婆的便當送到飲月山莊門衛顧石手中。"

var dialog_manager: Node = null
var can_interact := false
var dialog_lines: Array = []
var _is_talking := false
var _pending_add_lunchbox := false
var _pending_report_grandma := false


func _ready():
	dialog_manager = get_node_or_null("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[阿婆] DialogManager 沒抓到！")
	dialog_lines = _build_lines_for_state()


func _process(_delta):
	z_index = int(global_position.y + z_index_offset)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = true


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = false


func _unhandled_input(event):
	if not can_interact or _is_talking:
		return
	if dialog_manager == null or bool(dialog_manager.get("dialog_active")):
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_is_talking = true
		_clear_pending_actions()
		dialog_lines = _build_lines_for_state()
		var liuyu := get_node_or_null("/root/GameRoot/LiuYu")
		if liuyu:
			liuyu.set("can_move", false)
			face_towards(liuyu.global_position)
		dialog_manager.show_dialog_sequence(dialog_lines, self)


func _build_lines_for_state() -> Array:
	_clear_pending_actions()

	if GlobalState.get_flag(F_GUSHI_REQUEST_REPORT_GRANDMA) and not GlobalState.get_flag(F_GRANDMA_REPORTED):
		_pending_report_grandma = true
		return _build_report_grandma_lines()

	if GlobalState.get_flag(F_LUNCHBOX_RECEIVED) and not GlobalState.get_flag(F_LUNCHBOX_DELIVERED):
		return _build_lunchbox_reminder_lines()

	if not GlobalState.get_flag(F_LUNCHBOX_RECEIVED):
		_pending_add_lunchbox = true
		return _build_first_lunchbox_request_lines(GlobalState.get_flag(F_MET_GUSHI))

	return _build_after_lunchbox_delivered_lines()


func _build_first_lunchbox_request_lines(has_met_gushi: bool) -> Array:
	var lines: Array = [
		_l("……", liuyu_speaker_id, liuyu_portrait_path),
		_l("這地方雖不算荒僻，但山路來往難測。老人家獨自在此睡著，未免危險。", liuyu_speaker_id, liuyu_portrait_path),
		_l("這位老太，醒醒。", liuyu_speaker_id, liuyu_portrait_path),
		_l("唔……嗯？"),
		_l("誰？！"),
		_l("你站那麼近做什麼？想偷我籃子啊？"),
		_l("若要偷，方才便不會叫醒你。", liuyu_speaker_id, liuyu_portrait_path),
		_l("哼，巧言令色鮮矣仁。"),
		_l("這倒是真的。", liuyu_speaker_id, liuyu_portrait_path),
		_l("……"),
		_l("你這小子，怎麼連反駁都懶得反駁？"),
		_l("我只是提醒阿婆，野外打瞌睡不太安全。", liuyu_speaker_id, liuyu_portrait_path),
		_l("我那是打瞌睡嗎？我那是在……閉目養神。"),
		_l("養得挺沉。", liuyu_speaker_id, liuyu_portrait_path),
		_l("你——"),
		_l("唉……人老了，連生氣都嫌費力。"),
		_l("少俠，你別站得那麼筆直……我看了就更來氣。"),
		_l("阿婆可是遇上難事？", liuyu_speaker_id, liuyu_portrait_path),
		_l("難事？哼，是蠢事。我那個兒子——"),
		_l("……算了。你不是本地人吧？眼神像在找路，又像在找人。"),
		_l("我想去飲月山莊。", liuyu_speaker_id, liuyu_portrait_path),
		_l("飲月山莊……你也要去那裡？"),
		_l("好！你要去正好！"),
		_l("？", liuyu_speaker_id, liuyu_portrait_path),
		_l("我家顧石一早便上山守門去了，走得匆忙，連便當都沒帶。"),
	]
	if has_met_gushi:
		lines.append_array([
			_l("顧石？可是飲月山莊門前那位年輕門衛？", liuyu_speaker_id, liuyu_portrait_path),
			_l("正是他。少俠已經見過啦？"),
		])
	lines.append_array([
		_l("他那個死腦筋，值勤就是值勤，餓肚子也不肯回來拿！"),
		_l("阿婆要我替你送去？", liuyu_speaker_id, liuyu_portrait_path),
		_l("我才不是求你！我是——委託。"),
		_l("江湖人不是最講這個嗎？有來有往，兩不相欠。"),
		_l("竹林那段路，對我這把老骨頭太折騰了。你幫我跑一趟，算我……記你一份好。"),
		_l("門衛會因此放我進去？", liuyu_speaker_id, liuyu_portrait_path),
		_l("少做夢。我那兒子要是連便當和規矩都分不清，就不是我養大的。"),
		_l("我還以為這便當能當通行令。", liuyu_speaker_id, liuyu_portrait_path),
		_l("便當是便當，規矩是規矩。"),
		_l("那孩子不壞，就是死板。你若只想討方便，他一眼就看穿。"),
		_l("但你若真有事要見左先生……就別只說漂亮話。"),
		_l("那該說什麼？", liuyu_speaker_id, liuyu_portrait_path),
		_l("說人話。"),
		_l("……我明白了。", liuyu_speaker_id, liuyu_portrait_path),
		_l("拿著。別摔了，摔了我會更生氣。"),
		_n("取得物品：阿婆的便當"),
		_n("主線目標更新：將阿婆的便當送到飲月山莊門衛顧石手中。"),
	])
	return lines


func _build_lunchbox_reminder_lines() -> Array:
	return [
		_l("便當可別擱涼了。"),
		_l("顧石就在山門前，交給他便是。"),
	]


func _build_report_grandma_lines() -> Array:
	return [
		_l("便當已交到顧石手上。", liuyu_speaker_id, liuyu_portrait_path),
		_l("哼。算他還沒笨到連飯都不接。"),
		_l("他讓我回來看一眼，確認阿婆是否安好。", liuyu_speaker_id, liuyu_portrait_path),
		_l("那孩子……嘴上不說，心裡倒還記得我這把老骨頭。"),
		_l("他記得。只是說得少。", liuyu_speaker_id, liuyu_portrait_path),
		_l("說得少也好，少說少錯。可飯不能少吃。"),
		_l("顧石既讓我回來報平安，想必也該趁此時通報左飲了。", liuyu_speaker_id, liuyu_portrait_path),
	]


func _build_after_lunchbox_delivered_lines() -> Array:
	return [
		_l("山路難走，少俠來回奔波，也多留神。"),
		_l("顧石那孩子若還是死板，你也別太氣。"),
	]


func _l(text: String, speaker: int = -1, portrait: String = "") -> Dictionary:
	var resolved_speaker := speaker_id if speaker < 0 else speaker
	var resolved_portrait := portrait_path if portrait == "" else portrait
	return {
		"text": "「%s」" % text,
		"speaker": resolved_speaker,
		"portrait": resolved_portrait,
	}


func _n(text: String) -> Dictionary:
	return {
		"text": text,
		"speaker": 0,
		"portrait": "",
	}


func _clear_pending_actions() -> void:
	_pending_add_lunchbox = false
	_pending_report_grandma = false


func _apply_pending_actions() -> void:
	if _pending_add_lunchbox:
		GlobalState.set_flag(F_LUNCHBOX_RECEIVED, true)
		_add_item_safely(ITEM_LUNCHBOX, 1)
		_set_main_objective_safely(OBJECTIVE_DELIVER_LUNCHBOX)
	if _pending_report_grandma:
		GlobalState.set_flag(F_GRANDMA_REPORTED, true)
	_clear_pending_actions()


func _add_item_safely(item_id: String, amount: int = 1) -> void:
	if InventorySync and InventorySync.has_method("add_item_stack"):
		InventorySync.add_item_stack(item_id, amount, true)
		return

	var inv := get_node_or_null("/root/InventoryManager")
	if inv and inv.has_method("add_item"):
		inv.add_item(item_id, amount)
		return

	inv = get_node_or_null("/root/GameRoot/InventoryManager")
	if inv and inv.has_method("add_item"):
		inv.add_item(item_id, amount)
		return

	push_warning("[阿婆] 找不到可用 Inventory API，無法發放：%s" % item_id)


func _set_main_objective_safely(text: String) -> void:
	var qm := get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("set_main_objective"):
		qm.set_main_objective(text)
		return

	qm = get_node_or_null("/root/GameRoot/QuestManager")
	if qm and qm.has_method("set_main_objective"):
		qm.set_main_objective(text)


func face_towards(target_position: Vector2) -> void:
	var direction = (target_position - global_position).normalized()
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
	return "%s_left" % prefix


func reset_dialog_state():
	var liuyu := get_node_or_null("/root/GameRoot/LiuYu")
	if liuyu:
		liuyu.set("can_move", true)
	_is_talking = false
	_apply_pending_actions()
	dialog_lines = _build_lines_for_state()
	if animated_sprite.sprite_frames.has_animation("idle_left_down"):
		animated_sprite.play("idle_left_down")
