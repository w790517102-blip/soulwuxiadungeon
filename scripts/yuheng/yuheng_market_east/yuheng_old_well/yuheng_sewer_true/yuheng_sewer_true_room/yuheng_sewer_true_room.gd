extends Node2D
class_name YuhengSewerTrueRoom

# ------------------------------------------------------------
# 玉衡鎮｜藥師舊室：《渠燈補封》核心場景
# 掛載：yuheng_sewer_true_room.tscn 根節點
#
# 本場景功能：
# 1. 調查琴、寫字檯、藥櫃，補足「傳承藥師」的場景因果。
# 2. 調查牆符、獅頭水口、渠燈，完成三處補封。
# 3. 三處皆完成後，解鎖書眠技能：澄心落筆、清渠共印。
# 4. 回到 yuheng_sewer_true。
# ------------------------------------------------------------

@export var music_tag := "yuheng"
@export var map_display_name: String = "玉衡鎮舊水道・藥師舊室"

@export_file("*.tscn") var yuheng_sewer_true: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_true/yuheng_sewer_true.tscn"
@export var return_spawn_point := "from_yuheng_sewer_true_room"

@export var interact_action := "interact"

@export var empty_portrait_path := "res://assets/sprites/empty.png"
@export var liuyu_portrait_path := "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"
@export var shumian_portrait_path := "res://assets/sprites/Shu_mian/ShuMian_headshot.png"

@export var narration_speaker_id := 0
@export var liuyu_speaker_id := 2
@export var shumian_speaker_id := 4

@onready var overlay: ColorRect = get_node_or_null("BlackOverlay")
@onready var to_yuheng_sewer_true: Area2D = get_node_or_null("to_yuheng_sewer_true")

signal dialog_closed

const F_QD_TALISMAN_FIXED := "shumian_qd_talisman_fixed"
const F_QD_WATERHEAD_CHECKED := "shumian_qd_waterhead_checked"
const F_QD_LAMPS_REFILLED := "shumian_qd_lamps_refilled"
const F_QD_DONE := "shumian_clean_sewer_done"

const F_SKILL_CHENGXIN := "shumian_skill_chengxin_luobi_unlocked"
const F_SKILL_QINGQU := "shumian_skill_qingqu_gongyin_unlocked"

const MEMORY_IDS := [
	"memory_room_qin",
	"memory_room_writing_desk",
	"memory_room_medicine_cabinet",
]

const LOOT_TABLE := {
	"loot_old_herb_pouch": {
		"item_id": "mat_herb_pouch",
		"amount": 1,
		"display_name": "草藥包",
		"lines": [
			"藥櫃下層收著一只小布包，裡頭是分門別類的常見草藥。",
			"書眠：看來藥師當年收得很仔細，連語魅都沒能把它們泡壞。"
		]
	},
	"loot_calm_pill": {
		"item_id": "med_calm_pill",
		"amount": 1,
		"display_name": "清心丸",
		"lines": [
			"琴案旁的小匣中，有一枚以蠟紙包好的藥丸。",
			"書眠：這是清心丸。以前有人心緒太亂，藥師才會取出來。"
		]
	},
}

const FIX_IDS := [
	"fix_wall_talisman",
	"fix_lion_waterhead",
	"fix_channel_lamps",
]

var current_interaction_id := ""
var interaction_locked := false
var transition_locked := false
var _waiting_for_dialog := false
var _space_was_down := false


func _ready() -> void:
	_connect_transition_area()
	_connect_interaction_areas()

	await _play_entry_fade()
	await show_map_name()


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


func _handle_interaction(interaction_id: String) -> void:
	interaction_locked = true
	_set_player_movable(false)

	if MEMORY_IDS.has(interaction_id):
		await _show_dialog(_build_memory_lines(interaction_id))
	elif LOOT_TABLE.has(interaction_id):
		await _handle_loot(interaction_id)
	elif FIX_IDS.has(interaction_id):
		await _handle_fix(interaction_id)
	else:
		await _show_dialog([
			_n("這裡似乎沒有特別可調查的東西。")
		])

	_set_player_movable(true)
	interaction_locked = false


func _build_memory_lines(memory_id: String) -> Array:
	match memory_id:
		"memory_room_qin":
			return [
				_n("房中舊琴置於案上，琴身保存良好，弦色卻顯得沉靜。"),
				_l("這張琴也是藥師留下的？", liuyu_speaker_id, liuyu_portrait_path),
				_l("嗯。", shumian_speaker_id, shumian_portrait_path),
				_l("藥師離開後，這裡的典籍、藥櫃、琴，便一併交給我看管。", shumian_speaker_id, shumian_portrait_path),
				_l("我偶爾興致來了會撥幾聲。", shumian_speaker_id, shumian_portrait_path),
				_l("可自從紅徽音來到玉衡鎮，我便很少再碰它。", shumian_speaker_id, shumian_portrait_path),
				_l("她的琴能入心，我的琴只是識音。", shumian_speaker_id, shumian_portrait_path),
				_l("後來語魅污染此處，我便幾乎沒有動過了。", shumian_speaker_id, shumian_portrait_path),
			]
		"memory_room_writing_desk":
			return [
				_n("寫字檯上收著舊墨、筆架與幾卷藥理札記。"),
				_l("這裡不像孩子們練字的地方。", liuyu_speaker_id, liuyu_portrait_path),
				_l("這裡是藥師研讀與記錄的房間。", shumian_speaker_id, shumian_portrait_path),
				_l("我和藥師共同的回憶不多在這裡。", shumian_speaker_id, shumian_portrait_path),
				_l("更多是他留下的東西，後來交到我手上。", shumian_speaker_id, shumian_portrait_path),
				_n("書眠低頭看向自己手中的墨筆。"),
				_l("這支筆，也是他交給我的。", shumian_speaker_id, shumian_portrait_path),
				_l("原本只是寫字用的筆。", shumian_speaker_id, shumian_portrait_path),
				_l("後來我才明白，一筆落得穩，手也能穩；手能穩，心便不容易亂。", shumian_speaker_id, shumian_portrait_path),
				_l("於是它也成了我的武器。", shumian_speaker_id, shumian_portrait_path),
			]
		"memory_room_medicine_cabinet":
			return [
				_n("藥櫃抽屜密密排開，標籤清楚，藥香柔和而乾淨。"),
				_l("昨夜那些藥材明明已經被霉氣悶壞了。", liuyu_speaker_id, liuyu_portrait_path),
				_l("語魅退去後，它們便回到原本保存良好的樣子。", shumian_speaker_id, shumian_portrait_path),
				_l("這裡本就不是髒污之地。", shumian_speaker_id, shumian_portrait_path),
				_l("只是太多被壓住的話與心念，讓它看起來像病了一樣。", shumian_speaker_id, shumian_portrait_path),
				_l("現在病根暫退，藥氣也終於能透出來。", shumian_speaker_id, shumian_portrait_path),
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


func _handle_fix(fix_id: String) -> void:
	match fix_id:
		"fix_wall_talisman":
			if _get_flag(F_QD_TALISMAN_FIXED, false):
				await _show_dialog([_n("牆上的舊符已重新補穩。")])
				return

			_set_flag(F_QD_TALISMAN_FIXED, true)
			await _show_dialog([
				_n("牆上的舊符已不再滲出黑氣，但符尾仍有水漬暈開。"),
				_l("這裡先前撐得最苦。", shumian_speaker_id, shumian_portrait_path),
				_l("要重貼？", liuyu_speaker_id, liuyu_portrait_path),
				_l("不必重貼。", shumian_speaker_id, shumian_portrait_path),
				_l("它還認得原本的筆勢。", shumian_speaker_id, shumian_portrait_path),
				_n("書眠以墨筆補上符尾斷線，筆鋒落下時，符紙微微一亮。"),
			])
		"fix_lion_waterhead":
			if _get_flag(F_QD_WATERHEAD_CHECKED, false):
				await _show_dialog([_n("獅頭水口的水聲已比方才順暢許多。")])
				return

			_set_flag(F_QD_WATERHEAD_CHECKED, true)
			await _show_dialog([
				_n("獅頭水口重新吐出清水，水聲比昨夜輕了許多。"),
				_l("這裡也是封印？", liuyu_speaker_id, liuyu_portrait_path),
				_l("是水脈的口。", shumian_speaker_id, shumian_portrait_path),
				_l("水若堵住，濁氣便會在底下打轉。", shumian_speaker_id, shumian_portrait_path),
				_n("書眠俯身檢查水痕，又以筆尖點過石縫，將殘留濁氣引入渠中。"),
			])
		"fix_channel_lamps":
			if _get_flag(F_QD_LAMPS_REFILLED, false):
				await _show_dialog([_n("渠道旁兩盞舊燈已添過燈油，火光安穩。")])
				return

			_set_flag(F_QD_LAMPS_REFILLED, true)
			await _show_dialog([
				_n("渠道旁兩盞舊燈油芯已乾，燈座上仍留著藥草與松脂混成的香氣。"),
				_l("藥師說，水路要有燈。", shumian_speaker_id, shumian_portrait_path),
				_l("給人看路？", liuyu_speaker_id, liuyu_portrait_path),
				_l("也給水看路。", shumian_speaker_id, shumian_portrait_path),
				_n("書眠重新添入燈油，火光映入渠水，水面像被輕輕扶正。"),
			])

	await _check_qudeng_completion()


func _check_qudeng_completion() -> void:
	if _get_flag(F_QD_DONE, false):
		return

	if not (_get_flag(F_QD_TALISMAN_FIXED, false) \
		and _get_flag(F_QD_WATERHEAD_CHECKED, false) \
		and _get_flag(F_QD_LAMPS_REFILLED, false)):
		return

	_set_flag(F_QD_DONE, true)
	_set_flag(F_SKILL_CHENGXIN, true)
	_set_flag(F_SKILL_QINGQU, true)

	_unlock_shumian_skill("chengxin_luobi")
	_unlock_shumian_skill("qingqu_gongyin")

	await _show_dialog([
		_n("牆符、渠燈、水口皆已重新穩住。"),
		_n("清水沿著石渠流過，聲音比方才更輕，也更遠。"),
		_l("氣息變了。", liuyu_speaker_id, liuyu_portrait_path),
		_l("嗯。", shumian_speaker_id, shumian_portrait_path),
		_l("不是被壓下去。", shumian_speaker_id, shumian_portrait_path),
		_l("是有路可以走了。", shumian_speaker_id, shumian_portrait_path),
		_n("她望著水面許久，忽然提筆，在掌心輕輕落下一點。"),
		_l("原來……不是每一筆都要壓住。", shumian_speaker_id, shumian_portrait_path),
		_l("有些筆，是要替心開路。", shumian_speaker_id, shumian_portrait_path),
		_n("書眠悟得「澄心落筆」。"),
		_n("書眠悟得「清渠共印」。"),
		_l("這樣，足夠等我們回來？", liuyu_speaker_id, liuyu_portrait_path),
		_l("足夠讓我相信，我不是逃走。", shumian_speaker_id, shumian_portrait_path),
		_l("我是去把風帶回來。", shumian_speaker_id, shumian_portrait_path),
	])


func _unlock_shumian_skill(skill_id: String) -> void:
	var skill_manager := _get_first_node([
		"/root/SkillManager",
		"/root/GameRoot/SkillManager",
		"/root/PartyManager",
		"/root/GameRoot/PartyManager",
	])

	if skill_manager:
		if skill_manager.has_method("unlock_skill"):
			skill_manager.unlock_skill("shumian", skill_id)
			return
		if skill_manager.has_method("learn_skill"):
			skill_manager.learn_skill("shumian", skill_id)
			return

	_set_flag("skill_unlocked_shumian_%s" % skill_id, true)


func _n_or_speaker(text: String) -> Dictionary:
	if text.begins_with("書眠："):
		return _l(text.trim_prefix("書眠："), shumian_speaker_id, shumian_portrait_path)
	if text.begins_with("劉語塵："):
		return _l(text.trim_prefix("劉語塵："), liuyu_speaker_id, liuyu_portrait_path)
	return _n(text)


func _connect_transition_area() -> void:
	if to_yuheng_sewer_true and not to_yuheng_sewer_true.body_entered.is_connected(_on_to_yuheng_sewer_true_body_entered):
		to_yuheng_sewer_true.body_entered.connect(_on_to_yuheng_sewer_true_body_entered)


func _connect_interaction_areas() -> void:
	var containers := [
		get_node_or_null("InvestigationAreas"),
		get_node_or_null("LootAreas"),
		get_node_or_null("FixPoints"),
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


func _on_to_yuheng_sewer_true_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	await _change_map(yuheng_sewer_true, return_spawn_point)


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
