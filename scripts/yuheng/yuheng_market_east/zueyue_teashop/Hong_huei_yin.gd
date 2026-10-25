# res://npc/tea_house_girl.gd
extends CharacterBody2D

const TeaHouseNightDialog = preload("res://scripts/yuheng/yuheng_market_east/zueyue_teashop/tea_house_night_dialog.gd")

var _revisit_full_playing := false

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/NPC/Yuheng/Hong_Huei_Yin_headshot.png"
@export var speaker_id := 1
@export var use_path_patrol := false
@export var path_node: NodePath

@onready var animated_sprite := $AnimatedSprite2D
var dialog_manager: Node = null
var can_interact := false
var is_talking := false

var path_ref: PathFollow2D = null
var previous_position: Vector2 = Vector2.ZERO
var patrol_progress := 0.0

func _ready():
	dialog_manager = get_node("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[TeaGirl] DialogManager 沒抓到！")

	if use_path_patrol:
		path_ref = get_node_or_null(path_node)
		if path_ref == null:
			push_warning("[TeaGirl] PathFollow2D 沒有設定或找不到：" + str(path_node))
	previous_position = global_position

	# 若主線已超過 1，視為已遇過（僅用於避免場內重播初見）
	var main_stage := _get_main_stage_safely()
	if main_stage > 1:
		GlobalState.set_flag("event_tea_house_first_met", true)

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
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if is_talking:
			return
		is_talking = true

		var liuyu := get_node("/root/GameRoot/LiuYu")
		liuyu.can_move = false


		_revisit_full_playing = false
		var lines := _compose_lines()
		dialog_manager.show_dialog_sequence(lines, self)
		await dialog_manager.dialog_sequence_finished

		# 05 的完整重訪只播一次：整段播完才落旗。
		if _revisit_full_playing:
			GlobalState.set_flag(TeaHouseNightDialog.F_HUIYIN_REVISIT_05_SEEN, true)
			_revisit_full_playing = false

		# 若剛才為 stage==2 的琴音委託，對話結束後把主線推進到 3
		var main_stage := _get_main_stage_safely()
		if main_stage == 4:
			_advance_main_quest_to_5()

		liuyu.can_move = true
		is_talking = false

func reset_dialog_state():
	var liuyu := get_node("/root/GameRoot/LiuYu")
	if liuyu:
		liuyu.can_move = true
	is_talking = false

# ---------- 對話分流 ----------
func _compose_lines() -> Array:
	var main_stage := _get_main_stage_safely()
	var has_gossip := GlobalState.get_flag("triggered_zuoyin_gossip_summary")
	var inn_stage := int(SideQuestManager.get_quest("talk_to_yuheng_inn_boss").get("stage", 0))
	var has_inn_info := inn_stage >= 1
	var already_met := GlobalState.get_flag("event_tea_house_first_met")

	# 06（新曲奏響後）：不退回 05／04
	if TeaHouseNightDialog.is_stage_06() and GlobalState.get_flag(TeaHouseNightDialog.F_GOT_HALF_STRING_BUTTON):
		return TeaHouseNightDialog.huiyin_revisit_06(speaker_id, "res://assets/sprites/NPC/Yuheng/Hong_Huei_Yin_headshot.png", "res://assets/sprites/empty.png")

	# 05（舊水道事件與山莊會談之後，翌日白天）：完整重訪演出只播一次，之後播精簡循環。
	if TeaHouseNightDialog.is_stage_05() and GlobalState.get_flag(TeaHouseNightDialog.F_GOT_HALF_STRING_BUTTON):
		var empty_portrait := "res://assets/sprites/empty.png"
		var hong_portrait := "res://assets/sprites/NPC/Yuheng/Hong_Huei_Yin_headshot.png"
		if GlobalState.get_flag(TeaHouseNightDialog.F_HUIYIN_REVISIT_05_SEEN):
			return TeaHouseNightDialog.huiyin_revisit_loop(speaker_id, hong_portrait, empty_portrait)
		_revisit_full_playing = true
		return TeaHouseNightDialog.huiyin_revisit_full(speaker_id, hong_portrait, empty_portrait)

	# ❶ stage==1：第一次見面（未遇過）→ 初見沉默；已遇過 → 簡短沉默迴圈
	if main_stage == 1:
		if not already_met:
			GlobalState.set_flag("event_tea_house_first_met", true)
			var arr: Array = [
				_n("紅衣女伶正優雅地彈奏著，琴音悠揚。"),
			]
			if has_gossip and has_inn_info:
				arr.append_array([
					_liu("（心想）想必這位姑娘就是那位操琴高人……"),
					_liu("（心想）憑一己之力，利用琴功壓制鎮上所有人的情緒。但她為何要這麼做？"),
					_liu("（心想）更令人不解的是，那麼在乎玉衡鎮的左飲，竟然默許有人以琴壓情。"),
					_liu("（心想）難道……她與左飲之間，有什麼淵源不成？"),
					_liu("（心想）看來，必須好好問問這位姑娘了。"),
				])
			arr.append_array([
				_n("你看著眼前專心彈琴的女伶，開口搭話。"),
				_liu("這位姑娘，您的琴音優美動人……不知這一曲，可有名目？"),
				_n("她沒有回應，依舊四平八穩地彈著琴。"),
				_liu("（心想）……是太專心彈琴所以沒注意到我嗎？"),
				_liu("咳咳，我說，這位姑娘。"),
				_liu("方便問一問這首調的曲名嗎？"),
				_n("她不發一語地看著你，眼神裡沒有拒絕，也沒有接納。不像敵意，更像是……給自己設下一道靜默的結界。"),
				_n("你輕輕嘆了口氣。看樣子這位姑娘有什麼難言之隱，無法以言而喻，跟她在這裡兜圈子，想必也得不到什麼答案。"),
				_liu("（心想）先去繼續尋找能和左飲搭上線的方法吧。等見著左飲，我一定要問清楚這位姑娘的來歷，以及她到底在盤算些什麼。"),
			])
			return arr
		# 已遇過（stage==1 + flag 已設）→ 簡短沉默迴圈
		if has_gossip and has_inn_info:
			return [
				_n("她依舊靜靜彈著琴，不再對眼，也未曾說話。"),
				_liu("（心想）等見著左飲，我一定要問清楚這位姑娘的來歷……以及她到底在盤算什麼。"),
			]
		else:
			return [
				_n("她依舊靜靜彈著琴，不再抬眼，也未曾說話。"),
			]

	# ❷ stage==2：書眠贈詩後 → 琴音傳話（互動後會把主線推進到 3）
	if main_stage == 2:
		return [
			_n("她不開口，曲調依舊，但你這次卻彷彿從琴音裡聽到人聲……"),
			_hong("（琴音）少俠，現下我以琴代口與你溝通。"),
			_hong("（琴音）我不開口，運行此琴功必須壓住內息，免得一念偏差，走火入魔。"),
			_hong("（琴音）你已能聞弦外之音——還請助我一事。"),
		]

	# ❸ stage≥3：05 以前白天只有靜默彈琴（那句請託是夜晚取得銅釦後才有的台詞）
	return [
		_n("她專注地彈著琴，指下琴聲未歇。"),
	]


# ---------- 主線讀取／推進（安全版） ----------
func _get_main_stage_safely() -> int:
	# AutoLoad 版本（建議）
	var qm := get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("get_main_quest_state"):
		var s: Dictionary = qm.get_main_quest_state()
		return int(s.get("stage", 1))

	# 場景內 GameRoot 備援版本
	qm = get_node_or_null("/root/GameRoot/QuestManager")
	if qm and qm.has_method("get_main_quest_state"):
		var s2: Dictionary = qm.get_main_quest_state()
		return int(s2.get("stage", 1))

	push_warning("[TeaGirl] 找不到 QuestManager，主線階段以 1 代替。")
	return 1

func _advance_main_quest_to_5():
	var qm := get_node_or_null("/root/QuestManager")
	if qm == null:
		qm = get_node_or_null("/root/GameRoot/QuestManager")
	if qm and qm.has_method("advance_main_quest"):
		qm.advance_main_quest(5, "承女伶之託，尋線追查")
	else:
		push_warning("[TeaGirl] QuestManager 不存在或缺 advance_main_quest()，無法推進主線。")

# ---------- 小工具 ----------
const _HONG_PORTRAIT := "res://assets/sprites/NPC/Yuheng/Hong_Huei_Yin_headshot.png"
const _LIU_PORTRAIT := "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"
const _EMPTY_PORTRAIT := "res://assets/sprites/empty.png"


## 旁白（第二人稱／客觀敘事）：speaker 0，上方無頭像欄
func _n(text: String) -> Dictionary:
	return { "text": text, "speaker": 0, "portrait": _EMPTY_PORTRAIT }


func _liu(text: String) -> Dictionary:
	return { "text": "劉語塵：「%s」" % text, "speaker": 2, "portrait": _LIU_PORTRAIT }


## 夜訪報名前稱「紅衣女伶」，報名後（met_hong_huiyin_name）才稱「紅徽音」
func _hong(text: String) -> Dictionary:
	var hong_name := "紅徽音" if GlobalState.get_flag("met_hong_huiyin_name") else "紅衣女伶"
	return { "text": "%s：「%s」" % [hong_name, text], "speaker": speaker_id, "portrait": _HONG_PORTRAIT }
