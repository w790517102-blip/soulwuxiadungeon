extends Node2D
class_name YuhengSewerTrue

# ------------------------------------------------------------
# 玉衡鎮｜清澈舊水道：《渠燈補封》外層場景
# 掛載：yuheng_sewer_true.tscn 根節點
#
# 本場景功能：
# 1. 進入清澈舊水道後，播放一次書眠與劉語塵的初見對話。
# 2. 調查琴、寫字台、藥櫃，觸發書眠回憶孩子與病人在此學習、養息的往事。
# 3. 翻箱倒櫃取得小獎勵。
# 4. 轉場到 yuheng_sewer_true_room，由藥師舊室完成正式補封。
# ------------------------------------------------------------

@export var music_tag := "yuheng"
@export var map_display_name: String = "玉衡鎮舊水道"

@export_file("*.tscn") var yuheng_old_well: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_old_well.tscn"
@export_file("*.tscn") var yuheng_stalactite_cave: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_final_room/yuheng_stalactite_cave/yuheng_stalactite_cave.tscn"
@export_file("*.tscn") var yuheng_sewer_true_room: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_true/yuheng_sewer_true_room.tscn"

@export var old_well_spawn_point := "from_yuheng_sewer_true"
@export var stalactite_cave_spawn_point := "from_yuheng_sewer_true"
@export var true_room_spawn_point := "from_yuheng_sewer_true"

@export var interact_action := "interact"

@export var empty_portrait_path := "res://assets/sprites/empty.png"
@export var liuyu_portrait_path := "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"
@export var shumian_portrait_path := "res://assets/sprites/Shu_mian/ShuMian_headshot.png"

@export var narration_speaker_id := 0
@export var liuyu_speaker_id := 2
@export var shumian_speaker_id := 4

@onready var overlay: ColorRect = get_node_or_null("BlackOverlay")
@onready var to_yuheng_old_well: Area2D = get_node_or_null("to_yuheng_old_well")
@onready var to_yuheng_stalactite_cave: Area2D = get_node_or_null("to_yuheng_stalactite_cave")
@onready var to_yuheng_sewer_true_room: Area2D = get_node_or_null("to_yuheng_sewer_true_room")

signal dialog_closed

const F_QUDENG_STARTED := "shumian_qudeng_started"
const F_QUDENG_INTRO_SEEN := "shumian_qudeng_intro_seen"

const MEMORY_IDS := [
	"memory_qin",
	"memory_writing_desk",
	"memory_medicine_cabinet",
]

const LOOT_TABLE := {
	"loot_herb_basket": {
		"item_id": "herb",
		"amount": 2,
		"display_name": "藥草",
		"lines": [
			"架旁的小竹籃裡還收著幾束保存良好的藥草。",
			"書眠：這些原是給孩子們認藥用的。現在倒也派得上用場。"
		]
	},
	"loot_qi_box": {
		"item_id": "elixir_qi",
		"amount": 1,
		"display_name": "回氣丹",
		"lines": [
			"一只小木匣藏在書冊後方，匣中躺著一枚藥丸。",
			"書眠：藥師以前常說，學東西不怕慢，只怕氣先亂了。"
		]
	},
	"loot_haste_scroll": {
		"item_id": "haste_talisman",
		"amount": 1,
		"display_name": "神速符",
		"lines": [
			"桌腳旁壓著一張保存完好的疾行符。",
			"劉語塵：這也算藥師留下的東西？",
			"書眠：不，是孩子們追逐打鬧時，偷偷藏在這裡的。",
			"書眠：不過符意還在，應該還能用。"
		]
	},
}

var current_interaction_id := ""
var interaction_locked := false
var transition_locked := false
var _waiting_for_dialog := false
var _space_was_down := false


func _ready() -> void:
	_connect_transition_areas()
	_connect_interaction_areas()

	await _play_entry_fade()
	await show_map_name()

	if not _get_flag(F_QUDENG_INTRO_SEEN, false):
		await _show_intro_once()


func get_map_display_name() -> String:
	return map_display_name


func _process(_delta: float) -> void:
	if current_interaction_id == "":
		return

	if interaction_locked or transition_locked:
		return

	if _is_interact_pressed():
		await _handle_interaction(current_interaction_id)


func _play_entry_fade() -> void:
	if overlay == null:
		return

	overlay.visible = true
	overlay.modulate.a = 1.5

	var tween_in := overlay.create_tween()
	tween_in.tween_property(overlay, "modulate:a", 0.0, 1.5)
	await tween_in.finished


func show_map_name() -> void:
	var map_popup := get_node_or_null("CanvasLayer/MapNamePopup")
	if map_popup:
		map_popup.text = map_display_name
		map_popup.visible = true
		map_popup.modulate.a = 1.0

		await get_tree().create_timer(2.0).timeout

		var popup_tween := map_popup.create_tween()
		popup_tween.tween_property(map_popup, "modulate:a", 0.0, 1.5)
		await popup_tween.finished

		map_popup.visible = false
	else:
		push_warning("MapNamePopup 找不到！請確認 CanvasLayer 裡有加 Label")


func _show_intro_once() -> void:
	interaction_locked = true
	_set_player_movable(false)

	_set_flag(F_QUDENG_STARTED, true)
	_set_flag(F_QUDENG_INTRO_SEEN, true)

	await _show_dialog([
		_n("井下水聲清亮，石壁間藥香未散。"),
		_n("這裡沒有紫黑霧氣，也沒有令人窒息的濕腐味。"),
		_n("燈影照在水面上，竟像照著一條被人細心照料過的溪。"),
		_l("這裡……", liuyu_speaker_id, liuyu_portrait_path),
		_l("是昨夜那條舊水道？", liuyu_speaker_id, liuyu_portrait_path),
		_l("不錯。", shumian_speaker_id, shumian_portrait_path),
		_l("從你驚訝的表情就能明白，昨夜它被壓住的語魅塞得有多重。", shumian_speaker_id, shumian_portrait_path),
		_l("幾乎已經病入膏肓了。", shumian_speaker_id, shumian_portrait_path),
		_n("書眠望著水邊的舊藥架與書案，聲音比平時低了些。"),
		_l("老實說，那時候若不是劉少俠你……", shumian_speaker_id, shumian_portrait_path),
		_l("恐怕這座鎮早就……", shumian_speaker_id, shumian_portrait_path),
		_l("書眠姑娘，不必把話都攬到自己身上。", liuyu_speaker_id, liuyu_portrait_path),
		_l("也不會有人責難你知情不報。", liuyu_speaker_id, liuyu_portrait_path),
		_l("你怕一說出口，亂了左飲和紅徽音的心神，事情不會更好。", liuyu_speaker_id, liuyu_portrait_path),
		_l("……嗯。", shumian_speaker_id, shumian_portrait_path),
		_l("可正因如此，這次我想盡自己的力。", shumian_speaker_id, shumian_portrait_path),
		_l("真正替玉衡鎮，替大家，把隱患補好。", shumian_speaker_id, shumian_portrait_path),
		_l("要我怎麼做？", liuyu_speaker_id, liuyu_portrait_path),
		_l("陪我走一遍。", shumian_speaker_id, shumian_portrait_path),
		_l("這裡記得玉衡鎮原本的樣子。", shumian_speaker_id, shumian_portrait_path),
		_l("而真正要補穩的東西，在藥師舊室。", shumian_speaker_id, shumian_portrait_path),
	])

	_set_player_movable(true)
	interaction_locked = false


func _handle_interaction(interaction_id: String) -> void:
	interaction_locked = true
	_set_player_movable(false)

	if MEMORY_IDS.has(interaction_id):
		await _show_dialog(_build_memory_lines(interaction_id))
	elif LOOT_TABLE.has(interaction_id):
		await _handle_loot(interaction_id)
	else:
		await _show_dialog([
			_n("這裡似乎沒有特別可調查的東西。")
		])

	_set_player_movable(true)
	interaction_locked = false


func _build_memory_lines(memory_id: String) -> Array:
	match memory_id:
		"memory_qin":
			return [
				_n("水邊放著一張舊琴，琴身擦得乾淨，卻已許久無人深彈。"),
				_l("以前孩子們會在這裡學聽五音。", shumian_speaker_id, shumian_portrait_path),
				_l("藥師說，聽得出宮商角徵羽，不是為了風雅。", shumian_speaker_id, shumian_portrait_path),
				_l("是為了讓孩子知道，心亂時，聲音也會亂。", shumian_speaker_id, shumian_portrait_path),
				_l("你也在這裡學琴？", liuyu_speaker_id, liuyu_portrait_path),
				_l("學過一些。", shumian_speaker_id, shumian_portrait_path),
				_l("只是我只懂基礎樂理，談不上以琴入武。", shumian_speaker_id, shumian_portrait_path),
				_l("紅徽音來了以後，我便更少碰琴。", shumian_speaker_id, shumian_portrait_path),
				_l("她的琴太深，我若在旁胡亂撥弦，反倒像是在溪水裡添亂。", shumian_speaker_id, shumian_portrait_path),
			]
		"memory_writing_desk":
			return [
				_n("書案上還留著幾張泛黃的習字紙，筆畫有的歪斜，有的認真得近乎僵硬。"),
				_l("這張桌子，原本不是我的。", shumian_speaker_id, shumian_portrait_path),
				_l("是孩子們練字用的。", shumian_speaker_id, shumian_portrait_path),
				_l("有些字寫得歪，可藥師說，只要心正，字慢慢會直。", shumian_speaker_id, shumian_portrait_path),
				_l("所以你後來才把寫字變成武功？", liuyu_speaker_id, liuyu_portrait_path),
				_l("也許是從這裡開始的。", shumian_speaker_id, shumian_portrait_path),
				_l("那時我還不懂，只覺得一筆落穩，手便不抖。", shumian_speaker_id, shumian_portrait_path),
				_l("後來才明白，手能穩，心便不容易被人帶亂。", shumian_speaker_id, shumian_portrait_path),
			]
		"memory_medicine_cabinet":
			return [
				_n("藥櫃中各格分明，蒲草、紫蘇、薄荷與止血藥材都被重新收整。"),
				_l("以前孩子們也在這裡認藥。", shumian_speaker_id, shumian_portrait_path),
				_l("有人總把紫蘇和薄荷認反，藥師也不惱，只叫他聞第三遍。", shumian_speaker_id, shumian_portrait_path),
				_l("病人來時，藥師便讓孩子們退到一旁，安靜看著。", shumian_speaker_id, shumian_portrait_path),
				_l("他說，醫人不是只看藥方。", shumian_speaker_id, shumian_portrait_path),
				_l("還要看那個人把疼痛藏在哪裡。", shumian_speaker_id, shumian_portrait_path),
				_l("難怪你的詩總像在看人。", liuyu_speaker_id, liuyu_portrait_path),
				_l("也許是藥師教壞了我。", shumian_speaker_id, shumian_portrait_path),
				_n("書眠說得很輕，唇邊卻有一點久違的笑意。"),
			]
		_:
			return [_n("這裡似乎承著某段舊日記憶。")]


func _handle_loot(loot_id: String) -> void:
	var flag_name := "shumian_qd_loot_%s_taken" % loot_id
	if _get_flag(flag_name, false):
		await _show_dialog([
			_n("這裡已經沒有可取之物。")
		])
		return

	var data: Dictionary = LOOT_TABLE[loot_id]
	var item_id := str(data.get("item_id", ""))
	var amount := int(data.get("amount", 1))
	var display_name := str(data.get("display_name", item_id))
	var lines: Array = []

	for line in data.get("lines", []):
		lines.append(_n_or_speaker(str(line)))

	_add_item(item_id, amount)
	_set_flag(flag_name, true)

	lines.append(_n("獲得 %s ×%d。" % [display_name, amount]))
	await _show_dialog(lines)


func _n_or_speaker(text: String) -> Dictionary:
	if text.begins_with("書眠："):
		return _l(text.trim_prefix("書眠："), shumian_speaker_id, shumian_portrait_path)
	if text.begins_with("劉語塵："):
		return _l(text.trim_prefix("劉語塵："), liuyu_speaker_id, liuyu_portrait_path)
	return _n(text)


func _connect_transition_areas() -> void:
	if to_yuheng_old_well and not to_yuheng_old_well.body_entered.is_connected(_on_to_yuheng_old_well_body_entered):
		to_yuheng_old_well.body_entered.connect(_on_to_yuheng_old_well_body_entered)

	if to_yuheng_stalactite_cave and not to_yuheng_stalactite_cave.body_entered.is_connected(_on_to_yuheng_stalactite_cave_body_entered):
		to_yuheng_stalactite_cave.body_entered.connect(_on_to_yuheng_stalactite_cave_body_entered)

	if to_yuheng_sewer_true_room and not to_yuheng_sewer_true_room.body_entered.is_connected(_on_to_yuheng_sewer_true_room_body_entered):
		to_yuheng_sewer_true_room.body_entered.connect(_on_to_yuheng_sewer_true_room_body_entered)


func _connect_interaction_areas() -> void:
	var containers := [
		get_node_or_null("InvestigationAreas"),
		get_node_or_null("LootAreas"),
	]

	for container in containers:
		if container == null:
			continue

		for child in container.get_children():
			if child is Area2D:
				_connect_interaction_area(child as Area2D, child.name)


func _connect_interaction_area(area: Area2D, interaction_id: String) -> void:
	if not area.body_entered.is_connected(_on_interaction_area_body_entered):
		area.body_entered.connect(_on_interaction_area_body_entered.bind(interaction_id))

	if not area.body_exited.is_connected(_on_interaction_area_body_exited):
		area.body_exited.connect(_on_interaction_area_body_exited.bind(interaction_id))


func _on_interaction_area_body_entered(body: Node, interaction_id: String) -> void:
	if _is_player(body):
		current_interaction_id = interaction_id


func _on_interaction_area_body_exited(body: Node, interaction_id: String) -> void:
	if _is_player(body) and current_interaction_id == interaction_id:
		current_interaction_id = ""


func _on_to_yuheng_old_well_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	await _change_map(yuheng_old_well, old_well_spawn_point)


func _on_to_yuheng_stalactite_cave_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	await _change_map(yuheng_stalactite_cave, stalactite_cave_spawn_point)


func _on_to_yuheng_sewer_true_room_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	await _change_map(yuheng_sewer_true_room, true_room_spawn_point)


func _change_map(scene_path: String, spawn_point_name: String) -> void:
	if transition_locked:
		return

	transition_locked = true
	_set_player_movable(false)

	await _fade_out()

	var game_root := get_node_or_null("/root/GameRoot")
	if game_root:
		game_root.spawn_point_name = spawn_point_name
		if game_root.has_method("change_map_to"):
			game_root.change_map_to(scene_path)
			return

	get_tree().change_scene_to_file(scene_path)


func _fade_out() -> void:
	if overlay == null:
		return

	overlay.visible = true
	overlay.modulate.a = 0.0

	var tween := overlay.create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
	await tween.finished


func _add_item(item_id: String, amount: int) -> void:
	var inventory := _get_first_node([
		"/root/InventoryManager",
		"/root/GameRoot/InventoryManager",
		"/root/InventorySync",
		"/root/GameRoot/InventorySync",
	])

	if inventory:
		if inventory.has_method("add_item"):
			inventory.add_item(item_id, amount)
			return
		if inventory.has_method("add"):
			inventory.add(item_id, amount)
			return

	_set_flag("received_item_%s" % item_id, true)


func _is_interact_pressed() -> bool:
	var pressed_by_action := false
	if InputMap.has_action(interact_action):
		pressed_by_action = Input.is_action_just_pressed(interact_action)

	var space_down := Input.is_key_pressed(KEY_SPACE)
	var pressed_by_space := space_down and not _space_was_down
	_space_was_down = space_down

	return pressed_by_action or pressed_by_space


func _is_player(body: Node) -> bool:
	return body.name == "LiuYu" or body.name == "Player" or body.is_in_group("player")


func _set_player_movable(value: bool) -> void:
	var player := get_node_or_null("/root/GameRoot/LiuYu")
	if player == null:
		player = get_node_or_null("/root/Player")

	if player:
		player.set("can_move", value)


func _get_first_node(paths: Array[String]) -> Node:
	for node_path in paths:
		var node := get_node_or_null(node_path)
		if node:
			return node
	return null


func _show_dialog(lines: Array) -> void:
	var dialog_manager := _get_dialog_manager()

	if dialog_manager == null:
		for line in lines:
			print(line)
		return

	if dialog_manager.has_method("show_dialog_sequence"):
		_waiting_for_dialog = true
		dialog_manager.show_dialog_sequence(lines, self)
		await _wait_dialog_finished(dialog_manager)
		return

	if dialog_manager.has_method("start_dialog"):
		dialog_manager.start_dialog(_lines_to_text_array(lines))
		await _wait_dialog_finished(dialog_manager)
		return

	for line in lines:
		print(line)


func _get_dialog_manager() -> Node:
	var dialog_manager := get_node_or_null("/root/GameRoot/DialogManager")
	if dialog_manager:
		return dialog_manager

	dialog_manager = get_node_or_null("/root/DialogManager")
	if dialog_manager:
		return dialog_manager

	return null


func _wait_dialog_finished(dialog_manager: Node) -> void:
	if dialog_manager.has_signal("dialog_sequence_finished"):
		await dialog_manager.dialog_sequence_finished
	elif _waiting_for_dialog:
		await dialog_closed

	_waiting_for_dialog = false


func reset_dialog_state() -> void:
	if _waiting_for_dialog:
		_waiting_for_dialog = false
		dialog_closed.emit()


func _lines_to_text_array(lines: Array) -> Array[String]:
	var result: Array[String] = []
	for line in lines:
		if line is Dictionary and line.has("text"):
			result.append(str(line["text"]))
		else:
			result.append(str(line))
	return result


func _l(text: String, speaker: int, portrait: String = "") -> Dictionary:
	return {
		"text": text,
		"speaker": speaker,
		"portrait": portrait if portrait != "" else empty_portrait_path,
	}


func _n(text: String) -> Dictionary:
	return {
		"text": text,
		"speaker": narration_speaker_id,
		"portrait": empty_portrait_path,
	}


func _get_flag(flag_name: String, default_value = null):
	var global_state := _get_global_state()
	if global_state == null:
		return default_value

	if global_state.has_method("get_flag"):
		var value = global_state.get_flag(flag_name)
		if value == null:
			return default_value
		return value

	var value = global_state.get(flag_name)
	if value == null:
		return default_value

	return value


func _set_flag(flag_name: String, value) -> void:
	var global_state := _get_global_state()
	if global_state == null:
		push_warning("找不到 GlobalState，無法寫入：" + flag_name)
		return

	if global_state.has_method("set_flag"):
		global_state.set_flag(flag_name, value)
	else:
		global_state.set(flag_name, value)


func _get_global_state() -> Node:
	var global_state := get_node_or_null("/root/GlobalState")
	if global_state:
		return global_state

	global_state = get_node_or_null("/root/GameRoot/GlobalState")
	if global_state:
		return global_state

	return null
