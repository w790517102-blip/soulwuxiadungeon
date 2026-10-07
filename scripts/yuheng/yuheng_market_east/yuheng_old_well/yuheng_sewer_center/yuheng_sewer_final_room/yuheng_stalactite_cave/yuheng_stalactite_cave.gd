extends Node2D
class_name YuhengStalactiteCave

const EnemyDBScript = preload("res://scripts/db/EnemyDB.gd")
const BattlePhaseProfileDBScript = preload("res://scripts/db/BattlePhaseProfileDB.gd")
const MolinYanjiangScene = preload("res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_final_room/yuheng_stalactite_cave/molingyanjiang.tscn")
const YumeiElementScene: PackedScene = preload("res://scenes/fx/yumei_element.tscn")
const MolinPhase2ParryTexture: Texture2D = preload("res://assets/sprites/NPC/Yuheng/molingyanjiang_phase2_parry.png")

# ------------------------------------------------------------
# 場景路徑 / 基本設定
# ------------------------------------------------------------
@export_file("*.tscn") var yuheng_sewer_final_room: String = "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_final_room/yuheng_sewer_final_room.tscn"
@export_file("*.tscn") var yin_yue_manor_room_night: String = "res://scenes/yuheng/YinYueManor/yin_yue_manor_room/yin_yue_manor_room(night).tscn"

@export var music_tag := "yuheng_sewer"
@export var map_display_name: String = "玉衡鎮地下鐘乳石洞"
@export var manor_spawn_point_name := "Liu_yu_Initial_point"
@export var sewer_final_room_spawn_point_name := "from_yuheng_stalactite_cave"

@export var zuoyin_arrival_cutscene_key := "yuheng_stalactite_zuoyin_arrival"

@export var fish_boss_battle_id := "boss_yuheng_molin_yanjiang_phase1"
@export var fish_boss_enemy_id := "molin_yanjiang"

# 對話設定
@export var empty_portrait_path := "res://assets/sprites/empty.png"
@export var liuyu_portrait_path := "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"
@export var shumian_portrait_path := "res://assets/sprites/NPC/Yuheng/Su_Mien_headshot2.png"
@export var zuoyin_portrait_path := "res://assets/sprites/NPC/Yuheng/Zuo_Yin_headshot2.png"
@export var boss_phase1_portrait_path := "res://assets/Enemy/molingyanjiang_phase1.png"
@export var boss_phase2_portrait_path := "res://assets/Enemy/molingyanjiang_phase2.png"

@export var narration_speaker_id := 0
@export var liuyu_speaker_id := 2
@export var shumian_speaker_id := 2
@export var zuoyin_speaker_id := 2
@export var boss_speaker_id := 1

@onready var overlay: ColorRect = get_node_or_null("BlackOverlay")
@onready var event_trigger: Area2D = get_node_or_null("Su_mien_event_trigger2/Su_mien_event_trigger")
@onready var intro_video_layer: CanvasLayer = get_node_or_null("StalactiteIntroVideoLayer")
@onready var intro_video_player: VideoStreamPlayer = get_node_or_null("StalactiteIntroVideoLayer/VideoStreamPlayer")
@onready var shumian_npc: Node2D = get_node_or_null("NPC/Su_mien")
@onready var zuoyin_npc: Node2D = get_node_or_null("NPC/Zuo_yin")

signal dialog_closed
signal stalactite_intro_video_finished

# ------------------------------------------------------------
# 劇情 / 戰鬥 Flags
# ------------------------------------------------------------
const F_STALACTITE_INTRO_DONE := "event_stalactite_shumian_intro_done"
const F_FINAL_SEAL_OPENED := "sewer_final_seal_opened"
const F_FISH_BOSS_STARTED := "battle_stalactite_fish_boss_started"
const F_FISH_BOSS_PHASE2 := "battle_stalactite_fish_boss_phase2"
const F_ZUOYIN_ASSIST_ACTIVE := "battle_stalactite_zuoyin_assist_active"
const F_FISH_BOSS_WON := "battle_stalactite_fish_boss_won"
const F_FISH_BOSS_REWARDS_GRANTED := "battle_stalactite_fish_boss_rewards_granted"
const F_MANOR_AFTER_FISH_READY := "main_yh_manor_after_fish_ready"
const PHASE2_BATTLE_ID := "boss_yuheng_molin_yanjiang_phase2"
const PHASE2_REWARD_SKILL_ID := "skill_breaking_wave_spear"
const PHASE2_REWARD_INNER_FORCE_ID := "chenchao_jue"
const POST_BATTLE_CAPTIONS := [
	"經過一場激烈的惡鬥後，你們終於離開了鐘乳石洞。",
	"待重新踏上玉衡鎮的街道時，夜色依舊深沉。",
	"一路上，誰也沒有多說什麼。",
	"回到飲月山莊時，紅徽音與顧石已靜靜等候在山門前。",
	"紅徽音看了看你，又看向白書眠與左飲，卻什麼也沒有問。",
	"最後，你們四人一言不發地走進山莊。",
	"顧石仍留在門外，重新守住那扇山門。",
]
const POST_BATTLE_CAPTION_FADE_SECONDS := 0.3
const POST_BATTLE_CAPTION_HOLD_SECONDS := 1.8
const POST_BATTLE_CAPTION_GAP_SECONDS := 0.2

const F_ZUOYIN_GUEST_JOINED := "party_zuoyin_guest_joined"
const SPECIAL_BATTLE_PARTY_IDS := ["liuyu", "shumian"]
const SPECIAL_BATTLE_INSIGHT_SOURCE_IDS := ["shumian"]
const CAVE_SCENE_PATH := "res://scenes/yuheng/yuheng_market_east/yuheng_old_well/yuheng_sewer_center/yuheng_sewer_final_room/yuheng_stalactite_cave/yuheng_stalactite_cave.tscn"
const BATTLE_SCENE_PATH := "res://scenes/battle_scene.tscn"
const INTRO_SKIP_GATE_SECONDS := 0.5
const PHASE_BREAK_KEY := "molin_yanjiang_phase1_to_phase2"
const PHASE1_BGM_PATH := "res://assets/BGM/battle_boss_yumei.ogg"
const PHASE_TRANSITION_BOSS_SCALE := 0.65
const YUMEI_ABSORPTION_DIRECTIONS := 8
const YUMEI_ELEMENTS_PER_WAVE := 4
const YUMEI_ABSORPTION_RADIUS_X := 330.0
const YUMEI_ABSORPTION_RADIUS_Y := 225.0
const YUMEI_ABSORPTION_WAVE_INTERVAL := 0.34
const YUMEI_ABSORPTION_TARGET_OFFSET := Vector2(0.0, -8.0)
const PHASE_PATH_1_DURATION := 0.48
const PHASE_PATH_2_DURATION := 0.22
const PHASE_PATH_3_DURATION := 0.38
const PHASE_PATH_4_DURATION := 0.32
const PHASE_PATH_5_DURATION := 0.28
const PHASE_PATH_6_DURATION := 0.30
const HELP_RUN_SPEED_SCALE := 0.8
const LIUYU_ATTACK_SPEED_SCALE := 1.3
const LIUYU_BACKWARD_DODGE_SPEED_SCALE := 1.3
const BOSS_DODGE_SPEED_SCALE := 2.0
const BOSS_COUNTER_SPEED_SCALE := 2.0
const SU_MIEN_HIT_IMPACT_PAUSE_SECONDS := 0.3
const BOSS_ABSORPTION_COLOR_STEP_SECONDS := 0.42
const BOSS_TRANSFORMATION_WHITE_FADE_OUT_SECONDS := 0.18
const BOSS_GUARD_PULSE_STEP_SECONDS := 0.018
const BOSS_GUARD_PULSE_DISTANCE := 8.0
const ZUOYIN_JUMP_BASE_DURATION := 0.45
const ZUOYIN_JUMP_SPEED_SCALE := 0.85
const LIUYU_PHASE_TRANSITION_SHADOW_OFFSET := Vector2(0.0, -20.0)
const BOSS_TRANSFORMATION_WHITE_SHADER := """
shader_type canvas_item;

uniform float white_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 source = COLOR;
	vec3 whitened = mix(source.rgb, vec3(1.0), white_amount);
	COLOR = vec4(whitened, source.a);
}
"""

# --- Phase 2 victory: the cave ending cutscene (between the return to the cave and the BlackOverlay) ----------------
## Where the carp hops to, relative to the boss's own spot (SpawnPoints/molingyanjiana_fight): the pond right of the
## stone platform, measured on the cave picture. Change it if the platform art moves.
@export var carp_water_offset := Vector2(215.0, 8.0)
const CAVE_VICTORY_FADE_IN_SECONDS := 1.0
const CAVE_VICTORY_BEAT_SECONDS := 0.7
const CARP_JUMP_SECONDS := 2.8
const CARP_HOP_COUNT := 5
const CARP_HOP_HEIGHT := 34.0
const CARP_SINK_SECONDS := 0.45
## They keep their guard up this long after the carp is gone, then lower it one after another.
const CAVE_VICTORY_WATCH_SECONDS := 1.3
const CAVE_VICTORY_RELAX_STAGGER_SECONDS := 0.7
const CAVE_VICTORY_SETTLE_SECONDS := 0.9
const CAVE_VICTORY_PAUSE_BEFORE_PEACE_SECONDS := 1.1
const CAVE_EXIT_WALK_SPEED := 150.0
const CAVE_EXIT_START_STAGGER_SECONDS := 0.5
## 左飲先走；另外兩人先看著他，這麼久之後才跟上。
const CAVE_EXIT_FOLLOW_DELAY_SECONDS := 2.0
const CAVE_EXIT_GAZE_STEP_SECONDS := 0.12
## 左飲的走路速度（px/s）；走路動畫是 5 格/秒的 4 格循環。
const ZUOYIN_EXIT_WALK_SPEED := 95.0
## The BlackOverlay starts to fade in as they start walking and is fully black by the end of this.
const CAVE_EXIT_FADE_SECONDS := 4.6

var story_locked := false
var transition_locked := false
var _waiting_for_dialog := false
var _skip_enabled := false
var _video_finishing := false
var _skip_wait_space_release := false
var _skip_wait_escape_release := false
var _skip_wait_mouse_release := false
var _event_trigger_requires_exit := false
var _phase_break_return_pending := false
## True from the first frame of a phase 2 victory return until the ending cutscene is over. GameRoot puts Liu Yu back at his
## pre-battle spot and gives control back AFTER this scene's _ready, so the cutscene has to re-apply his place and pose then
## (prepare_battle_return_actor), exactly as the phase break return does.
var _phase2_victory_cutscene_active := false
var _phase_transition_boss: Node2D = null
var _phase_absorption_fx: Node2D = null
var _yumei_particle_texture: Texture2D = null
var _boss_absorption_color_tween: Tween = null
var _boss_absorption_sprite: AnimatedSprite2D = null
var _boss_absorption_base_modulate: Color = Color.WHITE
var _boss_absorption_base_material: Material = null
var _boss_guard_pulse_tween: Tween = null


func _ready() -> void:
	var pending_result = GlobalState.get_meta("pending_battle_result", {})
	_phase_break_return_pending = _is_phase_break_result(pending_result)
	var phase2_victory_return_pending := _is_phase2_victory_result(pending_result)
	if phase2_victory_return_pending:
		_phase2_victory_cutscene_active = true
		# Battle UI and its reward confirmation have already closed before the map
		# return. Keep the first visible cave frame black for the chapter epilogue.
		_prime_phase_transition_black()
		story_locked = true
		transition_locked = true
		_set_player_movable(false)
	elif _phase_break_return_pending:
		# Phase break 回場的第一個可見畫面就是正式分鏡。先以全黑遮住，
		# 並在任何 fade out 開始前完成三名演員的生成、定位與首幀姿勢。
		_prime_phase_transition_black()
		if typeof(pending_result) == TYPE_DICTIONARY:
			GlobalState.set_meta(
				"stalactite_phase1_player_resources",
				(pending_result as Dictionary).get("player_resources", {}).duplicate(true)
			)
		story_locked = true
		_set_player_movable(false)
		_prepare_phase_transition_stage(_get_player())
	elif shumian_npc and not bool(_get_flag(F_FISH_BOSS_WON, false)):
		# 初次從洞口看見書眠時先讓她背向入口，之後的回眸才有方向變化。
		_play_actor_animation(shumian_npc, &"idle_right_up", true)
	if zuoyin_npc:
		zuoyin_npc.visible = false

	if event_trigger:
		if not event_trigger.body_entered.is_connected(_on_su_mien_event_trigger_body_entered):
			event_trigger.body_entered.connect(_on_su_mien_event_trigger_body_entered)
		if not event_trigger.body_exited.is_connected(_on_su_mien_event_trigger_body_exited):
			event_trigger.body_exited.connect(_on_su_mien_event_trigger_body_exited)
	else:
		push_warning("找不到 Su_mien_event_trigger2/Su_mien_event_trigger，鐘乳石洞事件不會自動觸發。")
	if intro_video_player and not intro_video_player.finished.is_connected(_on_stalactite_intro_video_naturally_finished):
		intro_video_player.finished.connect(_on_stalactite_intro_video_naturally_finished)
	if intro_video_layer:
		intro_video_layer.visible = false

	# 戰鬥回場時玩家會被放回原座標；必須先離開事件格，才可再次主動觸發。
	_event_trigger_requires_exit = bool(GlobalState.get_meta("pending_battle_return", false))

	if phase2_victory_return_pending:
		GlobalState.remove_meta("pending_battle_result")
		await on_fish_boss_battle_won()
		return

	await _play_entry_fade()
	if _phase_break_return_pending:
		GlobalState.remove_meta("pending_battle_result")
		await _play_phase_transition_and_start_phase2()
		return
	if bool(_get_flag(F_FINAL_SEAL_OPENED, false)) or bool(_get_flag(F_FISH_BOSS_WON, false)):
		_set_player_movable(true)
	show_map_name()

	# 若此戰已完成，玩家重回此圖時不再觸發。
	if _get_flag(F_FISH_BOSS_WON, false):
		_disable_event_trigger()


func get_map_display_name() -> String:
	return map_display_name


# ------------------------------------------------------------
# 進場淡入 / 地圖名稱
# ------------------------------------------------------------
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


# ------------------------------------------------------------
# 事件觸發：書眠過場 → 魚怪 BOSS 戰
# ------------------------------------------------------------
func _on_su_mien_event_trigger_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return

	if story_locked or _event_trigger_requires_exit or _get_flag(F_FISH_BOSS_WON, false):
		return

	story_locked = true
	_disable_event_trigger()
	_set_player_movable(false)

	if bool(_get_flag(F_STALACTITE_INTRO_DONE, false)):
		await _start_fish_boss_battle()
	else:
		await _start_stalactite_intro_and_battle()


func _on_su_mien_event_trigger_body_exited(body: Node2D) -> void:
	if _is_player(body):
		_event_trigger_requires_exit = false


func _start_stalactite_intro_and_battle() -> void:
	var game_root := get_node_or_null("/root/GameRoot")
	if game_root and game_root.has_method("stop_world_bgm"):
		await game_root.call("stop_world_bgm", 0.25)
	await _fade_out()
	await _play_stalactite_intro_video()

	_set_flag(F_STALACTITE_INTRO_DONE, true)
	_set_flag(F_FISH_BOSS_STARTED, true)
	await _wait_for_skip_input_release()
	await _start_fish_boss_battle()


func _play_stalactite_intro_video() -> void:
	_skip_enabled = false
	_video_finishing = false
	if intro_video_player == null or intro_video_player.stream == null:
		push_warning("鐘乳石洞過場影片節點或影片資源不存在，略過影片並繼續戰鬥進場。")
		return
	if intro_video_layer:
		intro_video_layer.visible = true
	intro_video_player.visible = true
	intro_video_player.play()

	# Gate 只從 VideoStreamPlayer 真正收到 play() 後開始計時。
	await get_tree().create_timer(INTRO_SKIP_GATE_SECONDS).timeout
	if _video_finishing:
		return
	_skip_enabled = true
	await stalactite_intro_video_finished


func _on_stalactite_intro_video_naturally_finished() -> void:
	_finish_stalactite_intro_video()


func _finish_stalactite_intro_video() -> void:
	if _video_finishing:
		return
	_video_finishing = true
	_skip_enabled = false
	if intro_video_player:
		intro_video_player.stop()
		intro_video_player.visible = false
	if intro_video_layer:
		intro_video_layer.visible = false
	stalactite_intro_video_finished.emit()


func _input(event: InputEvent) -> void:
	if not story_locked or not _skip_enabled or _video_finishing:
		return
	var accepted := false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_skip_wait_mouse_release = true
			accepted = true
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			var keycode := key_event.keycode
			var physical_keycode := key_event.physical_keycode
			if keycode == KEY_SPACE or physical_keycode == KEY_SPACE:
				_skip_wait_space_release = true
				accepted = true
			elif keycode == KEY_ESCAPE or physical_keycode == KEY_ESCAPE:
				_skip_wait_escape_release = true
				accepted = true
	if not accepted:
		return
	get_viewport().set_input_as_handled()
	_finish_stalactite_intro_video()


func _wait_for_skip_input_release() -> void:
	while (_skip_wait_space_release and Input.is_key_pressed(KEY_SPACE)) \
			or (_skip_wait_escape_release and Input.is_key_pressed(KEY_ESCAPE)) \
			or (_skip_wait_mouse_release and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		await get_tree().process_frame
	_skip_wait_space_release = false
	_skip_wait_escape_release = false
	_skip_wait_mouse_release = false


func _build_intro_fallback_lines() -> Array:
	return [
		_l("劉少俠……？你怎麼會在這裡？", shumian_speaker_id, shumian_portrait_path),
		_l("書眠姑娘。", liuyu_speaker_id, liuyu_portrait_path),
		_l("你離開白箋居後，神色不對。", liuyu_speaker_id, liuyu_portrait_path),
		_l("紅姑娘很擔心你。", liuyu_speaker_id, liuyu_portrait_path),
		_l("……我也是。", liuyu_speaker_id, liuyu_portrait_path),
		_l("你……為了找我，進了舊水道？", shumian_speaker_id, shumian_portrait_path),
		_l("那些機關與封印，不該那麼容易解開才是。", shumian_speaker_id, shumian_portrait_path),
		_l("確實不易。", liuyu_speaker_id, liuyu_portrait_path),
		_l("但我還是來了。", liuyu_speaker_id, liuyu_portrait_path),
		_l("……劉少俠。", shumian_speaker_id, shumian_portrait_path),
		_l("你的心意，我明白。", shumian_speaker_id, shumian_portrait_path),
		_l("可是，你不該來的。", shumian_speaker_id, shumian_portrait_path),
		_l("不是因為我不願見你。", shumian_speaker_id, shumian_portrait_path),
		_l("而是這裡的封印，不只是為了攔外人。", shumian_speaker_id, shumian_portrait_path),
		_l("它們也是為了讓這裡的水脈與濁氣維持平衡。", shumian_speaker_id, shumian_portrait_path),
		_l("所以，我解開封印，也驚動了它？", liuyu_speaker_id, liuyu_portrait_path),
		_l("……也許已經不只是驚動。", shumian_speaker_id, shumian_portrait_path),
		_l("你聽。", shumian_speaker_id, shumian_portrait_path),
		_n("洞中水聲忽然沉了下去。"),
		_n("桌上寫到一半的詩詞、石壁上的碑文，竟滲出一縷縷紫黑色穢氣。"),
		_n("那些穢氣滴入水面，像墨落清池，迅速向四周擴散。"),
		_l("這些是……語魅？", liuyu_speaker_id, liuyu_portrait_path),
		_l("看來，還是壓不住了。", shumian_speaker_id, shumian_portrait_path),
		_l("是我破了封印，才讓事情變成這樣？", liuyu_speaker_id, liuyu_portrait_path),
		_l("不是。", shumian_speaker_id, shumian_portrait_path),
		_l("你只是剛好推了最後一把。", shumian_speaker_id, shumian_portrait_path),
		_l("這裡本來就已經快撐不住了。", shumian_speaker_id, shumian_portrait_path),
		_n("水面下方忽然傳來劇烈震動。"),
		_l("小心，水下有東西！", shumian_speaker_id, shumian_portrait_path),
		_n("一尾受濁氣侵染的巨鯉破水而出，鱗甲翻黑，手中竟握著鏽蝕魚叉。"),
		_l("書眠姑娘，當心！", liuyu_speaker_id, liuyu_portrait_path),
		_l("劉少俠，我沒問題。", shumian_speaker_id, shumian_portrait_path),
		_n("她袖中筆鋒一轉，衣袂微揚，竟已擺出迎敵架勢。"),
		_n("劉語塵微微一怔，隨即握劍。"),
		_l("嗯。", liuyu_speaker_id, liuyu_portrait_path),
		_l("一起上。", liuyu_speaker_id, liuyu_portrait_path),
	]


# ------------------------------------------------------------
# BOSS 戰準備與啟動
# ------------------------------------------------------------
func get_fish_boss_battle_config() -> Dictionary:
	var player_party: Array = []
	if TeamData and TeamData.has_method("get_story_battle_party_for_actor_ids"):
		player_party = TeamData.get_story_battle_party_for_actor_ids(SPECIAL_BATTLE_PARTY_IDS)
	elif TeamData and TeamData.has_method("get_party_for_actor_ids"):
		player_party = TeamData.get_party_for_actor_ids(SPECIAL_BATTLE_PARTY_IDS)
	var enemy_party: Array = []
	var boss := EnemyDBScript.make_enemy(fish_boss_enemy_id)
	if not boss.is_empty():
		boss["ui_index"] = 0
		enemy_party.append(boss)
	return {
		"battle_id": fish_boss_battle_id,
		"enemy_id": fish_boss_enemy_id,
		"party": SPECIAL_BATTLE_PARTY_IDS.duplicate(),
		"party_actor_ids_override": SPECIAL_BATTLE_PARTY_IDS.duplicate(),
		"full_resource_deployment_actor_ids": ["shumian"],
		"use_story_battle_profile": true,
		"story_battle_profile_id": BattlePhaseProfileDBScript.YUHENG_SHUMIAN_STORY_PROFILE_ID,
		"player_party": player_party,
		"enemy_party": enemy_party,
		"ruleset": {"id": "default"},
		"regen_policy": {"id": "round_end_mp_regen_default"},
		"tone": {"intro_key": fish_boss_battle_id},
		"battle_tag": fish_boss_battle_id,
		"battle_bgm_override_path": PHASE1_BGM_PATH,
		"scripted_phase_break": PHASE_BREAK_KEY,
		"no_rewards": true,
		# Keep the authored Phase 1 zero-EXP/zero-drop contract from being
		# replaced by the generic enemy EXP fallback.
		"use_exact_enemy_rewards": true,
		"zone_id": "yuheng_stalactite_cave",
		"map_id": CAVE_SCENE_PATH,
		"scene_name": String(name),
		"reward_recipient_actor_ids": SPECIAL_BATTLE_PARTY_IDS.duplicate(),
		"post_battle_companion_insight_source_actor_ids": \
			SPECIAL_BATTLE_INSIGHT_SOURCE_IDS.duplicate(),
	}


func prepare_battle_return_actor(player: Node2D) -> void:
	if _phase2_victory_cutscene_active:
		_stage_liuyu_for_phase2_victory(player)
		return
	if not _is_phase_break_result(GlobalState.get_meta("pending_battle_result", {})):
		return
	story_locked = true
	player.visible = true
	player.set("can_move", false)
	player.set("override_idle_animation", true)
	_prepare_phase_transition_stage(player)


func _prime_phase_transition_black() -> void:
	if overlay == null:
		return
	overlay.visible = true
	overlay.modulate.a = 1.0


func _prepare_phase_transition_stage(player: Node2D) -> Node2D:
	var liuyu_marker := get_node_or_null("SpawnPoints/Liu_yu_fight_scene") as Marker2D
	var shumian_marker := get_node_or_null("SpawnPoints/Su_mien_fight_scene") as Marker2D
	var boss_marker := get_node_or_null("SpawnPoints/molingyanjiana_fight") as Marker2D
	if player:
		player.visible = true
		player.set("can_move", false)
		player.set("override_idle_animation", true)
		if liuyu_marker:
			player.global_position = liuyu_marker.global_position
		_set_phase_transition_initial_shadow(player)
		_play_actor_animation(player, &"ready_fight_right_down", true)
	if shumian_npc:
		if shumian_marker:
			shumian_npc.global_position = shumian_marker.global_position
		shumian_npc.visible = true
		_play_actor_animation(shumian_npc, &"ready_for_fight_right_down", true)
	if not is_instance_valid(_phase_transition_boss):
		_phase_transition_boss = MolinYanjiangScene.instantiate() as Node2D
		if _phase_transition_boss:
			get_node("NPC").add_child(_phase_transition_boss)
	if _phase_transition_boss:
		if boss_marker:
			_phase_transition_boss.global_position = boss_marker.global_position
		_phase_transition_boss.scale = Vector2.ONE * PHASE_TRANSITION_BOSS_SCALE
		_phase_transition_boss.visible = true
		_ensure_actor_atlas_animation(
			_phase_transition_boss,
			&"phase2_parry_left_down",
			MolinPhase2ParryTexture,
			Vector2i(4, 2),
			18.0,
			false
		)
		_play_actor_animation(
			_phase_transition_boss,
			&"phase1_defeated_half_kneel_left_down",
			true
		)
	return _phase_transition_boss


func _set_phase_transition_initial_shadow(player: Node2D) -> void:
	var shadow := _get_actor_shadow(player)
	if shadow == null:
		return
	if not shadow.has_meta("phase_transition_shadow_base_position"):
		shadow.set_meta("phase_transition_shadow_base_position", shadow.position)
	var base_position := Vector2(shadow.get_meta("phase_transition_shadow_base_position"))
	shadow.position = base_position + LIUYU_PHASE_TRANSITION_SHADOW_OFFSET


func _clear_phase_transition_initial_shadow(player: Node2D) -> void:
	var shadow := _get_actor_shadow(player)
	if shadow == null or not shadow.has_meta("phase_transition_shadow_base_position"):
		return
	shadow.position = Vector2(shadow.get_meta("phase_transition_shadow_base_position"))


func _is_phase_break_result(result_any) -> bool:
	if typeof(result_any) != TYPE_DICTIONARY:
		return false
	var result: Dictionary = result_any
	return String(result.get("result", "")) == "phase_break" \
		and String(result.get("scripted_phase_break", "")) == PHASE_BREAK_KEY


func _is_phase2_victory_result(result_any) -> bool:
	if typeof(result_any) != TYPE_DICTIONARY:
		return false
	var result: Dictionary = result_any
	return String(result.get("result", "")) == "victory" \
		and String(result.get("battle_id", "")) == PHASE2_BATTLE_ID


func _play_phase_transition_and_start_phase2() -> void:
	var player := _get_player()
	if player == null:
		push_warning("鐘乳石洞 Phase Break 回場時找不到劉語塵，無法接續第二階段。")
		return
	_set_player_movable(false)
	player.set("override_idle_animation", true)
	_disable_event_trigger()

	var boss := _prepare_phase_transition_stage(player)
	if boss == null:
		push_warning("無法建立墨鱗魘將場景，略過地圖演出並接續第二階段戰鬥。")
		await _start_fish_boss_phase2_battle()
		return
	await _show_dialog([
		_l("我們贏了？", liuyu_speaker_id, liuyu_portrait_path),
		_n("墨鱗魘將伏在水邊，喉間忽然擠出低沉笑聲。"),
		_l("哈……哈哈……", boss_speaker_id, boss_phase1_portrait_path),
		_l("別小看我啊！猴子們！", boss_speaker_id, boss_phase1_portrait_path),
	])
	_phase_absorption_fx = _start_yumei_absorption_fx(boss)
	await _show_dialog([
		_n("四周殘存的語魅濁氣驟然倒捲，盡數湧向墨鱗魘將。"),
		_l("！？", liuyu_speaker_id, liuyu_portrait_path),
		_l("！？", shumian_speaker_id, shumian_portrait_path),
	])
	await get_tree().create_timer(0.35).timeout
	await _flash_phase_transition()
	_stop_yumei_absorption_fx()
	_start_boss_transformation_whitening(boss, &"phase2_transformation")
	await _play_finite_actor_animation(boss, &"phase2_transformation")
	await _fade_out_boss_transformation_whitening()
	_play_actor_animation(boss, &"phase2_idle_left_down", true)
	await _show_dialog([
		_l("這是！？", liuyu_speaker_id, liuyu_portrait_path),
		_n("一股刺骨的寒意猛然滲入筋骨，你幾乎是在本能間便明白——不能再放任眼前這頭怪物繼續壯大。"),
		_l("不妙！！", liuyu_speaker_id, liuyu_portrait_path),
		_n("你倏然定下目光，握住劍柄的手反而收得更緊、更穩。"),
		_n("雙膝微屈，下一瞬，已準備縱身迎上。"),
	])

	# 先讓劉語塵單獨完成躍進；這段期間 Boss 保持原地，讓玩家看清楚
	# 劉語塵已經抓到距離，而不是一開始就像雙方同時位移。
	var liuyu_jump_duration: float = _start_actor_animation_once_and_hold(
		player,
		&"toward_hop_right_down",
		PHASE_PATH_1_DURATION,
		2.0
	)
	_clear_phase_transition_initial_shadow(player)
	await _move_actor_along_phase_path(
		player,
		^"Liu_yu_path/1_jump_to_attack",
		liuyu_jump_duration,
		true
	)

	# 劉語塵抵達斬擊位置、真正揮劍的同一刻，才觸發 Boss 最後一刻閃避。
	# Dodge 只播放已校準的二階 idle；BossRoot 整體沿 Path 位移，播放完
	# 停在末幀並維持到對白結束，再由後續反擊動畫接管。
	var liuyu_attack_duration: float = _start_actor_animation_once_and_hold(
		player,
		&"sword_attack_right_down",
		PHASE_PATH_2_DURATION,
		LIUYU_ATTACK_SPEED_SCALE
	)
	var boss_dodge_duration: float = _start_actor_animation_once_and_hold(
		boss,
		&"phase2_idle_left_down",
		PHASE_PATH_2_DURATION,
		BOSS_DODGE_SPEED_SCALE
	)
	await _move_actor_along_phase_path(
		boss,
		^"Molingyanjiang_path/2_dodge_attack",
		boss_dodge_duration
	)
	var remaining_strike_time: float = liuyu_attack_duration - boss_dodge_duration
	if remaining_strike_time > 0.0:
		await get_tree().create_timer(remaining_strike_time).timeout
	await _show_dialog([
		_l("太慢了！！", boss_speaker_id, boss_phase2_portrait_path),
		_l("！？", liuyu_speaker_id, liuyu_portrait_path),
	])
	_restore_actor_shadow(player)

	# Boss 反擊與劉語塵後跳同步；動作完成後才輪到書眠出聲。
	var boss_counter_duration: float = _start_actor_animation_once_and_hold(
		boss,
		&"phase2_attack_left_down",
		PHASE_PATH_3_DURATION,
		BOSS_COUNTER_SPEED_SCALE
	)
	var liuyu_dodge_duration: float = _start_actor_animation_once_and_hold(
		player,
		&"backward_hop_right_down",
		PHASE_PATH_3_DURATION,
		LIUYU_BACKWARD_DODGE_SPEED_SCALE
	)
	await _move_two_actors_along_phase_paths(
		player,
		^"Liu_yu_path/3_jump_backward",
		liuyu_dodge_duration,
		boss,
		^"Molingyanjiang_path/3_attack_liuyu",
		boss_counter_duration
	)
	await _show_dialog([_l("還沒呢！", shumian_speaker_id, shumian_portrait_path)])

	# 書眠先切入指定位置；抵達後才真正出手，Boss 也在同一刻格擋。
	await _move_actor_along_phase_path(
		shumian_npc,
		^"Su_mien_path/4_su_mien_attack",
		PHASE_PATH_4_DURATION
	)
	var shumian_attack_duration: float = _start_actor_animation_once_and_hold(
		shumian_npc,
		&"brush_attack_right_down",
		PHASE_PATH_4_DURATION
	)
	var boss_guard_duration: float = _start_actor_animation_once_and_hold(
		boss,
		&"phase2_guard_left_down",
		PHASE_PATH_4_DURATION
	)
	_start_boss_guard_impact_pulses(boss, &"phase2_guard_left_down")
	await get_tree().create_timer(maxf(shumian_attack_duration, boss_guard_duration)).timeout
	await _show_dialog([_l("沒用的！", boss_speaker_id, boss_phase2_portrait_path)])

	# Boss 攻擊與書眠受擊計時在同一時間點啟動；0.3 秒是由攻擊起手
	# 對齊實際命中幀的 offset，不等待 Boss 播完整套攻擊。
	_start_actor_animation_once_and_hold(
		boss,
		&"phase2_attack_left_down",
		PHASE_PATH_5_DURATION,
		BOSS_COUNTER_SPEED_SCALE
	)
	await get_tree().create_timer(SU_MIEN_HIT_IMPACT_PAUSE_SECONDS).timeout

	# 命中停頓後才播放被打飛／失衡，再接完整倒地動畫。
	var shumian_falling_duration: float = _start_actor_animation_once_and_hold(
		shumian_npc,
		&"hit_falling_right_down",
		PHASE_PATH_5_DURATION
	)
	await _move_actor_along_phase_path(
		shumian_npc,
		^"Su_mien_path/5_hit_fall",
		shumian_falling_duration,
		false,
		Tween.EASE_OUT
	)
	await _play_finite_actor_animation(shumian_npc, &"hit_fall_right_down")
	await _show_dialog([_l("書眠!!", liuyu_speaker_id, liuyu_portrait_path)])

	# 劉語塵喊完後，以略放慢的奔跑節奏趕到書眠身旁再完成攙扶。
	_play_actor_animation(player, &"running_right")
	await _move_actor_along_phase_path(
		player,
		^"Liu_yu_path/6_help_su_mien",
		PHASE_PATH_6_DURATION / HELP_RUN_SPEED_SCALE
	)
	await _play_finite_actor_animation(player, &"drop_sword_and_help")
	await _show_dialog([_l("妳沒事吧！？", liuyu_speaker_id, liuyu_portrait_path)])

	await _play_finite_actor_animation(shumian_npc, &"hit_fall_see_back_right_down")
	await _show_dialog([
		_l("語塵……我沒事。", shumian_speaker_id, shumian_portrait_path),
		_l("只是那魚怪身上的氣息……不對勁。", shumian_speaker_id, shumian_portrait_path),
	])
	await get_tree().create_timer(0.35).timeout
	await _show_dialog([
		_l("我也感覺到了。", liuyu_speaker_id, liuyu_portrait_path),
		_l("方才牠吸納四周邪祟之氣後，身法陡然暴增，周身也像覆上了一層護體邪氣……", liuyu_speaker_id, liuyu_portrait_path),
		_l("尋常刀兵，恐怕已經傷不了牠。", liuyu_speaker_id, liuyu_portrait_path),
	])
	await _show_dialog([
		_l("哈哈哈！！方才不是還挺得意的嗎？", boss_speaker_id, boss_phase2_portrait_path),
		_l("怎麼？如今反倒輪到我把你們逼入絕境了！！", boss_speaker_id, boss_phase2_portrait_path),
	])
	await _play_finite_actor_animation(shumian_npc, &"hit_fall_see_through_right_down")

	# 書眠重新看向敵人後，劉語塵先由攙扶姿勢提劍站起，
	# 再進入持續迎敵的備戰待機，不直接瞬切拔劍姿勢。
	_ensure_reversed_actor_animation(
		player,
		&"take_sword_and_stand_right",
		&"drop_sword_and_help"
	)
	await _play_finite_actor_animation(player, &"take_sword_and_stand_right")
	_play_actor_animation(player, &"ready_fight_idle_right_down")
	await get_tree().create_timer(0.45).timeout
	await _show_dialog([
		_n("眼看眼前這名吸納了語魅之氣、再度捲土重來的強敵，你心底不由一沉，焦灼與徬徨也隨之漫了上來。"),
		_l("可惡……難道，真要到此為止了嗎……", liuyu_speaker_id, liuyu_portrait_path),
	])

	await _show_dialog([
		_n("此時，你忽然察覺遠處似乎傳來一陣異樣的動靜……"),
		_n("那聲響由遠而近，正以極快的速度朝此處逼來。"),
		_l("???：「書眠！！」", narration_speaker_id, empty_portrait_path),
	])
	await _move_zuoyin_along_existing_path()
	await _show_dialog([
		_n("你看見白書眠怔怔望著眼前突然闖入的紅衣男子，神色一瞬間失了平日的從容。"),
		_n("她像是還不敢相信自己的眼睛，嘴唇微張，隔了半晌，才有些斷續地喚出那個名字。"),
		_l("左……左飲？", shumian_speaker_id, shumian_portrait_path),
		_n("白書眠輕吸了一口氣，像是將方才的驚訝重新吞回胸口。"),
		_n("她很快穩住語氣，轉向你，聲音也重新恢復了平緩。"),
		_l("劉少俠……這位，就是左飲。", shumian_speaker_id, shumian_portrait_path),
		_l("!!", liuyu_speaker_id, liuyu_portrait_path),
		_l("……原來，你就是飲月山莊的左大俠。", liuyu_speaker_id, liuyu_portrait_path),
	])
	await _show_dialog([_n("左飲短暫看過白書眠、劉語塵與墨鱗魘將，隨即辨明了眼前的戰況。")])
	await _show_dialog([
		_l("……", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_l("原來如此。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_l("徽音的琴，根本沒把那些情緒消掉。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_l("只是暫時壓了下去。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_l("白日裡壓得再平，到了夜裡……那些情緒還是會從夢裡翻上來。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_n("左飲的目光落向洞窟深處，那些沿著石縫淌過的污濁水痕。"),
		_l("夢醒了，人總要洗臉、漱口。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_l("那些沒散乾淨的殘響，也就跟著水……一路流到這裡。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_l("所以，才養成了這副模樣麼……", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_l("……你們兩個，就一直在跟這東西纏鬥？", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_l("行了。剩下的，算我一份。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_l("又來一隻猴子？", boss_speaker_id, boss_phase2_portrait_path),
		_l("管你是誰——今日一個也別想活著出去！！", boss_speaker_id, boss_phase2_portrait_path),
	])
	await _play_finite_actor_animation(zuoyin_npc, &"unsheathe_right")
	await _show_dialog([
		_n("左飲才剛將手中的刀拔出鞘，銀白刀身便忽地微微震顫起來，彷彿正與墨鱗魘將周身翻湧的語魅之氣彼此呼應。"),
		_n("下一瞬，銀白刀身驟然泛起幽紫光芒，一縷不祥的邪氣隨之自刃上逸散而出。"),
	])
	await _play_finite_actor_animation(zuoyin_npc, &"post_draw_sword_resonance_right")
	await _show_dialog([
		_n("你與白書眠不約而同地望向左飲手中的那柄怪刀。"),
		_n("銀白刀身之上，紫黑色的氣焰正一縷縷向外翻湧。那並非徒有其表的光影——邪氣掠過之處，連刀鞘的邊緣都漸漸焦黑，傳來細微的龜裂聲。"),
		_n("彷彿只要再靠近一些，連有形之物都會被那股陰冷而躁烈的氣息一併吞沒。"),
		_l("星痕逆紋刃……你也覺得這股邪氣嗆得很，是吧？", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_l("唉，好不容易才替你尋到一副合適的刀鞘。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_n("墨鱗魘將死死盯著那抹紫黑刀光，原本張狂的神色忽然一滯。"),
		_n("那股邪氣彷彿越過牠滿身鱗甲，直直映入體內翻湧的惡念；一瞬之間，牠竟像是被什麼看穿了似的，連氣息都亂了一拍。"),
		_n("牠猛地甩了甩頭，又重重眨了幾下眼，像是急著將方才那一瞬的動搖甩出腦海。"),
		_n("待牠再抬起頭時，聲音反倒比先前更加粗暴躁怒。"),
		_l("你們這群只會耍猴戲的傢伙，真是看了就煩！！", boss_speaker_id, boss_phase2_portrait_path),
		_l("尤其是你！拿著那把怪刀的傢伙！！", boss_speaker_id, boss_phase2_portrait_path),
		_l("啊啊！！煩死了！！看我怎麼收拾你們！！", boss_speaker_id, boss_phase2_portrait_path),
		_l("……看來，你果然認得這股氣息。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_l("那就好辦了。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_n("左飲沉下聲來，渾厚的嗓音壓過洞中紛亂的回響，清楚地傳入你與白書眠耳中。"),
		_l("劉少俠，書眠。待會兒我來牽制牠，剩下的，就交給你們了。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
	])
	await _play_finite_actor_animation(shumian_npc, &"get_stand_up_right_down")
	var synchronized_lines: Array = [
		_l("劉語塵：「行。」", liuyu_speaker_id, liuyu_portrait_path),
		_l("白書眠：「沒問題。」", shumian_speaker_id, shumian_portrait_path),
	]
	synchronized_lines[0]["dialog_lane"] = 2
	synchronized_lines[1]["dialog_lane"] = 1
	await _show_synchronized_dialog(synchronized_lines)
	_set_flag(F_FISH_BOSS_PHASE2, true)
	_set_flag(F_ZUOYIN_GUEST_JOINED, true)
	await _start_fish_boss_phase2_battle()


func _start_fish_boss_phase2_battle() -> void:
	var player_party: Array = []
	if TeamData and TeamData.has_method("get_story_battle_party_for_actor_ids"):
		player_party = TeamData.get_story_battle_party_for_actor_ids(SPECIAL_BATTLE_PARTY_IDS)
	elif TeamData and TeamData.has_method("get_party_for_actor_ids"):
		player_party = TeamData.get_party_for_actor_ids(SPECIAL_BATTLE_PARTY_IDS)
	var carried_any = GlobalState.get_meta("stalactite_phase1_player_resources", {})
	var config: Dictionary = BattlePhaseProfileDBScript.make_molin_phase2_context(player_party, {
		"zone_id": "yuheng_stalactite_cave",
		"map_id": CAVE_SCENE_PATH,
		"scene_name": String(name),
		"return_map_path": CAVE_SCENE_PATH,
		"reward_recipient_actor_ids": SPECIAL_BATTLE_PARTY_IDS.duplicate(),
		"post_battle_companion_insight_source_actor_ids": \
			SPECIAL_BATTLE_INSIGHT_SOURCE_IDS.duplicate(),
	})
	if typeof(carried_any) == TYPE_DICTIONARY:
		# Clamp carried HP/MP only after BattleController rebuilds the Phase II
		# equipment-integrated baseline; canonical resource maxima are lower.
		config["initial_player_resources"] = (carried_any as Dictionary).duplicate(true)
	GlobalState.remove_meta("stalactite_phase1_player_resources")
	await _start_battle_with_config(config)


func _start_battle_with_config(config: Dictionary) -> void:
	var player := _get_player()
	var game_root := get_node_or_null("/root/GameRoot")
	if player == null or game_root == null or (config.get("enemy_party", []) as Array).is_empty():
		push_warning("鐘乳石洞戰鬥 context 不完整，無法開始戰鬥。")
		return
	var enemies: Array = config.get("enemy_party", [])
	if player.has_method("_resolve_encounter_transition_style"):
		config["encounter_transition_style"] = player.call("_resolve_encounter_transition_style", enemies)
	GlobalState.set_meta("return_map_path", CAVE_SCENE_PATH)
	GlobalState.set_meta("return_player_pos", player.global_position)
	GlobalState.set_meta("return_encounter_cooldown", 0.0)
	GlobalState.set_meta("pending_battle_context", config)
	if game_root.has_method("pause_world_bgm_for_battle"):
		game_root.call("pause_world_bgm_for_battle")
	if player.has_method("lock_for_battle"):
		player.call("lock_for_battle")
	if player.has_method("_play_encounter_transition"):
		await player.call("_play_encounter_transition", config.get("encounter_transition_style", {}))
	player.visible = false
	game_root.call("change_map_to", BATTLE_SCENE_PATH)


func _flash_phase_transition() -> void:
	if overlay == null:
		return
	var original_color := overlay.color
	overlay.color = Color.WHITE
	overlay.visible = true
	overlay.modulate.a = 0.0
	var tween := overlay.create_tween()
	tween.tween_property(overlay, "modulate:a", 0.9, 0.08)
	tween.tween_property(overlay, "modulate:a", 0.0, 0.18)
	await tween.finished
	overlay.color = original_color


func _start_yumei_absorption_fx(boss: Node2D) -> Node2D:
	_stop_yumei_absorption_fx()
	if boss == null or YumeiElementScene == null:
		return null
	_start_boss_absorption_color_cycle(boss)
	var holder := Node2D.new()
	holder.name = "YumeiAbsorptionFX"
	holder.z_index = 40
	add_child(holder)
	holder.global_position = Vector2.ZERO
	_start_inward_yumei_particles(holder, boss)
	_run_yumei_element_stream(holder, boss)
	return holder


func _start_boss_absorption_color_cycle(boss: Node2D) -> void:
	_restore_boss_absorption_color()
	if not is_instance_valid(boss):
		return
	var sprite := boss.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return
	_boss_absorption_sprite = sprite
	_boss_absorption_base_modulate = sprite.modulate
	var alpha: float = _boss_absorption_base_modulate.a
	var saturated_white := Color(1.0, 1.0, 1.0, alpha)
	var yumei_purple := Color(0.62, 0.30, 0.86, alpha)
	var corrupted_black := Color(0.20, 0.10, 0.25, alpha)
	_boss_absorption_color_tween = sprite.create_tween()
	_boss_absorption_color_tween.set_loops()
	_boss_absorption_color_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_boss_absorption_color_tween.tween_property(
		sprite, "modulate", saturated_white, BOSS_ABSORPTION_COLOR_STEP_SECONDS
	)
	_boss_absorption_color_tween.tween_property(
		sprite, "modulate", yumei_purple, BOSS_ABSORPTION_COLOR_STEP_SECONDS
	)
	_boss_absorption_color_tween.tween_property(
		sprite, "modulate", corrupted_black, BOSS_ABSORPTION_COLOR_STEP_SECONDS
	)
	_boss_absorption_color_tween.tween_property(
		sprite, "modulate", yumei_purple, BOSS_ABSORPTION_COLOR_STEP_SECONDS
	)


func _start_boss_transformation_whitening(
	boss: Node2D,
	animation_name: StringName
) -> void:
	if _boss_absorption_color_tween and _boss_absorption_color_tween.is_valid():
		_boss_absorption_color_tween.kill()
	_boss_absorption_color_tween = null
	var sprite := _boss_absorption_sprite
	if not is_instance_valid(sprite) and is_instance_valid(boss):
		sprite = boss.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return
	_boss_absorption_sprite = sprite
	_boss_absorption_base_material = sprite.material
	# Transformation 的第一個可見 frame 必須是原色；不要讓吸收階段的
	# 白／紫／黑 modulate 循環殘留到白化動畫裡。
	sprite.modulate = _boss_absorption_base_modulate
	var white_shader := Shader.new()
	white_shader.code = BOSS_TRANSFORMATION_WHITE_SHADER
	var white_material := ShaderMaterial.new()
	white_material.shader = white_shader
	white_material.set_shader_parameter("white_amount", 0.0)
	sprite.material = white_material
	var transformation_duration: float = 1.0
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(animation_name):
		var frame_count: int = sprite.sprite_frames.get_frame_count(animation_name)
		var animation_fps: float = sprite.sprite_frames.get_animation_speed(animation_name) \
			* absf(sprite.speed_scale)
		transformation_duration = float(frame_count) / maxf(animation_fps, 0.01)
	_boss_absorption_color_tween = sprite.create_tween()
	_boss_absorption_color_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_boss_absorption_color_tween.tween_method(
		func(white_amount: float) -> void:
			if is_instance_valid(white_material):
				white_material.set_shader_parameter("white_amount", white_amount)
	, 0.0, 1.0, transformation_duration
	)


func _fade_out_boss_transformation_whitening() -> void:
	if _boss_absorption_color_tween and _boss_absorption_color_tween.is_valid():
		_boss_absorption_color_tween.kill()
	_boss_absorption_color_tween = null
	if not is_instance_valid(_boss_absorption_sprite):
		_restore_boss_absorption_color()
		return
	var white_material := _boss_absorption_sprite.material as ShaderMaterial
	if white_material == null:
		_restore_boss_absorption_color()
		return
	# 動畫最後一幀保持最白，結束後才以獨立 Tween 快速、連續退白。
	white_material.set_shader_parameter("white_amount", 1.0)
	_boss_absorption_color_tween = _boss_absorption_sprite.create_tween()
	_boss_absorption_color_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_boss_absorption_color_tween.tween_method(
		func(white_amount: float) -> void:
			if is_instance_valid(white_material):
				white_material.set_shader_parameter("white_amount", white_amount)
	, 1.0, 0.0, BOSS_TRANSFORMATION_WHITE_FADE_OUT_SECONDS
	)
	await _boss_absorption_color_tween.finished
	_restore_boss_absorption_color()


func _restore_boss_absorption_color() -> void:
	if _boss_absorption_color_tween and _boss_absorption_color_tween.is_valid():
		_boss_absorption_color_tween.kill()
	_boss_absorption_color_tween = null
	if is_instance_valid(_boss_absorption_sprite):
		_boss_absorption_sprite.modulate = _boss_absorption_base_modulate
		_boss_absorption_sprite.material = _boss_absorption_base_material
	_boss_absorption_sprite = null
	_boss_absorption_base_material = null


func _start_boss_guard_impact_pulses(boss: Node2D, animation_name: StringName) -> void:
	if _boss_guard_pulse_tween and _boss_guard_pulse_tween.is_valid():
		_boss_guard_pulse_tween.kill()
	_boss_guard_pulse_tween = null
	if not is_instance_valid(boss):
		return
	var sprite := boss.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null \
			or not sprite.sprite_frames.has_animation(animation_name):
		return
	if sprite.sprite_frames.get_frame_count(animation_name) < 3:
		return
	var animation_fps: float = sprite.sprite_frames.get_animation_speed(animation_name) \
		* absf(sprite.speed_scale)
	var frame_interval: float = 1.0 / maxf(animation_fps, 0.01)
	var pulse_duration: float = BOSS_GUARD_PULSE_STEP_SECONDS * 4.0
	var between_pulses: float = maxf(frame_interval - pulse_duration, 0.0)
	var base_position: Vector2 = boss.position
	var left_impact := base_position + Vector2(-BOSS_GUARD_PULSE_DISTANCE, -1.5)
	var right_recoil := base_position + Vector2(BOSS_GUARD_PULSE_DISTANCE, 1.5)
	_boss_guard_pulse_tween = boss.create_tween()
	_boss_guard_pulse_tween.tween_interval(frame_interval)
	_boss_guard_pulse_tween.tween_property(
		boss, "position", left_impact, BOSS_GUARD_PULSE_STEP_SECONDS
	)
	_boss_guard_pulse_tween.tween_property(
		boss, "position", right_recoil, BOSS_GUARD_PULSE_STEP_SECONDS
	)
	_boss_guard_pulse_tween.tween_property(
		boss, "position", left_impact, BOSS_GUARD_PULSE_STEP_SECONDS
	)
	_boss_guard_pulse_tween.tween_property(
		boss, "position", base_position, BOSS_GUARD_PULSE_STEP_SECONDS
	)
	_boss_guard_pulse_tween.tween_interval(between_pulses)
	_boss_guard_pulse_tween.tween_property(
		boss, "position", right_recoil, BOSS_GUARD_PULSE_STEP_SECONDS
	)
	_boss_guard_pulse_tween.tween_property(
		boss, "position", left_impact, BOSS_GUARD_PULSE_STEP_SECONDS
	)
	_boss_guard_pulse_tween.tween_property(
		boss, "position", right_recoil, BOSS_GUARD_PULSE_STEP_SECONDS
	)
	_boss_guard_pulse_tween.tween_property(
		boss, "position", base_position, BOSS_GUARD_PULSE_STEP_SECONDS
	)


func _run_yumei_element_stream(holder: Node2D, boss: Node2D) -> void:
	var wave_index := 0
	while is_instance_valid(holder) and holder.is_inside_tree() and is_instance_valid(boss):
		for stream_index in range(YUMEI_ELEMENTS_PER_WAVE):
			var direction_index := (stream_index * 2 + wave_index % 2) \
				% YUMEI_ABSORPTION_DIRECTIONS
			_launch_yumei_element(holder, boss, direction_index, wave_index)
		wave_index += 1
		await get_tree().create_timer(YUMEI_ABSORPTION_WAVE_INTERVAL).timeout


func _launch_yumei_element(
	holder: Node2D,
	boss: Node2D,
	direction_index: int,
	wave_index: int
) -> void:
	if not is_instance_valid(holder) or not is_instance_valid(boss):
		return
	var element := YumeiElementScene.instantiate() as AnimatedSprite2D
	if element == null:
		return
	holder.add_child(element)
	var target := boss.global_position + YUMEI_ABSORPTION_TARGET_OFFSET
	var angle := TAU * float(direction_index) / float(YUMEI_ABSORPTION_DIRECTIONS)
	angle += float(wave_index % 3 - 1) * 0.055
	var radial_offset := Vector2(
		cos(angle) * YUMEI_ABSORPTION_RADIUS_X,
		sin(angle) * YUMEI_ABSORPTION_RADIUS_Y
	)
	element.global_position = target + radial_offset
	var travel_direction: Vector2 = (target - element.global_position).normalized()
	# yumei_element 的原圖朝右；依每顆氣團實際飛行方向旋轉。
	element.rotation = travel_direction.angle()
	element.z_index = 41
	element.scale = Vector2.ONE * (0.13 + 0.015 * float((direction_index + wave_index) % 3))
	element.modulate = Color(0.72, 0.42, 0.94, 0.0)
	element.play(&"small_air_particle")
	var travel_duration := 0.82 + 0.06 * float((direction_index + wave_index) % 4)
	var tween := element.create_tween()
	tween.set_parallel(true)
	tween.tween_property(element, "global_position", target, travel_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(element, "modulate:a", 1.0, travel_duration * 0.72) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(element, "scale", Vector2.ONE * 0.055, travel_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		if is_instance_valid(holder) and holder.is_inside_tree():
			_emit_yumei_impact_splash(holder, target)
		if is_instance_valid(element):
			element.queue_free()
	, CONNECT_ONE_SHOT)


func _start_inward_yumei_particles(holder: Node2D, boss: Node2D) -> void:
	var target := boss.global_position + YUMEI_ABSORPTION_TARGET_OFFSET
	var particle_texture := _get_yumei_particle_texture()
	for direction_index in range(YUMEI_ABSORPTION_DIRECTIONS):
		var angle := TAU * float(direction_index) / float(YUMEI_ABSORPTION_DIRECTIONS)
		var radial_offset := Vector2(
			cos(angle) * YUMEI_ABSORPTION_RADIUS_X,
			sin(angle) * YUMEI_ABSORPTION_RADIUS_Y
		)
		var emitter_position := target + radial_offset
		var distance_to_boss := emitter_position.distance_to(target)
		var particles := CPUParticles2D.new()
		particles.name = "InwardParticles%d" % (direction_index + 1)
		particles.z_index = 38
		particles.amount = 7
		particles.lifetime = 0.9
		particles.preprocess = 0.9
		particles.randomness = 0.34
		particles.direction = (target - emitter_position).normalized()
		particles.spread = 11.0
		particles.gravity = Vector2.ZERO
		particles.initial_velocity_min = distance_to_boss / particles.lifetime * 0.88
		particles.initial_velocity_max = distance_to_boss / particles.lifetime * 1.08
		particles.scale_amount_min = 0.65
		particles.scale_amount_max = 1.25
		particles.color = Color(0.28, 0.035, 0.38, 0.82)
		particles.texture = particle_texture
		holder.add_child(particles)
		particles.global_position = emitter_position
		particles.emitting = true


func _emit_yumei_impact_splash(holder: Node2D, impact_position: Vector2) -> void:
	if not is_instance_valid(holder):
		return
	var splash := CPUParticles2D.new()
	splash.name = "YumeiImpactSplash"
	splash.z_index = 42
	splash.amount = 4
	splash.lifetime = 0.24
	splash.one_shot = true
	splash.explosiveness = 1.0
	splash.randomness = 0.7
	splash.direction = Vector2.UP
	splash.spread = 180.0
	splash.gravity = Vector2(0.0, 18.0)
	splash.initial_velocity_min = 24.0
	splash.initial_velocity_max = 48.0
	splash.scale_amount_min = 0.5
	splash.scale_amount_max = 1.05
	splash.color = Color(0.48, 0.08, 0.62, 0.9)
	splash.texture = _get_yumei_particle_texture()
	holder.add_child(splash)
	splash.global_position = impact_position
	splash.finished.connect(splash.queue_free, CONNECT_ONE_SHOT)
	splash.emitting = true


func _get_yumei_particle_texture() -> Texture2D:
	if _yumei_particle_texture:
		return _yumei_particle_texture
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.52, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.86, 0.42, 1.0, 1.0),
		Color(0.33, 0.03, 0.48, 0.9),
		Color(0.05, 0.0, 0.08, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.width = 10
	texture.height = 10
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	_yumei_particle_texture = texture
	return _yumei_particle_texture


func _stop_yumei_absorption_fx() -> void:
	if not is_instance_valid(_phase_absorption_fx):
		_phase_absorption_fx = null
		return
	_phase_absorption_fx.queue_free()
	_phase_absorption_fx = null


func _play_finite_actor_animation(actor: Node, animation_name: StringName) -> void:
	var sprite: AnimatedSprite2D = null
	if actor:
		sprite = actor.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation_name):
		return
	sprite.play(animation_name)
	var frame_count := sprite.sprite_frames.get_frame_count(animation_name)
	var speed := sprite.sprite_frames.get_animation_speed(animation_name)
	await get_tree().create_timer(float(frame_count) / maxf(speed, 0.01)).timeout
	sprite.pause()
	if frame_count > 0:
		sprite.set_frame_and_progress(frame_count - 1, 1.0)


func _start_actor_animation_once_and_hold(
	actor: Node,
	animation_name: StringName,
	fallback_duration: float,
	animation_speed_scale: float = 1.0
) -> float:
	var resolved_speed_scale: float = maxf(animation_speed_scale, 0.01)
	var sprite: AnimatedSprite2D = null
	if actor:
		sprite = actor.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation_name):
		return fallback_duration / resolved_speed_scale
	var previous_speed_scale: float = sprite.speed_scale
	sprite.play(animation_name)
	sprite.speed_scale = previous_speed_scale * resolved_speed_scale
	var frame_count: int = sprite.sprite_frames.get_frame_count(animation_name)
	var animation_speed: float = sprite.sprite_frames.get_animation_speed(animation_name)
	var duration: float = float(frame_count) / maxf(animation_speed * sprite.speed_scale, 0.01)
	var hold_tween: Tween = sprite.create_tween()
	hold_tween.tween_interval(duration)
	hold_tween.tween_callback(func() -> void:
		if not is_instance_valid(sprite):
			return
		sprite.speed_scale = previous_speed_scale
		if sprite.animation != animation_name:
			return
		sprite.pause()
		if frame_count > 0:
			sprite.set_frame_and_progress(frame_count - 1, 1.0)
	)
	return duration


func _play_actor_animation(actor: Node, animation_name: StringName, pause_last: bool = false) -> void:
	var sprite: AnimatedSprite2D = null
	if actor:
		sprite = actor.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation_name):
		return
	sprite.play(animation_name)
	if pause_last:
		var frame_count := sprite.sprite_frames.get_frame_count(animation_name)
		if frame_count > 0:
				sprite.set_frame_and_progress(frame_count - 1, 1.0)
				sprite.pause()


func _ensure_reversed_actor_animation(
	actor: Node,
	animation_name: StringName,
	source_animation_name: StringName
) -> void:
	var sprite: AnimatedSprite2D = null
	if actor:
		sprite = actor.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return
	var frames: SpriteFrames = sprite.sprite_frames
	if frames.has_animation(animation_name):
		return
	if not frames.has_animation(source_animation_name):
		push_warning(
			"找不到可建立反向動畫的來源：%s -> %s"
			% [String(source_animation_name), String(animation_name)]
		)
		return
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, false)
	frames.set_animation_speed(
		animation_name,
		frames.get_animation_speed(source_animation_name)
	)
	var frame_count: int = frames.get_frame_count(source_animation_name)
	for frame_index in range(frame_count - 1, -1, -1):
		frames.add_frame(
			animation_name,
			frames.get_frame_texture(source_animation_name, frame_index),
			frames.get_frame_duration(source_animation_name, frame_index)
		)


func _ensure_actor_atlas_animation(
	actor: Node,
	animation_name: StringName,
	atlas_texture: Texture2D,
	grid_size: Vector2i,
	speed: float,
	loops: bool
) -> void:
	var sprite: AnimatedSprite2D = null
	if actor:
		sprite = actor.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null or atlas_texture == null:
		return
	if sprite.sprite_frames.has_animation(animation_name):
		return
	if grid_size.x <= 0 or grid_size.y <= 0:
		return
	var frame_size := Vector2(
		atlas_texture.get_width() / float(grid_size.x),
		atlas_texture.get_height() / float(grid_size.y)
	)
	sprite.sprite_frames.add_animation(animation_name)
	sprite.sprite_frames.set_animation_loop(animation_name, loops)
	sprite.sprite_frames.set_animation_speed(animation_name, speed)
	for row in range(grid_size.y):
		for column in range(grid_size.x):
			var atlas_frame := AtlasTexture.new()
			atlas_frame.atlas = atlas_texture
			atlas_frame.region = Rect2(
				Vector2(frame_size.x * float(column), frame_size.y * float(row)),
				frame_size
			)
			sprite.sprite_frames.add_frame(animation_name, atlas_frame)


func _move_actor_along_phase_path(
	actor: Node2D,
	path_node_path: NodePath,
	duration: float,
	keep_shadow_on_ground: bool = false,
	ease_type: Tween.EaseType = Tween.EASE_IN_OUT
) -> void:
	if not is_instance_valid(actor):
		return
	var path := get_node_or_null(path_node_path) as Path2D
	var follow: PathFollow2D = null
	if path:
		follow = path.get_node_or_null("PathFollow2D") as PathFollow2D
	if path == null or follow == null or path.curve == null:
		push_warning("找不到 Phase 2 分鏡 Path2D：%s" % String(path_node_path))
		return
	var path_length: float = path.curve.get_baked_length()
	if path_length <= 0.0:
		push_warning("Phase 2 分鏡 Path2D 沒有有效長度：%s" % String(path_node_path))
		return
	follow.progress = 0.0
	actor.global_position = follow.global_position
	var shadow: Control = _get_actor_shadow(actor) if keep_shadow_on_ground else null
	var shadow_world_offset: Vector2 = Vector2.ZERO
	var shadow_ground_y: float = 0.0
	if shadow:
		if not shadow.has_meta("phase_shadow_base_position"):
			shadow.set_meta("phase_shadow_base_position", shadow.position)
		shadow_world_offset = shadow.global_position - actor.global_position
		shadow_ground_y = shadow.global_position.y
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(ease_type)
	tween.tween_method(func(progress: float) -> void:
		follow.progress = progress
		actor.global_position = follow.global_position
		if shadow:
			# 只有跳躍角色需要局部視覺補償；一般地面角色（包含 Boss）
			# 不會進入此分支，Shadow 完全繼承 ActorRoot 的 Parent Transform。
			shadow.global_position = Vector2(
				actor.global_position.x + shadow_world_offset.x,
				shadow_ground_y
			)
	, 0.0, path_length, duration)
	await tween.finished


func _get_actor_shadow(actor: Node) -> Control:
	if actor == null:
		return null
	return actor.get_node_or_null("TextureRect") as Control


func _restore_actor_shadow(actor: Node) -> void:
	var shadow: Control = _get_actor_shadow(actor)
	if shadow == null or not shadow.has_meta("phase_shadow_base_position"):
		return
	shadow.position = Vector2(shadow.get_meta("phase_shadow_base_position"))


func _move_two_actors_along_phase_paths(
	actor_a: Node2D,
	path_a_node_path: NodePath,
	duration_a: float,
	actor_b: Node2D,
	path_b_node_path: NodePath,
	duration_b: float
) -> void:
	var path_a := get_node_or_null(path_a_node_path) as Path2D
	var path_b := get_node_or_null(path_b_node_path) as Path2D
	var follow_a: PathFollow2D = null
	var follow_b: PathFollow2D = null
	if path_a:
		follow_a = path_a.get_node_or_null("PathFollow2D") as PathFollow2D
	if path_b:
		follow_b = path_b.get_node_or_null("PathFollow2D") as PathFollow2D
	if not is_instance_valid(actor_a) or not is_instance_valid(actor_b) \
			or path_a == null or path_b == null \
			or follow_a == null or follow_b == null \
			or path_a.curve == null or path_b.curve == null:
		push_warning(
			"找不到同步 Phase 2 分鏡 Path2D：%s / %s" \
			% [String(path_a_node_path), String(path_b_node_path)]
		)
		return
	var path_a_length: float = path_a.curve.get_baked_length()
	var path_b_length: float = path_b.curve.get_baked_length()
	if path_a_length <= 0.0 or path_b_length <= 0.0:
		push_warning(
			"同步 Phase 2 分鏡 Path2D 沒有有效長度：%s / %s" \
			% [String(path_a_node_path), String(path_b_node_path)]
		)
		return
	follow_a.progress = 0.0
	follow_b.progress = 0.0
	actor_a.global_position = follow_a.global_position
	actor_b.global_position = follow_b.global_position
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(progress: float) -> void:
		follow_a.progress = progress
		actor_a.global_position = follow_a.global_position
	, 0.0, path_a_length, duration_a)
	tween.tween_method(func(progress: float) -> void:
		follow_b.progress = progress
		actor_b.global_position = follow_b.global_position
	, 0.0, path_b_length, duration_b)
	await tween.finished


func _move_zuoyin_along_existing_path() -> void:
	if zuoyin_npc == null:
		return
	var path := get_node_or_null("Zuo_yin_jump_in/Path2D") as Path2D
	var follow := get_node_or_null("Zuo_yin_jump_in/Path2D/PathFollow2D") as PathFollow2D
	if path == null or follow == null or path.curve == null:
		push_warning("找不到左飲既有跳躍 Path，改由既有左飲節點直接顯示。")
		zuoyin_npc.visible = true
		return
	follow.progress = 0.0
	zuoyin_npc.visible = true
	zuoyin_npc.global_position = follow.global_position
	_play_actor_animation(zuoyin_npc, &"boldstep_hop_right_up")
	var length := path.curve.get_baked_length()
	var tween := create_tween()
	tween.tween_method(func(progress: float):
		follow.progress = progress
		zuoyin_npc.global_position = follow.global_position
	, 0.0, length, ZUOYIN_JUMP_BASE_DURATION / ZUOYIN_JUMP_SPEED_SCALE)
	await tween.finished
	var sprite := zuoyin_npc.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite and sprite.sprite_frames \
			and sprite.sprite_frames.has_animation(&"boldstep_hop_right_up"):
		var frame_count := sprite.sprite_frames.get_frame_count(&"boldstep_hop_right_up")
		sprite.pause()
		if frame_count > 0:
			sprite.set_frame_and_progress(frame_count - 1, 1.0)
	await get_tree().create_timer(0.6).timeout
	_play_actor_animation(zuoyin_npc, &"idle_right_up")


func _start_fish_boss_battle() -> void:
	var config := get_fish_boss_battle_config()
	var player := _get_player()
	var game_root := get_node_or_null("/root/GameRoot")
	if player == null or game_root == null:
		push_warning("找不到 LiuYu 或 GameRoot，無法啟動鐘乳石洞 Boss 戰。")
		return
	if (config.get("player_party", []) as Array).size() != SPECIAL_BATTLE_PARTY_IDS.size():
		push_warning("鐘乳石洞特殊隊伍不完整，取消 Boss 戰進場。")
		return
	if (config.get("enemy_party", []) as Array).is_empty():
		push_warning("EnemyDB 找不到墨鱗魘將，取消 Boss 戰進場。")
		return

	var enemies: Array = config.get("enemy_party", [])
	if player.has_method("_resolve_encounter_transition_style"):
		config["encounter_transition_style"] = player.call("_resolve_encounter_transition_style", enemies)
	GlobalState.set_meta("return_map_path", CAVE_SCENE_PATH)
	GlobalState.set_meta("return_player_pos", player.global_position)
	GlobalState.set_meta("return_encounter_cooldown", 0.0)
	GlobalState.set_meta("pending_battle_context", config)
	if game_root.has_method("pause_world_bgm_for_battle"):
		game_root.call("pause_world_bgm_for_battle")
	if player.has_method("lock_for_battle"):
		player.call("lock_for_battle")
	if player.has_method("_play_encounter_transition"):
		await player.call("_play_encounter_transition", config.get("encounter_transition_style", {}))
	player.visible = false
	game_root.call("change_map_to", BATTLE_SCENE_PATH)


func _connect_battle_finished_signal_if_possible(battle_node: Node) -> void:
	var signal_names := [
		"battle_finished",
		"battle_ended",
		"battle_result",
		"battle_won",
		"combat_finished",
	]

	for signal_name in signal_names:
		if battle_node.has_signal(signal_name):
			var callable := Callable(self, "_on_battle_finished")
			if not battle_node.is_connected(signal_name, callable):
				battle_node.connect(signal_name, callable, CONNECT_ONE_SHOT)
			return


func _on_battle_finished(result = null) -> void:
	var won := true

	if result is Dictionary and result.has("won"):
		won = bool(result["won"])
	elif result is bool:
		won = result
	elif result is String:
		won = result == "win" or result == "won" or result == "victory"

	if won:
		await on_fish_boss_battle_won()


# ------------------------------------------------------------
# 給戰鬥系統呼叫的劇情節點
# ------------------------------------------------------------
func on_fish_boss_phase_two_started() -> void:
	# BOSS 血量低於 50% 時呼叫。
	_set_flag(F_FISH_BOSS_PHASE2, true)
	_set_flag("battle_fish_boss_regen_active", true)
	_set_flag("battle_fish_boss_defense_buff_active", true)

	# 若戰鬥系統會顯示訊息，可讀這些 flag 或直接呼叫自己的 UI。
	print("魚怪進入二階：濁流護身 / 回血 / 防禦上升。")


func on_fish_boss_phase_two_survived_three_turns() -> void:
	# 玩家在二階撐過三回合後呼叫。
	if _get_flag(F_ZUOYIN_ASSIST_ACTIVE, false):
		return

	_set_flag(F_ZUOYIN_ASSIST_ACTIVE, true)
	_set_flag(F_ZUOYIN_GUEST_JOINED, true)

	await _play_zuoyin_arrival_cutscene_or_fallback()
	_activate_zuoyin_guest_assist()


func _play_zuoyin_arrival_cutscene_or_fallback() -> void:
	var cutscene_manager := _get_cutscene_manager()
	if cutscene_manager:
		if cutscene_manager.has_method("play_cutscene"):
			await cutscene_manager.play_cutscene(zuoyin_arrival_cutscene_key)
			return
		if cutscene_manager.has_method("play"):
			await cutscene_manager.play(zuoyin_arrival_cutscene_key)
			return
		if cutscene_manager.has_method("play_by_key"):
			await cutscene_manager.play_by_key(zuoyin_arrival_cutscene_key)
			return

	await _show_dialog([
		_n("巨鯉仰首嘶吼，洞中水脈應聲翻黑。"),
		_n("紫黑濁氣如鎖，纏上牠的鱗甲。"),
		_l("不好……它在借水脈反噬封印！", shumian_speaker_id, shumian_portrait_path),
		_l("這樣下去，整座洞都會被拖進去。", liuyu_speaker_id, liuyu_portrait_path),
		_n("就在此時，一道寒光自洞口斜斬而入。"),
		_n("水面翻起的濁潮被硬生生劈成兩半。"),
		_l("退半步。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_l("左飲？", liuyu_speaker_id, liuyu_portrait_path),
		_l("別分心。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_l("魚怪交給你們。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_l("濁氣的根，我來斬。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_n("左飲斬斷濁流，魚怪的「濁流護身」開始崩解。"),
		_n("左飲加入助戰。"),
	])


func _activate_zuoyin_guest_assist() -> void:
	# 給戰鬥系統讀取：左飲作為第三格客座角色，玩家不可控制。
	var global_state := _get_global_state()
	if global_state:
		global_state.set_meta("battle_party_slot_3", "zuoyin")
		global_state.set_meta("battle_zuoyin_assist_ai", "debuff_defense_stop_regen")
	_set_flag("battle_party_slot_3_controllable", false)

	# 左飲效果：削弱魚怪防禦與回血。
	_set_flag("battle_fish_boss_regen_active", false)
	_set_flag("battle_fish_boss_defense_buff_active", false)
	_set_flag("battle_fish_boss_defense_debuff_by_zuoyin", true)
	_set_flag("battle_fish_boss_regen_disabled_by_zuoyin", true)

	var party_manager := _get_party_manager()
	if party_manager:
		if party_manager.has_method("set_guest_member"):
			party_manager.set_guest_member(3, "zuoyin")
		elif party_manager.has_method("add_guest_member"):
			party_manager.add_guest_member("zuoyin")
		elif party_manager.has_method("set_party_member"):
			party_manager.set_party_member(3, "zuoyin")


func on_fish_boss_battle_won() -> void:
	if _get_flag(F_FISH_BOSS_WON, false):
		# Older completed saves may predate the global-knowledge reward flag.  The
		# idempotent manual APIs make this safe while still repairing that save.
		_grant_phase2_knowledge_rewards()
		return

	_grant_phase2_knowledge_rewards()
	_set_flag(F_FISH_BOSS_WON, true)
	_set_flag(F_MANOR_AFTER_FISH_READY, true)

	# 戰後先清除客座戰鬥狀態。書眠正式入隊放到飲月山莊會談結尾再處理。
	_set_flag(F_ZUOYIN_ASSIST_ACTIVE, false)
	_set_flag(F_ZUOYIN_GUEST_JOINED, false)
	var global_state := _get_global_state()
	if global_state:
		if global_state.has_meta("battle_party_slot_3"):
			global_state.remove_meta("battle_party_slot_3")
		if global_state.has_meta("battle_zuoyin_assist_ai"):
			global_state.remove_meta("battle_zuoyin_assist_ai")
	_set_flag("battle_party_slot_3_controllable", false)

	# 回到洞中後、BlackOverlay 之前：魚怪變回鯉魚跳入水中、三人放下戒備交談，離場時黑幕同時淡入。
	await _play_phase2_victory_cutscene()
	await _transition_to_yin_yue_manor_night()


func _grant_phase2_knowledge_rewards() -> void:
	if _get_flag(F_FISH_BOSS_REWARDS_GRANTED, false):
		return
	if TeamData == null:
		push_warning("找不到 TeamData，無法授予魘將戰後武學傳承。")
		return
	var skill_granted := TeamData.has_method("acquire_skill_manual")
	var inner_force_granted := TeamData.has_method("acquire_inner_force_manual")
	if not skill_granted or not inner_force_granted:
		push_warning("TeamData 缺少戰後武學傳承 API，略過本次授予。")
		return
	TeamData.acquire_skill_manual(PHASE2_REWARD_SKILL_ID)
	TeamData.acquire_inner_force_manual(PHASE2_REWARD_INNER_FORCE_ID)
	_set_flag(F_FISH_BOSS_REWARDS_GRANTED, true)


func on_fish_boss_battle_lost() -> void:
	# 可給戰鬥系統失敗時呼叫。先保留，不自動處理 Game Over。
	_set_flag("battle_stalactite_fish_boss_lost", true)


# ------------------------------------------------------------
# Party helpers
# ------------------------------------------------------------
func _get_party_manager() -> Node:
	var paths := [
		"/root/PartyManager",
		"/root/GameRoot/PartyManager",
		"/root/PartyController",
		"/root/GameRoot/PartyController",
	]
	return _get_first_node(paths)


# ------------------------------------------------------------
# 轉場：回終端房 / 回飲月山莊夜晚
# ------------------------------------------------------------
func _on_to_yuheng_sewer_final_room_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return

	if story_locked or transition_locked:
		return

	transition_locked = true
	_set_player_movable(false)

	await _fade_out()

	var game_root := get_node_or_null("/root/GameRoot")
	if game_root:
		game_root.spawn_point_name = sewer_final_room_spawn_point_name
		if game_root.has_method("change_map_to"):
			game_root.change_map_to(yuheng_sewer_final_room)
			return

	get_tree().change_scene_to_file(yuheng_sewer_final_room)


# ------------------------------------------------------------
# Phase 2 勝利後的鐘乳石洞收尾演出
#   魚怪 -> 鯉魚 -> 跳入水中 -> 三人放下戒備 -> 對話 -> 離場 + BlackOverlay 同時淡入
# 之後接既有的七段返程字幕與飲月山莊轉場（不在這裡處理）。
# ------------------------------------------------------------
func _play_phase2_victory_cutscene() -> void:
	var player := _get_player()
	if player == null or overlay == null:
		push_warning("鐘乳石洞戰後演出找不到劉語塵或 BlackOverlay，略過演出直接進入返程字幕。")
		return
	var boss := _prepare_phase2_victory_stage(player)
	await _fade_cave_in(CAVE_VICTORY_FADE_IN_SECONDS)
	await get_tree().create_timer(CAVE_VICTORY_BEAT_SECONDS).timeout

	# 1. 魚怪 -> 鯉魚 -> 朝水面跳去 -> 入水消失（沒有旁白；三人仍在戒備）
	await _play_fish_defeat_and_escape(boss)

	# 2. 三人先盯著水面，確認牠真的走了，才一個一個放下戒備
	await get_tree().create_timer(CAVE_VICTORY_WATCH_SECONDS).timeout
	await _relax_after_victory(player)

	# 3. 對話
	await _play_phase2_victory_dialogue()

	# 4. 離場：三人朝左下出口走，BlackOverlay 同時開始淡入
	await _walk_out_and_fade_to_black(player)


func _fade_cave_in(seconds: float) -> void:
	overlay.visible = true
	var tween := overlay.create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, seconds)
	await tween.finished


## 三人與魚怪回到戰鬥結束時的位置與姿態（戒備、備戰）。
func _prepare_phase2_victory_stage(player: Node2D) -> Node2D:
	var shumian_marker := get_node_or_null("SpawnPoints/Su_mien_fight_scene") as Marker2D
	var zuoyin_marker := get_node_or_null("SpawnPoints/zuo_yin_fight_scene") as Marker2D
	var boss_marker := get_node_or_null("SpawnPoints/molingyanjiana_fight") as Marker2D
	_stage_liuyu_for_phase2_victory(player)
	if shumian_npc:
		if shumian_marker:
			shumian_npc.global_position = shumian_marker.global_position
		shumian_npc.visible = true
		_play_actor_animation(shumian_npc, &"ready_for_fight_right_down", true)
	if zuoyin_npc:
		if zuoyin_marker:
			zuoyin_npc.global_position = zuoyin_marker.global_position
		zuoyin_npc.visible = true
		# 劍已出鞘的站姿（既有「拔劍後」動畫停在最後一格）
		_play_actor_animation(zuoyin_npc, &"post_draw_sword_resonance_right", true)
	if not is_instance_valid(_phase_transition_boss):
		_phase_transition_boss = MolinYanjiangScene.instantiate() as Node2D
		if _phase_transition_boss:
			get_node("NPC").add_child(_phase_transition_boss)
	if _phase_transition_boss:
		if boss_marker:
			_phase_transition_boss.global_position = boss_marker.global_position
		_phase_transition_boss.scale = Vector2.ONE * PHASE_TRANSITION_BOSS_SCALE
		_phase_transition_boss.modulate = Color.WHITE
		_phase_transition_boss.visible = true
		_play_actor_animation(_phase_transition_boss, &"phase2_idle_left_down")
	return _phase_transition_boss


## 劉語塵站回 Liu_yu_fight_scene，持劍戒備（ready_fight_idle_right_down）；不讓玩家腳本接管動畫與移動。
func _stage_liuyu_for_phase2_victory(player: Node2D) -> void:
	var liuyu_marker := get_node_or_null("SpawnPoints/Liu_yu_fight_scene") as Marker2D
	player.visible = true
	player.set("can_move", false)
	player.set("override_idle_animation", true)
	if liuyu_marker:
		player.global_position = liuyu_marker.global_position
	_set_phase_transition_initial_shadow(player)
	_play_actor_animation(player, &"ready_fight_idle_right_down", true)


## 墨鱗魘將（既有 phase2_defeated，五格）變回鯉魚，再用既有的 jump_into_pond（鯉魚跳動）一路跳向水面。
## 位移由 Root（CharacterBody2D）負責，影子跟著 Root；只有 AnimatedSprite2D 做上下的彈跳。
func _play_fish_defeat_and_escape(boss: Node2D) -> void:
	if not is_instance_valid(boss):
		return
	var sprite := boss.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var defeat_seconds := _start_actor_animation_once_and_hold(boss, &"phase2_defeated", 5.0 / 3.0)
	await get_tree().create_timer(defeat_seconds + 0.9).timeout
	if sprite == null:
		boss.visible = false
		return
	var start: Vector2 = boss.global_position
	var boss_marker := get_node_or_null("SpawnPoints/molingyanjiana_fight") as Marker2D
	var water: Vector2 = (boss_marker.global_position if boss_marker else start) + carp_water_offset
	var base_y: float = sprite.position.y
	_play_actor_animation(boss, &"jump_into_pond")
	var hop := create_tween()
	hop.tween_method(func(progress: float) -> void:
		if not is_instance_valid(boss) or not is_instance_valid(sprite):
			return
		boss.global_position = start.lerp(water, progress)
		# 每一跳：落地時 y 回到 0，空中抬高
		var phase := progress * float(CARP_HOP_COUNT)
		sprite.position.y = base_y - absf(sin(phase * PI)) * CARP_HOP_HEIGHT
	, 0.0, 1.0, CARP_JUMP_SECONDS)
	await hop.finished
	if not is_instance_valid(boss):
		return
	# 落水：下沉、淡出、消失
	sprite.position.y = base_y
	var sink := create_tween().set_parallel(true)
	sink.tween_property(sprite, "position:y", base_y + 18.0, CARP_SINK_SECONDS)
	sink.tween_property(boss, "modulate:a", 0.0, CARP_SINK_SECONDS)
	await sink.finished
	boss.visible = false
	boss.modulate.a = 1.0
	sprite.position.y = base_y


## 逐漸放下戰意：左飲先收劍（既有 unsheathe_right 反向播放），接著劉語塵收劍站定，最後白書眠放鬆。
func _relax_after_victory(player: Node2D) -> void:
	if zuoyin_npc:
		_ensure_reversed_actor_animation(zuoyin_npc, &"unsheathe_right_reversed", &"unsheathe_right")
		var zuoyin_duration := _start_actor_animation_once_and_hold(zuoyin_npc, &"unsheathe_right_reversed", 1.2)
		await get_tree().create_timer(zuoyin_duration).timeout
		_play_actor_animation(zuoyin_npc, &"idle_right_down")
	await get_tree().create_timer(CAVE_VICTORY_RELAX_STAGGER_SECONDS).timeout
	# 劉語塵收劍：ready_fight_right_down（拔劍備戰）倒著播，吻合 sprite sheet 的動作邏輯，再回到普通站姿
	_ensure_reversed_actor_animation(player, &"ready_fight_right_down_reversed", &"ready_fight_right_down")
	var liuyu_duration := _start_actor_animation_once_and_hold(player, &"ready_fight_right_down_reversed", 0.8)
	await get_tree().create_timer(maxf(liuyu_duration, 0.5)).timeout
	_clear_phase_transition_initial_shadow(player)
	_play_actor_animation(player, &"idle_right_down")
	await get_tree().create_timer(CAVE_VICTORY_RELAX_STAGGER_SECONDS * 0.6).timeout
	# 白書眠沒有「收筆」動畫：備戰站姿 -> 普通站姿（最接近的既有動畫）
	_play_actor_animation(shumian_npc, &"idle_right_down")
	await get_tree().create_timer(CAVE_VICTORY_SETTLE_SECONDS).timeout


func _play_phase2_victory_dialogue() -> void:
	await _show_dialog([
		_l("結……結束了？", shumian_speaker_id, shumian_portrait_path),
		_l("剛才讓我們吃盡苦頭的……竟只是一尾尋常鯉魚。", liuyu_speaker_id, liuyu_portrait_path),
		_l("魚是尋常。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_l("把牠養成那副模樣的東西，可不是。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_l("舊水道裡積了太久的穢氣……", liuyu_speaker_id, liuyu_portrait_path),
		_l("是那些被徽音的琴聲壓下去、本來屬於鎮民的怒意麼？", shumian_speaker_id, shumian_portrait_path),
		_l("不只怒意。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_l("怨、惱、爭執、不甘……人與人活在一處，本來就不可能什麼衝突都沒有。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_l("可那些東西沒有真的消失。", liuyu_speaker_id, liuyu_portrait_path),
		_l("嗯。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_l("壓得久了，又全往一處積。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_l("自然就成了牠最好的養料。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
	])
	# 停頓一下
	await get_tree().create_timer(CAVE_VICTORY_PAUSE_BEFORE_PEACE_SECONDS).timeout
	await _show_dialog([
		_l("……一切都恢復平靜了。", shumian_speaker_id, shumian_portrait_path),
		_l("至少眼下如此。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_l("回去吧。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_l("回去？", liuyu_speaker_id, liuyu_portrait_path),
		_l("……？", shumian_speaker_id, shumian_portrait_path),
		_l("我是說，來飲月山莊吧。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
		_l("有些事情，該坐下來說清楚了。", zuoyin_speaker_id, zuoyin_portrait_path, "左飲"),
	])


## 左飲帶頭離場：沿場景裡的 Zuo_yin_jump_in/exit（Path2D）走向出口；另外兩人的目光跟著他，
## CAVE_EXIT_FOLLOW_DELAY_SECONDS 之後才跟上。BlackOverlay 與左飲出發同時開始淡入，全黑時回傳，
## 之後不解除，直接接既有返程字幕。
func _walk_out_and_fade_to_black(player: Node2D) -> void:
	var exit_path := get_node_or_null("Zuo_yin_jump_in/exit") as Path2D
	var exit_follow := get_node_or_null("Zuo_yin_jump_in/exit/PathFollow2D") as PathFollow2D
	var exit_marker := get_node_or_null("SpawnPoints/from_yuheng_sewer_final_room") as Marker2D
	# 其他兩人跟上的終點：左飲這條路的盡頭（沒有這條路時退回洞口標記）
	var follow_point: Vector2 = exit_marker.global_position if exit_marker else player.global_position + Vector2(-400.0, 300.0)
	if exit_path and exit_path.curve and exit_path.curve.point_count > 0:
		follow_point = exit_path.to_global(exit_path.curve.get_point_position(exit_path.curve.point_count - 1))
	overlay.visible = true
	overlay.modulate.a = 0.0
	var fade := overlay.create_tween()
	fade.tween_property(overlay, "modulate:a", 1.0, CAVE_EXIT_FADE_SECONDS)
	# 左飲先走；另外兩人先看著他，過了 CAVE_EXIT_FOLLOW_DELAY_SECONDS 才邁步跟上，終點錯開避免穿模
	if exit_path and exit_follow and exit_path.curve and zuoyin_npc:
		_walk_zuoyin_along_exit_path(exit_path, exit_follow)
	else:
		_walk_actor_to(zuoyin_npc, &"walk_left_down", follow_point, 0.0)
	_watch_leader(shumian_npc, zuoyin_npc, CAVE_EXIT_FOLLOW_DELAY_SECONDS)
	_watch_leader(player, zuoyin_npc, CAVE_EXIT_FOLLOW_DELAY_SECONDS)
	_walk_actor_to(shumian_npc, &"idle_left_down", follow_point + Vector2(26.0, -12.0), CAVE_EXIT_FOLLOW_DELAY_SECONDS)
	_walk_actor_to(player, &"walk_left_down", follow_point + Vector2(-8.0, 8.0), CAVE_EXIT_FOLLOW_DELAY_SECONDS + CAVE_EXIT_START_STAGGER_SECONDS)
	await fade.finished


## 左飲沿 Path2D 走；走路動畫用 Zuo_yin3 的 walk_left_down（路徑一路朝左下）。
func _walk_zuoyin_along_exit_path(path: Path2D, follow: PathFollow2D) -> void:
	var length: float = path.curve.get_baked_length()
	if length <= 0.0:
		return
	follow.progress = 0.0
	zuoyin_npc.global_position = follow.global_position
	_play_actor_animation(zuoyin_npc, &"walk_left_down")
	var tween := create_tween()
	tween.tween_method(func(progress: float) -> void:
		if not is_instance_valid(zuoyin_npc):
			return
		follow.progress = progress
		zuoyin_npc.global_position = follow.global_position
	, 0.0, length, length / ZUOYIN_EXIT_WALK_SPEED)


## 目光跟著 leader：每隔一小段時間朝向他現在的位置（八方向待機動畫），持續 seconds 秒。
func _watch_leader(actor: Node2D, leader: Node2D, seconds: float) -> void:
	actor.set_meta("gaze_stop", false)
	var until_ms: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until_ms and is_instance_valid(actor) and is_instance_valid(leader) and not bool(actor.get_meta("gaze_stop", false)):
		_play_actor_animation(actor, _idle_animation_toward(leader.global_position - actor.global_position))
		await get_tree().create_timer(CAVE_EXIT_GAZE_STEP_SECONDS).timeout


## 與劉語塵腳本相同的八方向切分（idle_<方向>）。
func _idle_animation_toward(direction: Vector2) -> StringName:
	if direction.length() < 0.01:
		return &"idle_down"
	var angle: float = direction.angle()
	if angle >= -PI * 7.0 / 8.0 and angle < -PI * 5.0 / 8.0:
		return &"idle_left_up"
	elif angle >= -PI * 5.0 / 8.0 and angle < -PI * 3.0 / 8.0:
		return &"idle_up"
	elif angle >= -PI * 3.0 / 8.0 and angle < -PI * 1.0 / 8.0:
		return &"idle_right_up"
	elif angle >= -PI * 1.0 / 8.0 and angle < PI * 1.0 / 8.0:
		return &"idle_right"
	elif angle >= PI * 1.0 / 8.0 and angle < PI * 3.0 / 8.0:
		return &"idle_right_down"
	elif angle >= PI * 3.0 / 8.0 and angle < PI * 5.0 / 8.0:
		return &"idle_down"
	elif angle >= PI * 5.0 / 8.0 and angle < PI * 7.0 / 8.0:
		return &"idle_left_down"
	return &"idle_left"


## 沿直線走向目標。沒有行走動畫的角色（白書眠）用面向左下的站姿滑行；左飲用 Zuo_yin3 的 walk_left_down。
func _walk_actor_to(actor: Node2D, animation_name: StringName, target: Vector2, delay: float) -> void:
	if not is_instance_valid(actor):
		return
	var distance: float = actor.global_position.distance_to(target)
	var seconds: float = maxf(distance / CAVE_EXIT_WALK_SPEED, 0.1)
	var tween := actor.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_callback(func() -> void:
		if is_instance_valid(actor):
			actor.set_meta("gaze_stop", true)
			_play_actor_animation(actor, animation_name)
	)
	tween.tween_property(actor, "global_position", target, seconds)


func _transition_to_yin_yue_manor_night() -> void:
	transition_locked = true
	_set_player_movable(false)

	await _fade_out()
	await _play_post_battle_transition_captions()

	var game_root := get_node_or_null("/root/GameRoot")
	if game_root:
		game_root.spawn_point_name = manor_spawn_point_name
		if game_root.has_method("change_map_to"):
			game_root.change_map_to(yin_yue_manor_room_night)
			return

	get_tree().change_scene_to_file(yin_yue_manor_room_night)


func _fade_out() -> void:
	if overlay == null:
		return

	overlay.visible = true
	if overlay.modulate.a >= 0.999:
		return

	var tween := overlay.create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
	await tween.finished


func _play_post_battle_transition_captions() -> void:
	var canvas_layer := get_node_or_null("CanvasLayer") as CanvasLayer
	if canvas_layer == null:
		push_warning("鐘乳石洞戰後字幕找不到 CanvasLayer，將直接轉往飲月山莊。")
		return

	var caption := Label.new()
	caption.name = "PostBattleTransitionCaption"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_color_override("font_color", Color(0.96, 0.96, 0.94, 1.0))
	caption.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	caption.add_theme_constant_override("outline_size", 6)
	caption.add_theme_font_size_override("font_size", 24)
	caption.modulate.a = 0.0
	canvas_layer.add_child(caption)
	var viewport_size := get_viewport_rect().size
	caption.position = Vector2(viewport_size.x * 0.1, 0.0)
	caption.size = Vector2(viewport_size.x * 0.8, viewport_size.y)

	for caption_text in POST_BATTLE_CAPTIONS:
		caption.text = String(caption_text)
		caption.modulate.a = 0.0
		var caption_tween := caption.create_tween()
		caption_tween.tween_property(
			caption,
			"modulate:a",
			1.0,
			POST_BATTLE_CAPTION_FADE_SECONDS
		)
		caption_tween.tween_interval(POST_BATTLE_CAPTION_HOLD_SECONDS)
		caption_tween.tween_property(
			caption,
			"modulate:a",
			0.0,
			POST_BATTLE_CAPTION_FADE_SECONDS
		)
		await caption_tween.finished
		await get_tree().create_timer(POST_BATTLE_CAPTION_GAP_SECONDS).timeout

	caption.queue_free()


# ------------------------------------------------------------
# Node finders
# ------------------------------------------------------------
func _get_cutscene_manager() -> Node:
	var paths := [
		"/root/CutsceneManager",
		"/root/GameRoot/CutsceneManager",
		"/root/CutscenePlayer",
		"/root/GameRoot/CutscenePlayer",
	]
	return _get_first_node(paths)


func _get_battle_node() -> Node:
	var paths := [
		"/root/GameRoot/BattleTransition",
		"/root/BattleTransition",
		"/root/GameRoot/BattleController",
		"/root/BattleController",
		"/root/GameRoot/BattleManager",
		"/root/BattleManager",
	]
	return _get_first_node(paths)


func _get_first_node(paths: Array[String]) -> Node:
	for node_path in paths:
		var node := get_node_or_null(node_path)
		if node:
			return node
	return null


# ------------------------------------------------------------
# 共用工具：玩家 / Trigger
# ------------------------------------------------------------
func _is_player(body: Node) -> bool:
	return body.name == "LiuYu" or body.name == "Player" or body.is_in_group("player")


func _set_player_movable(value: bool) -> void:
	var player := _get_player()
	if player:
		player.set("can_move", value)


func _get_player() -> Node2D:
	var player := get_node_or_null("/root/GameRoot/LiuYu") as Node2D
	if player == null:
		player = get_node_or_null("/root/Player") as Node2D
	return player


func _disable_event_trigger() -> void:
	if event_trigger == null:
		return

	for child in event_trigger.get_children():
		if child is CollisionShape2D:
			child.disabled = true


# ------------------------------------------------------------
# Dialog helpers
# ------------------------------------------------------------
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


func _show_synchronized_dialog(lines: Array) -> void:
	var dialog_manager := _get_dialog_manager()
	if dialog_manager and dialog_manager.has_method("show_synchronized_dialog_pair"):
		_waiting_for_dialog = true
		dialog_manager.show_synchronized_dialog_pair(lines, self)
		await _wait_dialog_finished(dialog_manager)
		return
	await _show_dialog(lines)


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


func _l(
	text: String,
	speaker: int,
	portrait: String = "",
	speaker_name: String = ""
) -> Dictionary:
	var line: Dictionary = {
		"text": text,
		"speaker": speaker,
		"portrait": portrait if portrait != "" else empty_portrait_path,
	}
	if speaker_name != "":
		line["speaker_name"] = speaker_name
	return line


func _n(text: String) -> Dictionary:
	return {
		"text": text,
		"speaker": narration_speaker_id,
		"portrait": empty_portrait_path,
	}


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


func _set_flag(flag_name: String, value: bool) -> void:
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
