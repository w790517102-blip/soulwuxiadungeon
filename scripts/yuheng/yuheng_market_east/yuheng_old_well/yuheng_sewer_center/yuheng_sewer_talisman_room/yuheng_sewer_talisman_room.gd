extends Node2D
class_name YuhengSewerTalismanRoom

signal dialog_closed
signal reseal_choice_resolved

# ------------------------------------------------------------
# 地圖 / 轉場設定
# ------------------------------------------------------------
@export var yuheng_sewer_center: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_center.tscn"
@export var music_tag := "yuheng_sewer"
@export var map_display_name: String = "玉衡鎮下水道符咒間"

# 回到中央區時，要讓 GameRoot 把劉語塵放到這個 spawn point。
@export var return_spawn_point_name := "from_yuheng_sewer_talisman_room"

@onready var overlay: ColorRect = get_node_or_null("BlackOverlay")
@onready var to_yuheng_sewer_center: Area2D = get_node_or_null("To_yuheng_sewer_center")

# ------------------------------------------------------------
# 符咒機關設定
# ------------------------------------------------------------
const FLAG_SOLVED := "sewer_talisman_solved"
const FLAG_HINT_READ := "sewer_talisman_hint_read"
const FLAG_FINAL_ROOM_INTRO_DONE := "event_yuheng_sewer_final_room_intro_done"
const FLAG_HEART_FOUND := "sewer_talisman_heart_found"
const FLAG_MOUTH_FOUND := "sewer_talisman_mouth_found"
const FLAG_WATER_FOUND := "sewer_talisman_water_found"
const FLAG_HEART_RESEALED := "sewer_talisman_heart_resealed"
const FLAG_MOUTH_RESEALED := "sewer_talisman_mouth_resealed"
const FLAG_WATER_RESEALED := "sewer_talisman_water_resealed"
const SEWER_ZONE_ID := "yuheng_sewer"
const SEWER_TALISMAN_ENCOUNTER_CONFIG := {
	"encounter_region_id": "yuheng_sewer",
	"encounter_profile_id": "yuheng_sewer_pressure_v1",
	"distance_threshold": 240.0,
	"chance": 0.30,
	"cooldown_distance": 280.0,
	"intro_key": "yuheng_sewer_talisman_random"
}
const SEWER_TALISMAN_ENCOUNTER_TABLE := [
	{"w": 14, "enemies": ["yumei_sewer_rat", "yumei_sewer_rat"]},
	{"w": 10, "enemies": ["yumei_sewer_bat", "yumei_sewer_bat"]},
	{"w": 10, "enemies": ["yumei_sewer_rat", "yumei_sewer_rat", "yumei_sewer_rat"]},
	{"w": 10, "enemies": ["yumei_sewer_rat", "yumei_sewer_bat"]},
	{"w": 8, "enemies": ["yumei_sewer_rat", "yumei_sewer_rat", "yumei_sewer_bat"]},
	{"w": 6, "enemies": ["yumei_sewer_rat", "yumei_sewer_bat", "yumei_sewer_bat"]},
	{"w": 8, "enemies": ["turbid_tone_phantom", "yumei_sewer_rat"]},
	{"w": 5, "enemies": ["turbid_tone_phantom", "yumei_sewer_bat"]},
	{"w": 9, "enemies": ["broken_talisman_tone_phantom", "yumei_sewer_rat"]},
	{"w": 7, "enemies": ["broken_talisman_tone_phantom", "yumei_sewer_bat"]},
	{"w": 3, "enemies": ["broken_talisman_tone_phantom", "yumei_sewer_rat", "yumei_sewer_rat"]},
	{"w": 5, "enemies": ["fixation_tone_phantom"]},
	{"w": 3, "enemies": ["fixation_tone_phantom", "yumei_sewer_rat"]},
	{"w": 2, "enemies": ["fixation_tone_phantom", "yumei_sewer_bat"]}
]

# 正解來自石刻：
# 心亂則語生，語腐則水濁，水濁則夢驚。
# 所以補封順序為：心 → 語 → 水
const CORRECT_SEQUENCE: Array[String] = [
	"heart",
	"mouth",
	"water"
]

const TALISMAN_NAMES := {
	"heart": "心符",
	"mouth": "語符",
	"water": "水符"
}

const TALISMAN_SYMBOL_NAMES := {
	"heart": "心",
	"mouth": "語",
	"water": "水"
}

const TALISMAN_SHAPE_DESCRIPTIONS := {
	"heart": "一顆心臟",
	"mouth": "一張嘴",
	"water": "一滴水"
}

const TALISMAN_FOUND_FLAGS := {
	"heart": FLAG_HEART_FOUND,
	"mouth": FLAG_MOUTH_FOUND,
	"water": FLAG_WATER_FOUND
}

const TALISMAN_RESEALED_FLAGS := {
	"heart": FLAG_HEART_RESEALED,
	"mouth": FLAG_MOUTH_RESEALED,
	"water": FLAG_WATER_RESEALED
}

const TALISMAN_AREA_PATHS := {
	"heart": "heart_talisman/Area2D",
	"mouth": "mouth_talisman/Area2D",
	"water": "water_talisman/Area2D"
}

@export var interact_action := "interact"
@export var empty_portrait_path := "res://assets/sprites/empty.png"
@export var narration_speaker_id := 0

var current_target_id := ""
var current_sequence: Array[String] = []
var interaction_locked := false
var transition_locked := false
var player_ref: Node = null
var _waiting_for_dialog := false
var _space_was_down := false
var _reseal_choice_active := false
var _reseal_choice_confirmed := false


func _ready() -> void:
	_restore_talisman_progress()
	_setup_talisman_repair_visuals()
	_connect_talisman_areas()
	_connect_return_area()
	_set_entry_idle_direction()

	await _play_entry_fade()
	await show_map_name()


func get_map_display_name() -> String:
	return map_display_name

func get_encounter_zone_config(zone_id: String) -> Dictionary:
	if zone_id == SEWER_ZONE_ID:
		return SEWER_TALISMAN_ENCOUNTER_CONFIG.duplicate(true)
	return {}

func get_encounter_table(zone_id: String) -> Array:
	if zone_id == SEWER_ZONE_ID:
		return SEWER_TALISMAN_ENCOUNTER_TABLE.duplicate(true)
	return []


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


func _process(_delta: float) -> void:
	if current_target_id == "":
		return

	if interaction_locked:
		return

	if _is_interact_pressed():
		await _interact_talisman(current_target_id)


func _unhandled_input(event: InputEvent) -> void:
	if not _reseal_choice_active:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_resolve_reseal_choice(false)


# ------------------------------------------------------------
# 符咒機關主流程
# ------------------------------------------------------------
func _interact_talisman(talisman_id: String) -> void:
	if not TALISMAN_SYMBOL_NAMES.has(talisman_id):
		push_warning("未知的符咒圖樣：" + talisman_id)
		_finish_talisman_interaction()
		return

	interaction_locked = true
	_set_player_movable(false)

	if bool(_get_flag(FLAG_SOLVED, false)):
		await _show_dialog(_build_after_solved_lines())
		_finish_talisman_interaction()
		return

	if not _is_final_room_intro_done():
		await _show_dialog(_build_pre_intro_observation_lines())
		_finish_talisman_interaction()
		return

	if not bool(_get_flag(FLAG_HINT_READ, false)):
		var first_lines: Array[String] = _build_post_intro_recognition_lines()
		first_lines.append_array(_build_first_investigation_lines(talisman_id))
		await _show_dialog(first_lines)
		_set_flag(FLAG_HINT_READ, true)
		_mark_symbol_found(talisman_id)
		_refresh_sewer_puzzle_note()
		_finish_talisman_interaction()
		return

	if not _all_symbols_found():
		await _investigate_symbol(talisman_id)
		_finish_talisman_interaction()
		return

	if current_sequence.has(talisman_id):
		await _show_dialog(_build_already_resealed_lines())
		_finish_talisman_interaction()
		return

	var confirmed := await _ask_reseal_confirmation(talisman_id)
	if not confirmed:
		await _show_dialog(["（你暫且收回了手，沒有碰動牆上的符紙。）"])
		_finish_talisman_interaction()
		return

	current_sequence.append(talisman_id)

	if not _is_current_sequence_valid():
		_reset_talisman_progress()
		await _show_dialog(_build_wrong_sequence_lines(talisman_id))
		_finish_talisman_interaction()
		return

	_set_talisman_resealed(talisman_id, true)
	_apply_talisman_repair_visual(talisman_id)

	if current_sequence.size() >= CORRECT_SEQUENCE.size():
		await _solve_talisman_puzzle()
		_finish_talisman_interaction()
		return

	await _show_dialog(_build_correct_step_lines(talisman_id))
	_finish_talisman_interaction()


func _finish_talisman_interaction() -> void:
	if _reseal_choice_active:
		_resolve_reseal_choice(false)
	_set_player_movable(true)
	interaction_locked = false


func _investigate_symbol(talisman_id: String) -> void:
	var symbol_name := str(TALISMAN_SYMBOL_NAMES[talisman_id])
	if _is_symbol_found(talisman_id):
		await _show_dialog([
			"（這是先前看過的「%s」圖樣。）" % symbol_name,
			"還有其他圖樣尚未確認。先把它們找齊再說。"
		])
		return

	await _show_dialog(_build_symbol_discovery_lines(talisman_id))
	_mark_symbol_found(talisman_id)
	if _all_symbols_found():
		await _show_dialog([
			"心、語、水……三處都找到了。",
			"接下來，便依照石壁留下的順序補封。"
		])
	else:
		await _show_dialog(["還有其他圖樣尚未確認。先把它們找齊再說。"])


func _mark_symbol_found(talisman_id: String) -> void:
	var flag_name := str(TALISMAN_FOUND_FLAGS.get(talisman_id, ""))
	if flag_name != "":
		_set_flag(flag_name, true)


func _is_symbol_found(talisman_id: String) -> bool:
	var flag_name := str(TALISMAN_FOUND_FLAGS.get(talisman_id, ""))
	return flag_name != "" and bool(_get_flag(flag_name, false))


func _all_symbols_found() -> bool:
	for talisman_id in CORRECT_SEQUENCE:
		if not _is_symbol_found(talisman_id):
			return false
	return true


func _ask_reseal_confirmation(talisman_id: String) -> bool:
	await _show_dialog(_build_reseal_confirmation_lines(talisman_id))

	var dialog_manager := _get_dialog_manager()
	if dialog_manager == null or not dialog_manager.has_method("show_choice"):
		push_warning("找不到可用的 DialogManager ChoiceBox，視為未補符。")
		return false
	var choice_box := dialog_manager.get_node_or_null("ChoiceBox")
	if choice_box == null or not choice_box.has_method("hide_choices"):
		push_warning("找不到 DialogManager/ChoiceBox，視為未補符。")
		return false

	_reseal_choice_active = true
	_reseal_choice_confirmed = false
	dialog_manager.call("show_choice", [
		{"text": "是", "callback": Callable(self, "_resolve_reseal_choice").bind(true)},
		{"text": "否", "callback": Callable(self, "_resolve_reseal_choice").bind(false)}
	])
	await reseal_choice_resolved
	return _reseal_choice_confirmed


func _resolve_reseal_choice(confirmed: bool) -> void:
	if not _reseal_choice_active:
		return
	_reseal_choice_active = false
	_reseal_choice_confirmed = confirmed
	var dialog_manager := _get_dialog_manager()
	if dialog_manager:
		var choice_box := dialog_manager.get_node_or_null("ChoiceBox")
		if choice_box and choice_box.has_method("hide_choices"):
			choice_box.call("hide_choices")
	reseal_choice_resolved.emit()


func _is_current_sequence_valid() -> bool:
	if current_sequence.size() > CORRECT_SEQUENCE.size():
		return false

	for i in range(current_sequence.size()):
		if current_sequence[i] != CORRECT_SEQUENCE[i]:
			return false

	return true


func _restore_talisman_progress() -> void:
	current_sequence.clear()
	if bool(_get_flag(FLAG_SOLVED, false)):
		return

	# A valid partial solution is always a prefix of heart -> mouth -> water.
	# Stop at the first missing step so a damaged/legacy flag set cannot skip ahead.
	for talisman_id in CORRECT_SEQUENCE:
		if not _is_talisman_resealed(talisman_id):
			break
		current_sequence.append(talisman_id)


func _set_talisman_resealed(talisman_id: String, value: bool) -> void:
	var flag_name := str(TALISMAN_RESEALED_FLAGS.get(talisman_id, ""))
	if flag_name != "":
		_set_flag(flag_name, value)


func _is_talisman_resealed(talisman_id: String) -> bool:
	var flag_name := str(TALISMAN_RESEALED_FLAGS.get(talisman_id, ""))
	return flag_name != "" and bool(_get_flag(flag_name, false))


func _reset_talisman_progress() -> void:
	current_sequence.clear()
	for talisman_id in CORRECT_SEQUENCE:
		_set_talisman_resealed(talisman_id, false)
		_apply_talisman_repair_visual(talisman_id)


func _setup_talisman_repair_visuals() -> void:
	var source := get_node_or_null("talisman/talisman") as Sprite2D
	if source == null:
		push_warning("[符咒室] 找不到補符視覺節點 talisman/talisman。")
		return
	if bool(source.get_meta("repair_visuals_ready", false)):
		return
	if source.texture == null:
		push_warning("[符咒室] 補符視覺沒有可用貼圖。")
		return

	var repair_texture := source.texture
	var texture_size := repair_texture.get_size()
	var slice_width := texture_size.x / float(CORRECT_SEQUENCE.size())
	source.texture = null
	source.set_meta("repair_visuals_ready", true)

	for index in range(CORRECT_SEQUENCE.size()):
		var talisman_id := CORRECT_SEQUENCE[index]
		var region := Rect2(
			Vector2(slice_width * index, 0.0),
			Vector2(slice_width, texture_size.y)
		)
		var repair_slice := Sprite2D.new()
		repair_slice.name = "repair_%s" % talisman_id
		repair_slice.texture = repair_texture
		repair_slice.region_enabled = true
		repair_slice.region_filter_clip_enabled = true
		repair_slice.region_rect = region
		repair_slice.position = region.get_center() - texture_size * 0.5
		source.add_child(repair_slice)
		_apply_talisman_repair_visual(talisman_id)


func _apply_talisman_repair_visual(talisman_id: String) -> void:
	var repair_slice := get_node_or_null("talisman/talisman/repair_%s" % talisman_id) as Sprite2D
	if repair_slice == null:
		return
	repair_slice.visible = bool(_get_flag(FLAG_SOLVED, false)) or current_sequence.has(talisman_id)


func _solve_talisman_puzzle() -> void:
	_set_flag(FLAG_SOLVED, true)
	current_sequence.clear()

	await _show_dialog([
		"三道符光一齊定住。",
		"心符沉下，語符歸線，水符收濁。",
		"原本從牆縫滲出的紫黑霧氣，被一寸寸壓回裂口深處。",
		"石壁裡傳來細細的聲響，像有人替一處快裂開的傷口重新繫上線。",
		"劉語塵低聲道：「封住了。」",
		"他停了一下，望著那些被水氣泡皺的符紙。",
		"「但不像治好。」",
		"「只是替快裂的牆，再壓上一隻手。」",
		"「書眠……這些年到底一個人補過多少次？」",
		"遠方傳來機關開啟的聲音。"
	])
	_refresh_sewer_puzzle_note()


func _refresh_sewer_puzzle_note() -> void:
	var quest_manager := get_node_or_null("/root/QuestManager")
	if quest_manager and quest_manager.has_method("refresh_sewer_puzzle_note"):
		quest_manager.call("refresh_sewer_puzzle_note")


func _build_first_investigation_lines(talisman_id: String) -> Array[String]:
	var shape_description := str(TALISMAN_SHAPE_DESCRIPTIONS.get(talisman_id, "不明"))
	var symbol_name := str(TALISMAN_SYMBOL_NAMES.get(talisman_id, "不明"))
	return [
		"（你望向眼前刻在石壁上的%s圖樣。圖樣四周貼滿了用來封住石縫的舊符，其中幾張符紙的邊角已受潮翹起。）" % shape_description,
		"符紙原本應是祈平安、護身息的家常符，可如今筆畫沉重，符尾也被潮氣浸得發暗。",
		"（符紙之下，一道細小裂縫正滲出紫黑霧氣，像有什麼惡夢被壓在牆後，至今仍不肯安分。）",
		"（與此同時，你注意到一旁的石壁上刻著一行小字。）",
		"「心亂則語生，語腐則水濁，水濁則夢驚。」",
		"（你看了許久。）",
		"「心、語、水……這應當正對著石壁上的三種圖樣。」",
		"「看來那句話不只是一句咒語。」",
		"「倒像是在說，污染是如何一步一步滋長的。」",
		"「先亂其心，再腐其語；最後連飲水與睡夢這樣的日常，也不得安寧。」",
		"「換言之，這些符咒正是為了鎮住污染而設。」",
		"「只是年深日久，符紙漸朽，封住裂縫的力量也開始鬆動了。」",
		"「若不及時補封，穢氣恐怕會沿著石縫外洩，釀成更大的災禍。」",
		"「可既然留下了先後之語，補封的順序便不能錯。」",
		"「也就是說，我得先確認三種圖樣分別位在何處。」",
		"「眼前這道是『%s』。剩下兩種圖樣，想必也在附近。」" % symbol_name,
		"「……」",
		"（你在心中又將那句話默念了一遍，像是在提醒自己別遺漏任何一處。）",
		"「先找齊所有圖樣，再依『心、語、水』的順序，把鬆脫的符咒重新貼回去。」"
	]


func _build_symbol_discovery_lines(talisman_id: String) -> Array[String]:
	var shape_description := str(TALISMAN_SHAPE_DESCRIPTIONS[talisman_id])
	var symbol_name := str(TALISMAN_SYMBOL_NAMES[talisman_id])
	return [
		"（眼前的圖樣形如%s。周圍的舊符已壓不住石縫中外洩的穢氣。）" % shape_description,
		"「這裡應當就是『%s』。」" % symbol_name
	]


func _build_reseal_confirmation_lines(talisman_id: String) -> Array[String]:
	var shape_description := str(TALISMAN_SHAPE_DESCRIPTIONS[talisman_id])
	return [
		"（眼前的圖樣形如%s。周圍的符咒已壓不住石壁隙縫中外洩的穢氣。）" % shape_description,
		"「要將鬆脫的符咒重新貼上嗎？」",
		"提示：心 → 語 → 水"
	]


func _build_already_resealed_lines() -> Array[String]:
	var next_index := current_sequence.size()
	var next_name := ""
	if next_index < CORRECT_SEQUENCE.size():
		next_name = str(TALISMAN_SYMBOL_NAMES.get(CORRECT_SEQUENCE[next_index], ""))
	return [
		"（這一處鬆脫的符咒已經重新貼穩。）",
		"「這裡暫時壓住了。接下來是『%s』。」" % next_name
	]


func _build_pre_intro_observation_lines() -> Array[String]:
	return [
		"符紋彼此牽連，任意移動一處，恐怕會擾亂整座陣勢。",
		"在弄清它封著什麼以前，還是不要貿然動手。"
	]


func _build_post_intro_recognition_lines() -> Array[String]:
	return [
		"石壁上的符形徽印，應當對應這座符陣。",
		"既然它牽動出口封印，就不能只將符紙視作尋常封咒了。"
	]


func _is_final_room_intro_done() -> bool:
	return bool(_get_flag(FLAG_FINAL_ROOM_INTRO_DONE, false))


func _build_correct_step_lines(talisman_id: String) -> Array[String]:
	match talisman_id:
		"heart":
			return [
				"你按住心符。",
				"符紙下方的裂縫微微一震，原本躁動的霧氣短暫沉下。",
				"劉語塵道：「先定其心。」"
			]
		"mouth":
			return [
				"你按住語符。",
				"符上的墨線重新接起，像把一句快腐爛的話，勉強收回紙面。",
				"劉語塵道：「心定，語才不亂。」"
			]
		"water":
			return [
				"你按住水符。",
				"符尾浸入牆縫的水痕之中，濁氣被慢慢引回裂口深處。",
				"劉語塵道：「語若歸正，水才有路可清。」"
			]
		_:
			return [
				"符紙微微一震。"
			]


func _build_wrong_sequence_lines(talisman_id: String) -> Array[String]:
	var talisman_name := str(TALISMAN_NAMES.get(talisman_id, "符紙"))
	return [
		"你按住%s。" % talisman_name,
		"符光才剛亮起，便忽然一亂。",
		"三道裂縫同時滲出冷霧，水聲也變得沉濁。",
		"劉語塵皺眉：「順序錯了。」",
		"「那行字不是三個名詞，是一條流向。」",
		"符光散去，機關似乎重置了。"
	]


func _build_after_solved_lines() -> Array[String]:
	return [
		"三道符紙已經重新壓穩。",
		"牆縫中仍有寒意，卻不再繼續外滲。",
		"劉語塵道：「封印暫時穩住了。」"
	]


# ------------------------------------------------------------
# 符咒 Area2D
# ------------------------------------------------------------
func _connect_talisman_areas() -> void:
	for talisman_id in TALISMAN_AREA_PATHS.keys():
		_connect_talisman_area(talisman_id, str(TALISMAN_AREA_PATHS[talisman_id]))


func _connect_talisman_area(talisman_id: String, area_path: String) -> void:
	var area := get_node_or_null(area_path) as Area2D
	if area == null:
		push_warning("找不到符咒互動區：" + area_path)
		return

	if not area.body_entered.is_connected(_on_talisman_body_entered):
		area.body_entered.connect(_on_talisman_body_entered.bind(talisman_id))

	if not area.body_exited.is_connected(_on_talisman_body_exited):
		area.body_exited.connect(_on_talisman_body_exited.bind(talisman_id))


func _on_talisman_body_entered(body: Node, talisman_id: String) -> void:
	if _is_player(body):
		current_target_id = talisman_id
		player_ref = body


func _on_talisman_body_exited(body: Node, talisman_id: String) -> void:
	if _is_player(body) and current_target_id == talisman_id:
		current_target_id = ""
		if player_ref == body:
			player_ref = null


# ------------------------------------------------------------
# 回到舊水道中央
# ------------------------------------------------------------
func _connect_return_area() -> void:
	if to_yuheng_sewer_center == null:
		push_warning("To_yuheng_sewer_center 找不到！")
		return

	if not to_yuheng_sewer_center.body_entered.is_connected(_on_to_yuheng_sewer_center_body_entered):
		to_yuheng_sewer_center.body_entered.connect(_on_to_yuheng_sewer_center_body_entered)


func _on_to_yuheng_sewer_center_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return

	if transition_locked:
		return

	transition_locked = true
	player_ref = body
	_set_player_movable(false)

	await _fade_out_and_return_to_center()


func _fade_out_and_return_to_center() -> void:
	if overlay:
		overlay.visible = true
		overlay.modulate.a = 0.0

		var tween := overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
		await tween.finished

	var game_root := get_node_or_null("/root/GameRoot")
	if game_root:
		game_root.spawn_point_name = return_spawn_point_name

		if game_root.has_method("change_map_to"):
			game_root.change_map_to(yuheng_sewer_center)
			return

	get_tree().change_scene_to_file(yuheng_sewer_center)


# ------------------------------------------------------------
# 共用工具
# ------------------------------------------------------------
func _is_player(body: Node) -> bool:
	return body.name == "Player" or body.name == "LiuYu" or body.is_in_group("player")


func _is_interact_pressed() -> bool:
	var pressed_by_action := false
	if InputMap.has_action(interact_action):
		pressed_by_action = Input.is_action_just_pressed(interact_action)

	var space_down := Input.is_key_pressed(KEY_SPACE)
	var pressed_by_space := space_down and not _space_was_down
	_space_was_down = space_down

	return pressed_by_action or pressed_by_space


func _set_player_movable(value: bool) -> void:
	var target := player_ref
	if target == null:
		target = get_node_or_null("/root/GameRoot/LiuYu")
	if target == null:
		target = get_node_or_null("/root/Player")

	if target:
		target.set("can_move", value)


func _set_entry_idle_direction() -> void:
	var player := get_node_or_null("/root/GameRoot/LiuYu")
	if player == null:
		player = get_node_or_null("/root/Player")
	if player == null or not player.has_method("play_idle_direction"):
		return

	player.call("play_idle_direction", "right_up")
	if player.has_method("restore_idle_control"):
		player.call("restore_idle_control")


# ------------------------------------------------------------
# Dialog helpers
# ------------------------------------------------------------
func _show_dialog(lines: Array[String]) -> void:
	var dialog_manager := _get_dialog_manager()

	if dialog_manager == null:
		for line in lines:
			print(line)
		return

	if dialog_manager.has_method("show_dialog_sequence"):
		_waiting_for_dialog = true
		dialog_manager.show_dialog_sequence(_to_dialog_lines(lines), self)
		await _wait_dialog_finished(dialog_manager)
		return

	if dialog_manager.has_method("start_dialog"):
		dialog_manager.start_dialog(lines)
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


func _to_dialog_lines(lines: Array[String]) -> Array:
	var result: Array = []
	for line in lines:
		result.append({
			"text": line,
			"speaker": narration_speaker_id,
			"portrait": empty_portrait_path,
		})
	return result


# ------------------------------------------------------------
# GlobalState helpers
# ------------------------------------------------------------
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
