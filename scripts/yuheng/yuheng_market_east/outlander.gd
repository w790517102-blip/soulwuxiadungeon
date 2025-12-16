extends CharacterBody2D

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/empty.png"
@export var speaker_id := 1
@export var wander_range := 240
@export var wander_interval := 1.5
@export var wander_speed := 60.0
@export var use_path_patrol := true
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
var patrol_progress := 0.0
var path_ref: PathFollow2D = null
var previous_position: Vector2 = Vector2.ZERO
var _mark_flag_after_close := false # ✅ 對話關閉後才落旗，並重建循環台詞

func _ready():
	dialog_manager = get_node("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[NPC] DialogManager 沒抓到！")

	if use_path_patrol:
		path_ref = get_node_or_null(path_node)
		if path_ref == null:
			push_warning("[NPC] PathFollow2D 沒有設定或找不到：" + str(path_node))

	previous_position = global_position

	var main_stage := _get_main_stage_safely()
	dialog_lines = _build_lines_for_stage(main_stage)

func _process(delta):
	z_index = int(global_position.y + z_index_offset)
	# 可選：補你的巡邏或隨機走動邏輯

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = true

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "LiuYu":
		can_interact = false

func _unhandled_input(event):
	if not can_interact:
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

		# 第一次聽完可順便解鎖圖鑑（可選）
		if not GlobalState.get_flag("codex_yumei_unlocked"):
			GlobalState.set_flag("codex_yumei_unlocked", true)

		dialog_manager.show_dialog_sequence(dialog_lines, self)
		# ✅ 在 reset_dialog_state 裡落旗與重建台詞
		_mark_flag_after_close = not GlobalState.get_flag("met_wanderer_yumei")

func reset_dialog_state():
	# DialogManager 結束時會呼叫這裡
	var liuyu := get_node("/root/GameRoot/LiuYu")
	if liuyu:
		liuyu.can_move = true
	is_talking = false

	# ✅ 首輪剛結束 → 落旗＆重建循環台詞（無須離場重進）
	if _mark_flag_after_close:
		GlobalState.set_flag("met_wanderer_yumei", true)
		_mark_flag_after_close = false
		var main_stage := _get_main_stage_safely()
		dialog_lines = _build_lines_for_stage(main_stage)

# ---------------- 台詞組裝 ----------------

func _build_lines_for_stage(main_stage: int) -> Array:
	var met := GlobalState.get_flag("met_wanderer_yumei")

	# ❶ 尚未遇過 → 播放完整解說版本（你原稿＋劉語塵內心）
	if main_stage <= 2:
		if not met:
			return [
				{ "text": "「少俠，可曾聽過『言靈』與『語魅』之別？」", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "「咱這世道，有兩種靈體纏著人說話——一正一邪。」", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },

				{ "text": "「『言靈』護的是話本來的意思。」", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "「比如我說『我很生氣』，你聽懂我的憤怒，但你不會因此而被我的怒氣\n牽著走，讓自己也起了怒，反而心裡起的念多半生的是理解與同情——」", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "「知道『生氣』的意，卻不會被牽動著情，那份恰到好處的情緒，便是言靈\n把『意』與『情』傳遞得分寸不差。」", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },

				{ "text": "「『語魅』可不講分寸。」", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "「它只管把情緒硬塞進你心裡，哪怕把話的本意扭得全非。」", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "「譬如有人被附了魅，偏要罵一句：『相由心生，你這副德行，心也不會\n好到哪去！』」", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "「其實『相由心生』本意為眾生看待世間一切事物的樣貌皆發自觀者本身\n的內心，這話本是教人修己觀物，莫被外物牽走心神——」", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "「到了語魅嘴裡，便只剩挑唆與鄙夷。」", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "「再比如有人訴苦：『我總為愛發瘋。』」","speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "「旁人卻接：『好啊，那你就愛發瘋吧。』」", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "「這種故意曲解、讓委屈與怒氣蔓延的，也是語魅在作祟。」", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "「一句話——言靈使人『明白』，語魅只教人『上頭』。」", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "「如今這玉衡鎮，人人隨和不起爭，反倒裊裊琴音不曾斷，怕也不是沒緣由。」", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },

				{ "text": "劉語塵：「(嗯……這麼一說，語魅之禍理應處處留痕，而玉衡鎮\n這裡卻不見影跡。)」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "劉語塵：「(語魅魍魎不僅能以言亂人，禍害人間，)」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "劉語塵：「(實力強大的甚至具有形體，能夠威脅到人身安全)」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "劉語塵：「(我在路上已見識過許多人受其所害了。)」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "劉語塵：「(但這裡卻一片祥和，光靠左飲一個人真的有辦法\n做到這種地步嗎?)」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "劉語塵：「(該有的陰風不來，卻像有人先一步掃了場。)」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "劉語塵：「(到底是福是劫——還得多留心。)」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			]

	# ❷ 已遇過 → 依主線階段給簡短循環台詞
		else:
			return [
				{ "text": "如今這玉衡鎮，人人隨和不起爭，反倒裊裊琴音不曾斷，怕也不是沒緣由。」", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "劉語塵：「這裡不見任何語魅，光靠左飲一個人真的有辦法\n做到這種地步嗎?」", "speaker": 2, "portrait":  "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"  },
				{ "text": "劉語塵：「到底是福是劫——還得多留心。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" }
			]
	elif main_stage <= 6:
		return [
			{ "text": "琴聲善，善亦有度；善若過度，亦成執。", "speaker": 1, "portrait": portrait_path },
			{ "text": "此地群情雖平，卻像風停於谷，久之易悶。", "speaker": 1, "portrait": portrait_path },
		]
	else:
		return [
			{ "text": "白鳶橫天，像給谷口開了風眼。", "speaker": 1, "portrait": portrait_path },
			{ "text": "願君持衡——弦不傷人，心不傷己。", "speaker": 1, "portrait": portrait_path },
		]

# ---------------- 工具函式 ----------------

func _get_main_stage_safely() -> int:
	var qm := get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("get_main_quest_state"):
		var s: Dictionary = qm.get_main_quest_state()
		return int(s.get("stage", 1))
	qm = get_node_or_null("/root/GameRoot/QuestManager")
	if qm and qm.has_method("get_main_quest_state"):
		var s2: Dictionary = qm.get_main_quest_state()
		return int(s2.get("stage", 1))
	return 1

func _get_anim_by_vector(dir: Vector2, prefix: String) -> String:
	var angle = dir.angle()
	if angle >= -PI * 7/8 and angle < -PI * 5/8: return "%s_left_up" % prefix
	elif angle >= -PI * 5/8 and angle < -PI * 3/8: return "%s_up" % prefix
	elif angle >= -PI * 3/8 and angle < -PI * 1/8: return "%s_right_up" % prefix
	elif angle >= -PI * 1/8 and angle < PI * 1/8: return "%s_right" % prefix
	elif angle >= PI * 1/8 and angle < PI * 3/8: return "%s_right_down" % prefix
	elif angle >= PI * 3/8 and angle < PI * 5/8: return "%s_down" % prefix
	elif angle >= PI * 5/8 and angle < PI * 7/8: return "%s_left_down" % prefix
	else: return "%s_left" % prefix

func face_towards(target_position: Vector2) -> void:
	var direction = (target_position - global_position).normalized()
	last_direction = direction
	last_idle_direction = direction
	var anim_name = _get_anim_by_vector(direction, "idle")
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
