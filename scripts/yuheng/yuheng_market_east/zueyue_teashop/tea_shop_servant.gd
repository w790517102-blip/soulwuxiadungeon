# res://npc/tea_house_servant.gd
extends CharacterBody2D

const TeaHouseNightDialog = preload("res://scripts/yuheng/yuheng_market_east/zueyue_teashop/tea_house_night_dialog.gd")

const F_GO_TO_ZUIYUE_HUIYIN := "main_yh_go_to_zuiyue_huiyin"
const F_HUIYIN_FIRST_TALK_DONE := "event_huiyin_first_talk_done"

# 通用循環對白目前只完成 main_001。
# 日後新增某章的專屬循環對白時，才把該章與最後 stage 加進此表。
# 若目前主線已進入尚未支援的章節，會往前採用最近一個已支援章節的最後 stage。
const DIALOG_CHAPTER_LAST_STAGE := {
	"main_001": 10,
}
const DEFAULT_DIALOG_QUEST_ID := "main_001"

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/NPC/Yuheng/Teahouse_Servant_headshot.png"
@export var speaker_id := 1
@export var wander_range := 180
@export var wander_interval := 1.2
@export var wander_speed := 45.0
@export var use_path_patrol := false
@export var path_node: NodePath

@onready var animated_sprite := $AnimatedSprite2D
var dialog_manager: Node = null
var can_interact := false
var dialog_lines: Array = []
var wander_target := Vector2.ZERO
var wander_timer := 0.0
var last_direction := Vector2.DOWN
var last_idle_direction := Vector2.DOWN
var is_talking: bool = false
var has_recently_talked: bool = false
var path_ref: PathFollow2D = null
var previous_position: Vector2 = Vector2.ZERO
var _mark_flag_after_close := false

func _ready():
	dialog_manager = get_node("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[TeaServant] DialogManager 沒抓到！")

	if use_path_patrol:
		path_ref = get_node_or_null(path_node)
		if path_ref == null:
			push_warning("[TeaServant] PathFollow2D 沒有設定或找不到：" + str(path_node))
	previous_position = global_position

	dialog_lines = _build_lines_for_quest(_get_main_quest_state_safely())

func _build_lines_for_quest(quest_state: Dictionary) -> Array:
	var met := GlobalState.get_flag("met_yuheng_teahouse_servant")
	var observed := GlobalState.get_flag("event_market_choice_observe")
	var heard_qin := GlobalState.get_flag("event_yuheng_market_melody")
	var resolved_quest_state := _resolve_dialog_quest_state(quest_state)
	var main_stage := int(resolved_quest_state.get("stage", 1))

	# 夜晚茶坊：依「白天／夜晚有沒有說過話」「拿銅釦前後」共八種情況（見 TeaHouseNightDialog）。
	var night_lines := TeaHouseNightDialog.lines_for("servant", self, speaker_id, portrait_path, _build_huiyin_call_night_lines())
	if not night_lines.is_empty():
		return night_lines

	# 夜間主線（白天茶坊不會走到這裡）：紅徽音沒有開口吩咐；小二只是被琴音引出一份無來由的預感。
	if _is_waiting_for_huiyin_first_talk() and TeaHouseNightDialog.is_night_scene(self):
		return _build_huiyin_call_night_lines()

	# 白天 06（新曲奏響後）／05（舊水道與山莊會談後）：實際完成的世界事件優先於主線 stage。
	var day_lines := TeaHouseNightDialog.day_lines_for("servant", self, speaker_id, portrait_path)
	if not day_lines.is_empty():
		return day_lines

	# 首見：表／裏語氣分支
	if not met:
		if observed and heard_qin:
			return [
				{ "text": "店小二：「客倌裡請！」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "他剛開口準備大聲吆喝，忽地止住了。", "speaker": 0 },
				{ "text": "店小二：「……咳，客倌失禮了，我嗓子這幾日總是卡著似的。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "店小二：「熱茶馬上來，您先坐。今日上的是『醉月青魁』，回甘不苦澀，提神不擾眠。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "店小二：「那邊彈琴的姑娘？是新請來的，聽說是左飲爺引薦的高人。」", "speaker": speaker_id },
				{ "text": "忽然間，整間茶坊寂靜了下來，只餘琴聲緩緩。", "speaker": 0 },
				{ "text": "店小二：「您聽，那琴一響，滿坊都靜了三分。」", "speaker": speaker_id },
				{ "text": "店小二：「咱這坊裡近來靜得很，如果有誰話講重了，都像是被那琴音轉了調，給轉平了。」", "speaker": speaker_id },
				{ "text": "店小二：「就像我方才本想大聲招待您，突然滿腦都是這動人的琴聲，也不知道是不是分了神，竟給口水嗆著了。」", "speaker": speaker_id },
				{ "text": "店小二：「小的只求月底結帳時能講清楚話，別被當啞巴扣了工錢。」", "speaker": speaker_id }
			]
		else:
			return [
				{ "text": "店小二：「熱茶馬上來，您先坐。今日上的是『醉月青魁』，回甘不苦澀，提神不擾眠。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "店小二：「那邊彈琴的姑娘？是新請來的，聽說是左飲爺引薦的高人。」", "speaker": speaker_id },
				{ "text": "店小二：「您聽，那琴一響，滿坊都靜了三分。」", "speaker": speaker_id }
			]

	# 循環精簡語（主線 1～6：新曲還沒奏響，琴聲仍在壓情，沿用同一組循環）
	if main_stage <= 6:
		if observed and heard_qin:
			return [
				{ "text": "店小二：「現在我整日跑堂，卻一句話都不能講大聲……」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "店小二：「嗓子緊得很，連睡覺作夢都怕吵到誰似的。」", "speaker": speaker_id }
			]
		else:
			return [
				{ "text": "店小二：「客官來得正巧，茶湯正暖，琴聲正亮。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "店小二：「要不要來壺回甘不擾夢的『醉月青魁』？」", "speaker": speaker_id, "portrait": portrait_path }
			]

	else:
		# 【正常流程到不了】銅釦後必定同夜舊水道 → 同夜山莊會談 → 翌日白天（05），所以「銅釦後、會談前的白天」不是設計狀態，也沒有專屬台詞。
		# 這裡只是壞存檔/測試直接跳關時的保底中性台詞，不列入正式台詞矩陣。
		return [
			{ "text": "店小二：「客倌！裡面坐喲，今日還是『醉月青魁』，回甘不苦！」", "speaker": 1, "portrait": portrait_path },
			{ "text": "店小二：「想喝別的，儘管說嘿！」", "speaker": 1, "portrait": portrait_path },
		]


func _is_waiting_for_huiyin_first_talk() -> bool:
	return (
		GlobalState.get_flag(F_GO_TO_ZUIYUE_HUIYIN)
		and not GlobalState.get_flag(F_HUIYIN_FIRST_TALK_DONE)
	)


func _build_huiyin_call_night_lines() -> Array:
	return [
		{ "text": "店小二：「客倌，您可算來了——」", "speaker": speaker_id, "portrait": portrait_path },
		{ "text": "店小二：「咦？小的怎麼說得像早知道您會來似的。」", "speaker": speaker_id },
		{ "text": "店小二：「今夜添水擺盞時，我總不自覺多留了一副茶具。」", "speaker": speaker_id },
		{ "text": "店小二：「掌櫃問我留給誰，我也答不上來。」", "speaker": speaker_id },
		{ "text": "店小二：「可那琴聲一響，我腦中便晃過您佩劍進門的樣子。」", "speaker": speaker_id },
		{ "text": "店小二：「如今您真站在這兒，倒像是把一件早已發生在心裡的事，等成真的了。」", "speaker": speaker_id },
		{ "text": "店小二：「您別笑我，這話連小的自己都覺得玄。」", "speaker": speaker_id },
	]


func _process(delta):
	z_index = int(global_position.y + z_index_offset)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = true

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = false

func _unhandled_input(event):
	if not can_interact:
		animated_sprite.play("idle")
		return
	if dialog_manager.dialog_active:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if is_talking:
			return
		is_talking = true
		var liuyu := get_node("/root/GameRoot/LiuYu")
		liuyu.can_move = false
		face_towards(liuyu.global_position)
	
		# ✅ 這行是關鍵：在互動瞬間依目前旗標/主線重新組台詞
		var quest_state := _get_main_quest_state_safely()
		dialog_lines = _build_lines_for_quest(quest_state)

		dialog_manager.show_dialog_sequence(dialog_lines, self)
		# ✅ 在 reset_dialog_state 裡落旗與重建台詞
		_mark_flag_after_close = not GlobalState.set_flag("met_yuheng_teahouse_servant", true)

func reset_dialog_state():
	get_node("/root/GameRoot/LiuYu").can_move = true
	if is_talking:
		TeaHouseNightDialog.mark_talked("servant", self)
	is_talking = false
	if _mark_flag_after_close:
		GlobalState.set_flag("met_yuheng_teahouse_servant", true)
		_mark_flag_after_close = false
		# 旗標落地後，重建成「精簡循環版」
		dialog_lines = _build_lines_for_quest(_get_main_quest_state_safely())
		animated_sprite.play("idle")


func _get_main_quest_state_safely() -> Dictionary:
	var qm := get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("get_main_quest_state"):
		var state: Dictionary = qm.get_main_quest_state()
		return state.duplicate(true)

	qm = get_node_or_null("/root/GameRoot/QuestManager")
	if qm and qm.has_method("get_main_quest_state"):
		var state2: Dictionary = qm.get_main_quest_state()
		return state2.duplicate(true)

	# QuestManager 暫時不可用時，保留新遊戲最初語境；不讓空資料造成無對白。
	return {
		"id": DEFAULT_DIALOG_QUEST_ID,
		"stage": 1,
	}


func _resolve_dialog_quest_state(quest_state: Dictionary) -> Dictionary:
	var quest_id := str(quest_state.get("id", "")).strip_edges()
	var quest_stage := maxi(1, int(quest_state.get("stage", 1)))

	# 空 ID 視為主線尚未完成初始化，維持 main_001 當前 stage，避免新遊戲誤跳後期。
	if quest_id.is_empty():
		return {
			"id": DEFAULT_DIALOG_QUEST_ID,
			"stage": clampi(quest_stage, 1, int(DIALOG_CHAPTER_LAST_STAGE[DEFAULT_DIALOG_QUEST_ID])),
		}

	# 已有該章專屬循環對白：使用該章自己的 stage。
	if DIALOG_CHAPTER_LAST_STAGE.has(quest_id):
		return {
			"id": quest_id,
			"stage": clampi(quest_stage, 1, int(DIALOG_CHAPTER_LAST_STAGE[quest_id])),
		}

	# 尚未替新章節撰寫循環對白時，往前尋找最近一個已支援章節，
	# 並採用該章最後 stage，避免跨章後退回初期台詞或變成無對白。
	var chapter_number := _parse_main_quest_number(quest_id)
	if chapter_number >= 2:
		for previous_number in range(chapter_number - 1, 0, -1):
			var previous_id := "main_%03d" % previous_number
			if DIALOG_CHAPTER_LAST_STAGE.has(previous_id):
				return {
					"id": previous_id,
					"stage": int(DIALOG_CHAPTER_LAST_STAGE[previous_id]),
				}

	# 非預期 ID 也採安全的最近完成語境，不回傳空陣列。
	push_warning("[TeaServant] 未支援的主線 ID：%s；改用 %s 的最後 stage。" % [quest_id, DEFAULT_DIALOG_QUEST_ID])
	return {
		"id": DEFAULT_DIALOG_QUEST_ID,
		"stage": int(DIALOG_CHAPTER_LAST_STAGE[DEFAULT_DIALOG_QUEST_ID]),
	}


func _parse_main_quest_number(quest_id: String) -> int:
	if not quest_id.begins_with("main_"):
		return -1
	var suffix := quest_id.trim_prefix("main_")
	if not suffix.is_valid_int():
		return -1
	return int(suffix)

func face_towards(target_position: Vector2) -> void:
	var direction = (target_position - global_position).normalized()
	last_direction = direction
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
