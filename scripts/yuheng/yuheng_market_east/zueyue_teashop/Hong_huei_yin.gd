# res://npc/tea_house_girl.gd
extends CharacterBody2D

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


		var lines := _compose_lines()
		dialog_manager.show_dialog_sequence(lines, self)
		await dialog_manager.dialog_sequence_finished

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
	var has_inn_info := inn_stage >= 2
	var already_met := GlobalState.get_flag("event_tea_house_first_met")

	# ❶ stage==1：第一次見面（未遇過）→ 初見沉默；已遇過 → 簡短沉默迴圈
	if main_stage == 1:
		if not already_met:
			GlobalState.set_flag("event_tea_house_first_met", true)
			var arr: Array = [
				{ "text": "(紅衣女伶正優雅地彈奏出優美的琴音)", "speaker": 1, "portrait": "res://assets/sprites/NPC/Yuheng/Hong_Huei_Yin_headshot.png"  }
,
			]
			if has_gossip and has_inn_info:
				arr.append_array([
					{ "text": "劉語塵：「(想必這位姑娘就是那位操琴高人……)」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"  },
					{ "text": "劉語塵：「(憑一己之力,利用琴功壓制鎮上所有人的情緒)」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"  },
					{ "text": "劉語塵：「(但她為何要這麼做？)」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"  },
					{ "text": "劉語塵：「(更令人不解的是，那麼在乎玉衡鎮的左飲，竟然\n默許有人以琴壓情。)」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"  },
					{ "text": "劉語塵：「(難道……她與左飲之間，有什麼淵源不成？)」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"  },
					{ "text": "劉語塵：「(看來，必須好好問問這位姑娘了。)」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"  },
				])
			arr.append_array([
				{ "text": "(你看著眼前專心彈琴的女伶，開口向他搭話)", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"  },
				{ "text": "劉語塵：「這位姑娘，您的琴音優美動人……不知這一曲，\n可有名目？」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"  },
				{ "text": "(她沒有回應你，依舊四平八穩地彈著琴)", "speaker": 1, "portrait": "res://assets/sprites/NPC/Yuheng/Hong_Huei_Yin_headshot.png"  },
				{ "text": "劉語塵：「...(是太專心彈琴所以沒注意到我嗎?)」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"  },
				{ "text": "劉語塵：「咳咳，我說,這位姑娘」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"  },
				{ "text": "劉語塵：「方便問一問這首調的曲名嗎?」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"  },
				{ "text": "(她不發一語看著你，眼神裡沒有拒絕，也沒有接納。不像敵意，\n更像是…給自己設下一道靜默的結界。)", "speaker": 1, "portrait": "res://assets/sprites/NPC/Yuheng/Hong_Huei_Yin_headshot.png" },
				{ "text": "劉語塵：「（唉~）」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"  },
				{ "text": "劉語塵：「（看樣子這位姑娘有甚麼難言之隱，無法以言而喻。\n跟她在這裡兜圈子想必也得不到甚麼答案）」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"  },
				{ "text": "劉語塵：「（先去繼續尋找能和左飲搭上線的方法吧！等見著左飲，\n我一定要問清楚這位姑娘的來歷，以及她到底在盤算些什麼？）」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"  },
			])
			return arr
		# 已遇過（stage==1 + flag 已設）→ 簡短沉默迴圈
		if has_gossip and has_inn_info:
			return [
				{ "text": "（她依舊靜靜彈著琴，不再對眼，也未曾說話。）", "speaker": 1, "portrait": "res://assets/sprites/NPC/Yuheng/Hong_Huei_Yin_headshot.png" },
				{ "text": "劉語塵：「（等見著左飲，我一定要問清楚這位姑娘的來歷……\n以及她到底在盤算什麼？）」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			]
		else:
			return [
				{ "text": "（她依舊靜靜彈著琴，不再抬眼，也未曾說話。）", "speaker": 1, "portrait": "res://assets/sprites/NPC/Yuheng/Hong_Huei_Yin_headshot.png" },
			]

	# ❷ stage==2：書眠贈詩後 → 琴音傳話（互動後會把主線推進到 3）
	if main_stage == 2:
		return [
			{ "text": "（她不開口，曲調依舊，但你這次卻彷彿從琴音裡聽到人聲……）", "speaker": 1, "portrait": "res://assets/sprites/NPC/Yuheng/Hong_Huei_Yin_headshot.png" },
			{ "text": "（琴音）少俠，現下我以琴代口與你溝通。", "speaker": 1, "portrait": "res://assets/sprites/NPC/Yuheng/Hong_Huei_Yin_headshot.png" },
			{ "text": "（琴音）我不開口，運行此琴功必須壓住內息，免得一念偏差，走火入魔。", "speaker": 1, "portrait": "res://assets/sprites/NPC/Yuheng/Hong_Huei_Yin_headshot.png" },
			{ "text": "（琴音）你已能聞弦外之音——還請助我一事。", "speaker": 1, "portrait": "res://assets/sprites/NPC/Yuheng/Hong_Huei_Yin_headshot.png" },
		]

	# ❸ stage≥3：之後皆為「琴音短迴圈」
	return [
		{ "text": "（琴音）拜託你了，少俠！", "speaker": 1, "portrait": "res://assets/sprites/NPC/Yuheng/Hong_Huei_Yin_headshot.png" }
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
