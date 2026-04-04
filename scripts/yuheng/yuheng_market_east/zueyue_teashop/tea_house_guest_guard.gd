# ==============================
# 客人乙｜鏢師
# res://npc/tea_house_guest_guard.gd
# ==============================
extends CharacterBody2D

const EnemyDB = preload("res://scripts/db/EnemyDB.gd")

@export var z_index_offset := 0
@export var portrait_path := "res://assets/sprites/NPC/YinHuo/Xan_Bu_Lay_headshot.png"
@export var speaker_id := 1
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
var _mark_flag_after_close := false

func _ready():
	dialog_manager = get_node("/root/GameRoot/DialogManager")
	if dialog_manager == null:
		push_warning("[TeaBoss] DialogManager 沒抓到！")

	if use_path_patrol:
		path_ref = get_node_or_null(path_node)
		if path_ref == null:
			push_warning("[TeaBoss] PathFollow2D 沒有設定或找不到：" + str(path_node))
	previous_position = global_position

	dialog_lines = _build_lines_for_stage(_get_main_stage_safely())

func _build_lines_for_stage(main_stage: int) -> Array:
	var met := GlobalState.get_flag("met_yuheng_teahouse_guard")
	var observed := GlobalState.get_flag("event_market_choice_observe")
	var heard_qin := GlobalState.get_flag("event_yuheng_market_melody")

	if not met:
		if observed and heard_qin:
			return [
			{ "text": "（一名鏢師坐於茶坊最深處，長身影落，氣息沉穩。他抬眼望向你）", "speaker": speaker_id,"portrait": "res://assets/sprites/empty.png" },
			{ "text": "（這名鏢師就這樣默默坐在角落，他看起來不像是本地人）", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "（說不定他也察覺琴聲的異樣……）", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "（正當你準備開口搭話時，鏢師搶先一步出聲。）", "speaker": speaker_id, "portrait": "res://assets/sprites/empty.png" },
			{ "text": "「那琴聲……不，是內功。你也聽見了，對吧？」", "speaker": speaker_id, "portrait": portrait_path },
			{ "text": "（!!!）", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "「少俠，既來此處，不若共飲一盞。這茶坊人多，話可輕，心難動」。", "speaker": speaker_id,"portrait": portrait_path },
			{ "text": "（你在他對面坐下，他為你斟了一盞茶，未多言）", "speaker": 1,"portrait": "res://assets/sprites/empty.png" },
			{ "text": "「這茶不濃，但回甘。然而這鎮子，靜得太深，反倒讓人提不起氣。」", "speaker": speaker_id,"portrait": portrait_path },
			{ "text": "劉語塵: 「先謝過，敢問閣下尊名？」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "「行走江湖，姓甚名誰早丟在路上，只有一名號——單步雷。」", "speaker": speaker_id, "portrait": portrait_path },
			{ "text": "「在下劉語塵。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
			{ "text": "單步雷: 「劉少俠，如今世上語魅橫行、邪典四起，\n你千里迢迢來到此地，想必也是有所求？」", "speaker": speaker_id },
			{ "text": "劉語塵: 「（心頭一震，隨即鎮定）單兄好眼力，\n在下此行乃為尋左飲，想問他一物的下落。」", "speaker": 2 },
			{ "text": "劉語塵: 「還是說單兄鏢路縱橫、見識廣博，\n或可向您請教？」", "speaker": 2 },
			{ "text": "單步雷: 「（抿一口茶）我們幹這行的，知道的多，\n不能說的更多。尋物找人之事，問不得。」", "speaker": speaker_id },
			{ "text": "單步雷: 「許多事無可奉告，還請少俠見諒。」", "speaker": speaker_id },
			{ "text": "劉語塵: 「（唉，果然鏢局最大的特點就是守口如瓶，\n哪有那麼容易問到情報的）」", "speaker": 2 },
			{ "text": "劉語塵: 「單兄，敝人一時莽撞，讓您難為了，還望見諒。」", "speaker": 2 },
			{ "text": "單步雷: 「別見外，江湖上像你這般有禮的人，不多見了。\n哪像我，講話粗、脾氣直。往日遇不平事，向來先亮嗓子，\n再亮拳頭。」", "speaker": speaker_id },
			{ "text": "單步雷: 「可來這鎮子，一張口就像被誰從喉頭按住。」", "speaker": speaker_id },
			{ "text": "單步雷: 「（望向遠方，聲音極輕）就像那時候……\n也是這樣的聲音……」", "speaker": speaker_id },
			{ "text": "劉語塵: 「那時候？」", "speaker": 2 },
			{ "text": "單步雷: 「（微微一怔，回神一笑）唉，不足掛齒的往事，\n不提也罷。」", "speaker": speaker_id },
			{ "text": "單步雷: 「（語氣平靜，卻透出一絲難掩的悲意）怒能護人，\n也能傷人。可若連怒都壓著，我還護得了誰？」", "speaker": speaker_id },
			{ "text": "單步雷: 「抱歉啦劉少俠，我這茶喝多了，提神過了頭，今日便\n先到這。來日有緣，再敘。」", "speaker": speaker_id },
			{ "text": "劉語塵: 「也是，在這琴聲的影響之下，話說得越多，\n心只會跟茶回沖一樣，越沖越淡。」", "speaker": 2 }
		
		]
		else:
			return [
				{ "text": "（一名鏢師坐於茶坊最深處，長身影落，氣息沉穩。他抬眼望向你）", "speaker": speaker_id,"portrait": "res://assets/sprites/empty.png" },
				{ "text": "（這名鏢師就這樣默默坐在角落，他看起來不像是本地人）", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "（正當你準備開口搭話時，鏢師搶先一步出聲。）", "speaker": speaker_id,"portrait": "res://assets/sprites/empty.png" },
				{ "text": "「少俠，既來此處，不若共飲一盞。這茶坊人多，話可輕，心難動。」", "speaker": speaker_id,"portrait": portrait_path },
				{ "text": "（你在他對面坐下，他為你斟了一盞茶，未多言）", "speaker": 1,"portrait": "res://assets/sprites/empty.png" },
				{ "text": "「這茶不濃，但回甘。然而這鎮子，靜得太深，反倒讓人提不起氣。」", "speaker": speaker_id,"portrait": portrait_path },
				{ "text": "劉語塵: 「先謝過，敢問閣下尊名？」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "「行走江湖，姓甚名誰早丟在路上，只有一名號——單步雷。」", "speaker": speaker_id, "portrait": portrait_path },
				{ "text": "「在下劉語塵。」", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "單步雷: 「劉少俠，如今世上語魅橫行、邪典四起，\n你千里迢迢來到此地，想必也是有所求？」", "speaker": speaker_id },
				{ "text": "劉語塵: 「（心頭一震，隨即鎮定）單兄好眼力，\n在下此行乃為尋左飲，想問他一物的下落。」", "speaker": 2 },
				{ "text": "劉語塵: 「還是說單兄鏢路縱橫、見識廣博，或可向您請教？」", "speaker": 2 },
				{ "text": "單步雷: 「（抿一口茶）我們幹這行的，知道的多，\n不能說的更多。尋物找人之事，問不得。」", "speaker": speaker_id },
				{ "text": "單步雷: 「許多事無可奉告，還請少俠見諒。」", "speaker": speaker_id },
				{ "text": "劉語塵: 「（唉，果然鏢局最大的特點就是守口如瓶，\n哪有那麼容易問到情報的）」", "speaker": 2 },
				{ "text": "劉語塵: 「單兄，敝人一時莽撞，讓您難為了，還望見諒。」", "speaker": 2 },
				{ "text": "單步雷: 「別見外，江湖上像你這般有禮的人，不多見了。\n哪像我，講話粗、脾氣直。往日遇不平事，向來先亮嗓子，\n再亮拳頭。」", "speaker": speaker_id },
				{ "text": "單步雷: 「可來這鎮子，一張口就像被誰從喉頭按住。」", "speaker": speaker_id },
				{ "text": "單步雷: 「（望向遠方，聲音極輕）就像那時候……\n也是這樣的聲音……」", "speaker": speaker_id },
				{ "text": "劉語塵: 「那時候？」", "speaker": 2 },
				{ "text": "單步雷: 「（微微一怔，回神一笑）唉，不足掛齒的往事，\n不提也罷。」", "speaker": speaker_id },
				{ "text": "單步雷: 「（語氣平靜，卻透出一絲難掩的悲意）怒能護人，\n也能傷人。可若連怒都壓著，我還護得了誰？」", "speaker": speaker_id },
				{ "text": "單步雷: 「抱歉啦劉少俠，我這茶喝多了，提神過了頭，今日便\n先到這。來日有緣，再敘。」", "speaker": speaker_id },
				{ "text": "劉語塵: 「(看來單兄果然十分在意這琴聲…)」", "speaker": 2 },
				{ "text": "劉語塵: 「也好，來日方長。到時若再見面，換我請您一壺酒。」", "speaker": 2 }
		]

	# 循環簡版（章一內）
	if main_stage <= 2:
		if observed and heard_qin:
			return [
				{ "text": "「少俠來日有緣，再敘。」", "speaker": speaker_id, "portrait": portrait_path },
			]
		else:
			return [ { "text": "「少俠來日有緣，再敘。」", "speaker": speaker_id, "portrait": portrait_path } ]

	return [ { "text": "「江湖一路，人各有難言。」", "speaker": speaker_id, "portrait": portrait_path } ]

func _process(delta):
	z_index = int(global_position.y + z_index_offset)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu": can_interact = true

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.name == "LiuYu": can_interact = false

func _unhandled_input(event):
	if not can_interact:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if is_talking:
			return
		is_talking = true
		var liuyu := get_node("/root/GameRoot/LiuYu")
		liuyu.can_move = false
		face_towards(liuyu.global_position)
		if GlobalState.get_flag("met_yuheng_teahouse_guard"):
			_show_interaction_menu()
			return

		# ✅ 這行是關鍵：在互動瞬間依目前旗標/主線重新組台詞
		var main_stage := _get_main_stage_safely()
		dialog_lines = _build_lines_for_stage(main_stage)

		dialog_manager.show_dialog_sequence(dialog_lines, self)
		# ✅ 在 reset_dialog_state 裡落旗與重建台詞
		_mark_flag_after_close = not GlobalState.set_flag("met_yuheng_teahouse_guard", true)

func _show_interaction_menu() -> void:
	dialog_manager.show_choice([
		{ "text": "比武", "callback": Callable(self, "_choose_spar") },
		{ "text": "閒聊", "callback": Callable(self, "_choose_chat") },
	])


func _choose_chat() -> void:
	dialog_manager.choice_box.hide_choices()
	var main_stage := _get_main_stage_safely()
	dialog_lines = _build_lines_for_stage(main_stage)
	dialog_manager.show_dialog_sequence(dialog_lines, self)


func _choose_spar() -> void:
	dialog_manager.choice_box.hide_choices()
	var lines := [
		{ "text": "單步雷: 「劉少俠，若願切磋，單某奉陪到底。點到為止。」", "speaker": speaker_id, "portrait": portrait_path },
	]
	dialog_manager.show_dialog_sequence(lines, self)
	await dialog_manager.dialog_finished
	await _start_training_battle()


func _start_training_battle() -> void:
	var liuyu := get_node_or_null("/root/GameRoot/LiuYu")
	if liuyu == null:
		is_talking = false
		return
	var game_root = get_node_or_null("/root/GameRoot")
	if game_root == null:
		liuyu.can_move = true
		is_talking = false
		return
	var current_scene = game_root.get_node_or_null("CurrentScene")
	var current_map := ""
	var scene_name := ""
	if current_scene and current_scene.get_child_count() > 0:
		var scene_root := current_scene.get_child(0)
		current_map = String(scene_root.scene_file_path)
		scene_name = String(scene_root.name)
		if current_map != "":
			GlobalState.set_meta("return_map_path", current_map)
	var battle_bgm_path := "res://assets/BGM/battle_1.ogg"
	if current_scene and current_scene.get_child_count() > 0:
		var scene_root_any := current_scene.get_child(0)
		var bgm_any = scene_root_any.get("battle_bgm_path")
		if bgm_any != null and str(bgm_any) != "":
			battle_bgm_path = str(bgm_any)
	GlobalState.set_meta("return_player_pos", liuyu.global_position)

	var enemy := EnemyDB.make_enemy("tea_house_guest_guard")
	if enemy.is_empty():
		liuyu.can_move = true
		is_talking = false
		return
	enemy["ui_index"] = 0
	var context = {
		"player_party": TeamData.get_active_party(),
		"enemy_party": [enemy],
		"ruleset": {"id": "sparring"},
		"regen_policy": {"id": "round_end_mp_regen_default"},
		"tone": {"intro_key": "zueyue_teashop_training"},
		"battle_tag": "zueyue_teashop_training",
		"zone_id": "zueyue_teashop_training",
		"map_id": current_map,
		"scene_name": scene_name,
		"battle_bgm_path": battle_bgm_path,
		"no_rewards": true
	}
	GlobalState.set_meta("pending_battle_context", context)
	if game_root.has_method("pause_world_bgm_for_battle"):
		game_root.pause_world_bgm_for_battle()
	liuyu.can_move = false
	if liuyu.has_method("lock_for_battle"):
		liuyu.lock_for_battle()
	game_root.change_map_to("res://scenes/battle_scene.tscn")

func reset_dialog_state():
	get_node("/root/GameRoot/LiuYu").can_move = true
	is_talking = false
	if _mark_flag_after_close:
		GlobalState.set_flag("met_yuheng_teahouse_guard", true)
		_mark_flag_after_close = false
		# 旗標落地後，重建成「精簡循環版」
		dialog_lines = _build_lines_for_stage(_get_main_stage_safely())
		animated_sprite.play("idle")
			

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
