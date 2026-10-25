# res://npc/tea_house_boss.gd
extends CharacterBody2D

const TeaHouseNightDialog = preload("res://scripts/yuheng/yuheng_market_east/zueyue_teashop/tea_house_night_dialog.gd")

const ShopUI = preload("res://scripts/ui/ShopUI.gd")

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
@export var portrait_path := "res://assets/sprites/NPC/Yuheng/Teahouse_Boss_headshot.png"
@export var speaker_id := 1
@export var shop_id: String = "zueyue_teashop"
@export var wander_range := 160
@export var wander_interval := 2.0
@export var wander_speed := 30.0
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

func _ready():
	dialog_manager = get_node("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[TeaBoss] DialogManager 沒抓到！")

	if use_path_patrol:
		path_ref = get_node_or_null(path_node)
		if path_ref == null:
			push_warning("[TeaBoss] PathFollow2D 沒有設定或找不到：" + str(path_node))
	previous_position = global_position

	dialog_lines = _build_lines_for_quest(_get_main_quest_state_safely())

func _build_lines_for_quest(quest_state: Dictionary) -> Array:
	var met := GlobalState.get_flag("met_yuheng_teahouse_boss")
	var observed := GlobalState.get_flag("event_market_choice_observe")
	var heard_qin := GlobalState.get_flag("event_yuheng_market_melody")
	var resolved_quest_state := _resolve_dialog_quest_state(quest_state)
	var main_stage := int(resolved_quest_state.get("stage", 1))

	# 夜晚茶坊：依「白天／夜晚有沒有說過話」「拿銅釦前後」共八種情況（見 TeaHouseNightDialog）。
	var night_lines := TeaHouseNightDialog.lines_for("boss", self, speaker_id, portrait_path, _build_huiyin_call_night_lines())
	if not night_lines.is_empty():
		return night_lines

	# 夜間主線（白天茶坊不會走到這裡）：紅徽音未開口交代任何事；掌櫃只是從琴音裡生出劉語塵將至的預感。
	if _is_waiting_for_huiyin_first_talk() and TeaHouseNightDialog.is_night_scene(self):
		return _build_huiyin_call_night_lines()

	# 白天 06（新曲奏響後）／05（舊水道與山莊會談後）：實際完成的世界事件優先於主線 stage。
	var day_lines := TeaHouseNightDialog.day_lines_for("boss", self, speaker_id, portrait_path)
	if not day_lines.is_empty():
		return day_lines

	# ❶ 首見｜有觀察琴音者進入「裏」語氣
	if not met:
		if observed and heard_qin:
			return [
				{ "text": "掌櫃：「客官裡頭請，小店雅座仍有空位。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "掌櫃：「近日店內流行淡茶，配這琴的調剛剛好。」", "speaker": speaker_id },
				{ "text": "茶香混著弦音，在空氣裡緩緩擴散。", "speaker": 0 },
				{ "text": "劉語塵：「老闆，這茶坊內的悠悠琴聲有如天籟、餘音繞樑，是誰有這般雅致呢？」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "掌櫃：「啊～你也是被這琴音吸引過來的啊，這琴聲乃出自於店內駐彈的那位紅衣女伶之手。」", "speaker": speaker_id },
				{ "text": "掌櫃抬手指了指右方那位穿紅衣的彈琴女伶，琴聲未停。", "speaker": 0 },
				{ "text": "劉語塵：「好琴！」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "劉語塵：「但這琴音……雖說讓內心平靜，但聽著聽著……總覺得讓有些本來想說出口的話……欲言卻又止。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "劉語塵：「像是被琴音掐住了喉，說不出口。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "劉語塵：「敢問這位紅衣女伶的來歷？」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "掌櫃：「女伶之事……」", "speaker": speaker_id },
				{ "text": "話到嘴邊，被絃音壓了回去。", "speaker": 0 },
				{ "text": "掌櫃：「掌櫃的我，也只知她是左飲爺引進來的。至於緣由，從未細問。」", "speaker": speaker_id },
				{ "text": "掌櫃：「至於你說的琴音壓情，自有其妙，大家都有感覺到。不過內心平靜未嘗壞事，再加上女伶是左飲引薦的，大家也不深究了。」", "speaker": speaker_id },
				{ "text": "掌櫃：「只是壓久了，心頭像壓著絨被，雖說暖是暖的，但也悶。」", "speaker": speaker_id },
				{ "text": "掌櫃：「這世道，有時知太多，不如只知七分。」", "speaker": speaker_id },
				{ "text": "掌櫃：「客官若有困惑，不妨往市集西街走走。那裡……風聲比琴聲大些。」", "speaker": speaker_id }
			]
		else:
			return [
				{ "text": "掌櫃：「客官裡頭請，小店雅座仍有空位。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "掌櫃：「本坊請了一位女伶駐彈，是左飲爺親自提的。客人們都說，琴音沉靜養心。」", "speaker": speaker_id },
				{ "text": "掌櫃：「琴音聽著心就靜，靜心飲茶見真味。」", "speaker": speaker_id }
			]

	# ❷ 已對話｜循環（簡化）版本（主線 1～6：新曲還沒奏響，琴聲仍在壓情，沿用同一組循環）
	if main_stage <= 6:
		if observed and heard_qin:
			return [
				{ "text": "掌櫃：「這世道，有時知太多，不如只知七分。」", "speaker": speaker_id },
				{ "text": "掌櫃：「客官若有困惑，不妨往市集西街走走。那裡……風聲比琴聲大些。」", "speaker": speaker_id }
			]
		else:
			return [
				{ "text": "掌櫃：「來杯茶罷，客官。淡茶最適這兩日天氣。」", "speaker": speaker_id, "portrait": portrait_path }
			]

	else:
		# 【正常流程到不了】銅釦後必定同夜舊水道 → 同夜山莊會談 → 翌日白天（05），所以「銅釦後、會談前的白天」不是設計狀態，也沒有專屬台詞。
		# 這裡只是壞存檔/測試直接跳關時的保底中性台詞，不列入正式台詞矩陣。
		return [
			{ "text": "掌櫃：「客官來了，淡茶備著，想喝甚麼說一聲。」", "speaker": 1, "portrait": portrait_path },
			{ "text": "掌櫃：「近來坊裡一切照舊，慢坐便是。」", "speaker": 1, "portrait": portrait_path },
		]


func _is_waiting_for_huiyin_first_talk() -> bool:
	return (
		GlobalState.get_flag(F_GO_TO_ZUIYUE_HUIYIN)
		and not GlobalState.get_flag(F_HUIYIN_FIRST_TALK_DONE)
	)


func _build_huiyin_call_night_lines() -> Array:
	return [
		{ "text": "掌櫃：「客倌，我就知道您今夜還會再來。」", "speaker": speaker_id, "portrait": portrait_path },
		{ "text": "劉語塵：「掌櫃的知道我要來？」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
		{ "text": "掌櫃：「這……說真的，我也不知道自己怎麼會這麼說。」", "speaker": speaker_id, "portrait": portrait_path },
		{ "text": "掌櫃：「只是今夜聽那位女伶撫琴，腦子裡總不自覺浮出您白日進門的模樣。」", "speaker": speaker_id },
		{ "text": "掌櫃：「像這坊裡有張桌、有盞燈，原就該替您留著。」", "speaker": speaker_id },
		{ "text": "掌櫃：「如今真見到您，我反倒莫名鬆了口氣。」", "speaker": speaker_id },
		{ "text": "掌櫃：「怪事。可這琴聲近來帶來的怪事，也不只一樁了。」", "speaker": speaker_id },
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
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if is_talking:
			return
		is_talking = true
		var liuyu := get_node("/root/GameRoot/LiuYu")
		liuyu.can_move = false
		face_towards(liuyu.global_position)
		if GlobalState.get_flag("met_yuheng_teahouse_boss"):
			_show_interaction_menu()
			return
		_show_chat_dialog(true)


func _show_interaction_menu() -> void:
	dialog_manager.show_choice([
		{ "text": "購買", "callback": Callable(self, "_choose_buy") },
		{ "text": "閒聊", "callback": Callable(self, "_choose_chat") },
	])


func _choose_buy() -> void:
	dialog_manager.choice_box.hide_choices()
	var lines := [
		{ "text": "掌櫃：「客倌，既然都來了，要不買包茶？也可買些點心佐茶～」", "speaker": speaker_id, "portrait": portrait_path },
	]
	dialog_manager.show_dialog_sequence(lines, self)
	await dialog_manager.dialog_finished
	await _open_shop()


func _choose_chat() -> void:
	dialog_manager.choice_box.hide_choices()
	_show_chat_dialog(false)


func _show_chat_dialog(mark_met: bool) -> void:
	var quest_state := _get_main_quest_state_safely()
	dialog_lines = _build_lines_for_quest(quest_state)
	dialog_manager.show_dialog_sequence(dialog_lines, self)
	await dialog_manager.dialog_finished
	TeaHouseNightDialog.mark_talked("boss", self)
	if mark_met:
		GlobalState.set_flag("met_yuheng_teahouse_boss", true)
	var liuyu := get_node_or_null("/root/GameRoot/LiuYu")
	if liuyu:
		liuyu.can_move = true
	is_talking = false


func reset_dialog_state():
	pass

func _open_shop() -> void:
	var liuyu := get_node_or_null("/root/GameRoot/LiuYu")
	if liuyu == null:
		is_talking = false
		return
	is_talking = true
	liuyu.can_move = false
	await ShopUI.open_shop(shop_id, liuyu)
	liuyu.can_move = true
	is_talking = false

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
	push_warning("[TeaBoss] 未支援的主線 ID：%s；改用 %s 的最後 stage。" % [quest_id, DEFAULT_DIALOG_QUEST_ID])
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
