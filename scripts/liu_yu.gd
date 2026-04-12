extends CharacterBody2D

const WALK_SPEED = 160
const RUN_SPEED = 400

var last_direction := Vector2(1, 1).normalized()
var direction := Vector2.ZERO
var can_move := true

@onready var animated_sprite := $AnimatedSprite2D
# 若角色腳底位置與 Sprite 原點不同，可調整這個偏移
@export var z_index_offset := 0
@export var random_encounter_enabled := true
const EnemyDB = preload("res://scripts/db/EnemyDB.gd")
const ZONE_CONFIG := {
	"yuheng_bamboo_outskirts": {
		"distance_threshold": 280.0,
		"chance": 0.25,
		"cooldown_distance": 320.0,
		"intro_key": "yuheng_bamboo_outskirts_random"
	},
	"yuheng_sewer": {
		"distance_threshold": 240.0,
		"chance": 0.30,
		"cooldown_distance": 280.0,
		"intro_key": "yuheng_sewer_random"
	}
}

const ENCOUNTER_POOLS := {
	"yuheng_bamboo_outskirts": [
		{"w": 0, "enemies": ["bamboo_macaque", "bamboo_macaque"]},
		{"w": 0, "enemies": ["bamboo_macaque", "bamboo_bobcat"]},
		{"w": 20, "enemies": ["bamboo_wild_boar"]},
		{"w": 75, "enemies": ["bamboo_poison_snake", "bamboo_poison_snake"]},
		{"w": 5, "enemies": ["bamboo_bobcat", "bamboo_poison_snake"]}
	],
	"yuheng_sewer": [
		{"w": 35, "enemies": ["sewer_rat_swarm"]},
		{"w": 30, "enemies": ["sewer_thug", "sewer_thug"]},
		{"w": 20, "enemies": ["sewer_thug", "sewer_rat_swarm"]},
		{"w": 10, "enemies": ["sewer_ooze_slime"]},
		{"w": 5, "enemies": ["sewer_drowned_wight"]}
	]
}
const ENCOUNTER_TRANSITION_FONT_PATH := "res://assets/fonts/YuWeiShuFaXingShuFanTi-1.ttf"
const ENCOUNTER_IMPACT_SFX_PATH := "res://assets/sound/encounter.ogg"
const ENCOUNTER_ZOOM_SCALE := 0.88
const ENCOUNTER_ZOOM_DURATION := 0.5
const ENCOUNTER_WAR_HOLD_DURATION := 1.2
const ENCOUNTER_WAR_FADE_DURATION := 0.8
const ENCOUNTER_DEBUG_LOG := true
const ENCOUNTER_STYLE_BY_ARCHETYPE := {
	"地痞": "ruffian",
	"山賊": "ruffian",
	"匪徒": "ruffian",
	"流氓": "ruffian",
	"朝廷": "court",
	"官兵": "court",
	"軍人": "court",
	"野獸": "beast",
	"爬蟲": "beast",
	"鬼神": "ghost",
	"江湖人士": "jianghu"
}
const ENCOUNTER_STYLE_DEFAULT_TEXTURE := "res://assets/background/encounter_screen_defult.jpg"
const ENCOUNTER_STYLE_PROFILES := {
	"default": {
		"glyphs": ["戰"],
		"colors": [Color(0.95, 0.18, 0.16, 1.0)],
		"generic_texture_path": ENCOUNTER_STYLE_DEFAULT_TEXTURE,
		"glyph_texture_paths": {"戰": ENCOUNTER_STYLE_DEFAULT_TEXTURE}
	},
	"ruffian": {
		"glyphs": ["劫"],
		"colors": [Color(0.57, 0.49, 0.33, 1.0), Color(0.45, 0.43, 0.40, 1.0), Color(0.24, 0.20, 0.16, 1.0)],
		"generic_texture_path": "res://assets/background/encounter_screen_rob.jpg",
		"glyph_texture_paths": {"劫": "res://assets/background/encounter_screen_rob.jpg"}
	},
	"court": {
		"glyphs": ["令", "緝"],
		"colors": [Color(0.62, 0.66, 0.70, 1.0), Color(0.38, 0.50, 0.56, 1.0), Color(0.60, 0.28, 0.26, 1.0)],
		"generic_texture_path": "res://assets/background/encounter_screen_court_defult.jpg",
		"glyph_texture_paths": {"令": "res://assets/background/encounter_screen_court_ling.jpg", "緝": "res://assets/background/encounter_screen_court_chi.jpg"}
	},
	"beast": {
		"glyphs": ["獵", "獸"],
		"colors": [Color(0.43, 0.30, 0.18, 1.0), Color(0.62, 0.48, 0.28, 1.0), Color(0.82, 0.74, 0.56, 1.0)],
		"generic_texture_path": ENCOUNTER_STYLE_DEFAULT_TEXTURE,
		"glyph_texture_paths": {"獵": ENCOUNTER_STYLE_DEFAULT_TEXTURE, "獸": ENCOUNTER_STYLE_DEFAULT_TEXTURE}
	},
	"ghost": {
		"glyphs": ["煞", "厄", "魘"],
		"colors": [Color(0.10, 0.10, 0.10, 1.0), Color(0.45, 0.12, 0.12, 1.0), Color(0.36, 0.34, 0.34, 1.0)],
		"generic_texture_path": "res://assets/background/encounter_screen_phantom_defult.jpg",
		"glyph_texture_paths": {"煞": "res://assets/background/encounter_screen_phantom_xar.jpg", "厄": "res://assets/background/encounter_screen_phantom_er.jpg", "魘": "res://assets/background/encounter_screen_phantom_yan.jpg"}
	},
	"jianghu": {
		"glyphs": ["決", "鬥"],
		"colors": [Color(0.12, 0.12, 0.12, 1.0), Color(0.56, 0.24, 0.18, 1.0), Color(0.86, 0.86, 0.82, 1.0)],
		"generic_texture_path": ENCOUNTER_STYLE_DEFAULT_TEXTURE,
		"glyph_texture_paths": {"決": "res://assets/background/encounter_screen_jianghu_jue.jpg", "鬥": "res://assets/background/encounter_screen_jianghu_do.jpg"}
	}
}

var in_danger_zone := false
var current_zone_id := ""
var _zone_overrides := {}
var _encounter_distance_accum := 0.0
var _encounter_cooldown_distance := 0.0
var _encounter_rng := RandomNumberGenerator.new()
var _encounter_paused := false
var _encounter_transition_playing := false

func _ready():
	last_direction = GlobalState.last_facing_direction
	animated_sprite.play(get_idle_anim_name(last_direction))
	_encounter_rng.randomize()

# ✅ 修正劉語塵在市集觀察事件中，未與NPC對話時 idle 方向過快復原的情況
# 👉 方法：我們在觀察階段暫時停用 `_physics_process()` 裡自動 idle 的動畫播放邏輯
# 👉 實作方式：新增一個 `override_idle_animation` flag 控制轉向動畫是否由事件接管

# --- 增補在原本角色控制腳本中 ---

# 加在你的變數區域
var override_idle_animation := false

# ✅ 替換 `_physics_process()` 中 idle 動畫的判斷
func _physics_process(delta):
	if not can_move:
		return

	direction = Vector2(
		int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left")),
		int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	).normalized()

	var is_running = Input.is_action_pressed("run")
	var speed = RUN_SPEED if is_running else WALK_SPEED
	var prefix = "run" if is_running else "walk"

	if direction != Vector2.ZERO:
		velocity = direction * speed
		last_direction = direction
		animated_sprite.play(get_anim_name(last_direction, prefix))
	else:
		velocity = Vector2.ZERO
		if not override_idle_animation:
			animated_sprite.play(get_idle_anim_name(last_direction))

	move_and_slide()
	_update_random_encounter(delta)
func get_anim_name(dir: Vector2, prefix: String) -> String:
	return _get_anim_by_vector(dir, prefix)

func get_idle_anim_name(dir: Vector2) -> String:
	return _get_anim_by_vector(dir, "idle")

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

# ✅ 修改 `play_idle_direction()` 讓事件控制 idle 時會設置 override flag
func play_idle_direction(direction_name: String):
	override_idle_animation = true

	var dir_map = {
		"up": Vector2(0, -1),
		"down": Vector2(0, 1),
		"left": Vector2(-1, 0),
		"right": Vector2(1, 0),
		"left_up": Vector2(-1, -1),
		"right_up": Vector2(1, -1),
		"left_down": Vector2(-1, 1),
		"right_down": Vector2(1, 1),
	}

	if dir_map.has(direction_name):
		last_direction = dir_map[direction_name].normalized()
		animated_sprite.play(get_idle_anim_name(last_direction))

# ✅ 加一個讓外部事件在結束時恢復正常 idle 控制的函式
func restore_idle_control():
	override_idle_animation = false

func _update_random_encounter(delta: float) -> void:
	if not random_encounter_enabled:
		return
	if _encounter_paused:
		return
	if _is_battle_active():
		return
	if not in_danger_zone:
		_encounter_distance_accum = 0.0
		return
	if current_zone_id == "":
		return
	if direction == Vector2.ZERO:
		return

	var config = ZONE_CONFIG.get(current_zone_id, {})
	var distance_threshold = _resolve_zone_value(config, "distance_threshold", 0.0)
	var cooldown_distance = _resolve_zone_value(config, "cooldown_distance", 0.0)
	var chance = _resolve_zone_value(config, "chance", 0.0)

	if _encounter_cooldown_distance > 0.0:
		_encounter_cooldown_distance = max(
			_encounter_cooldown_distance - velocity.length() * delta,
			0.0
		)
		return

	if distance_threshold > 0.0:
		_encounter_distance_accum += velocity.length() * delta

	if _encounter_distance_accum < distance_threshold:
		return

	_encounter_distance_accum = 0.0

	if _encounter_rng.randf() <= chance:
		_trigger_random_battle()
	else:
		_encounter_cooldown_distance = cooldown_distance

func _is_battle_active() -> bool:
	return get_tree().root.find_child("BattleScene", true, false) != null

func _trigger_random_battle() -> void:
	if _encounter_transition_playing:
		return
	var player_party = TeamData.get_active_party()
	if player_party.is_empty():
		push_warning("❗ 當前隊伍為空，無法啟動遭遇戰。")
		return

	var game_root = get_node_or_null("/root/GameRoot")
	var current_map := ""
	var scene_name := ""
	var battle_bgm_path := "res://assets/BGM/battle_1.ogg"
	if game_root:
		var current_scene = game_root.get_node_or_null("CurrentScene")
		if current_scene and current_scene.get_child_count() > 0:
			var scene_root := current_scene.get_child(0)
			current_map = String(scene_root.scene_file_path)
			scene_name = String(scene_root.name)
			var bgm_any = scene_root.get("battle_bgm_path")
			if bgm_any != null and str(bgm_any) != "":
				battle_bgm_path = str(bgm_any)

	var enemies = _build_enemies_from_zone(current_zone_id, ENCOUNTER_POOLS)
	var transition_style := _resolve_encounter_transition_style(enemies)

	var context = {
		"player_party": player_party,
		"enemy_party": enemies,
		"ruleset": {"id": "default"},
		"regen_policy": {"id": "round_end_mp_regen_default"},
		"tone": {"intro_key": _resolve_zone_intro_key()},
		"battle_tag": current_zone_id,
		"zone_id": current_zone_id,
		"map_id": current_map,
		"scene_name": scene_name,
		"battle_bgm_path": battle_bgm_path,
		"encounter_transition_style": transition_style
	}

	if context["enemy_party"].is_empty():
		push_warning("❗ Encounter pool 產生空敵人，取消本次遭遇戰。")
		return

	if game_root:
		if current_map != "":
			GlobalState.set_meta("return_map_path", current_map)
		GlobalState.set_meta("return_player_pos", global_position)

	GlobalState.set_meta("pending_battle_context", context)
	if game_root:
		if game_root.has_method("pause_world_bgm_for_battle"):
			game_root.pause_world_bgm_for_battle()
		_pause_for_battle()
		await _play_encounter_transition(context.get("encounter_transition_style", {}))
		visible = false
		var cooldown_distance = _resolve_zone_value(
			ZONE_CONFIG.get(current_zone_id, {}),
			"cooldown_distance",
			0.0
		)
		GlobalState.set_meta("return_encounter_cooldown", cooldown_distance)
		game_root.change_map_to("res://scenes/battle_scene.tscn")
	else:
		push_warning("❗ 找不到 GameRoot，無法切換到戰鬥場景。")
	_encounter_cooldown_distance = _resolve_zone_value(
		ZONE_CONFIG.get(current_zone_id, {}),
		"cooldown_distance",
		0.0
	)

func _weighted_pick(pool: Array) -> Dictionary:
	var total := 0
	for e in pool:
		total += int(e.get("w", 0))
	if total <= 0:
		return {}

	var r = _encounter_rng.randi_range(1, total)
	var acc := 0
	for e in pool:
		acc += int(e.get("w", 0))
		if r <= acc:
			return e
	return pool[-1] if pool.size() > 0 else {}

func _build_enemies_from_zone(
	zone_id: String,
	encounter_pools: Dictionary
) -> Array:
	var pool: Array = encounter_pools.get(zone_id, [])
	if pool.is_empty():
		push_warning("Encounter pool empty for zone_id=%s" % zone_id)
		return []

	var picked := _weighted_pick(pool)
	var ids: Array = picked.get("enemies", [])
	var enemies: Array = []

	for i in range(ids.size()):
		var enemy_id = ids[i]
		var enemy := EnemyDB.make_enemy(enemy_id)
		if enemy.is_empty():
			push_warning("Enemy not found: %s" % enemy_id)
			continue
		enemy["ui_index"] = i
		enemies.append(enemy)

	return enemies

func enter_danger_zone(zone_id: String, overrides: Dictionary = {}) -> void:
	current_zone_id = zone_id
	_zone_overrides = overrides
	in_danger_zone = true

func exit_danger_zone(zone_id: String) -> void:
	if zone_id == current_zone_id:
		in_danger_zone = false
		current_zone_id = ""
		_zone_overrides = {}
		_encounter_distance_accum = 0.0

func reset_encounter_state() -> void:
	in_danger_zone = false
	current_zone_id = ""
	_zone_overrides = {}
	_encounter_distance_accum = 0.0
	_encounter_cooldown_distance = 0.0
	_encounter_paused = false
	_restore_idle_animation()

func set_encounter_paused(paused: bool) -> void:
	_encounter_paused = paused

func set_encounter_cooldown(distance: float) -> void:
	_encounter_cooldown_distance = max(distance, 0.0)

func refresh_danger_zone_from_position(start_delay_sec: float = 0.7) -> void:
	var was_paused := _encounter_paused
	_encounter_paused = true
	if start_delay_sec > 0.0:
		await get_tree().create_timer(start_delay_sec).timeout

	var state := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = global_position
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var hits := state.intersect_point(params, 16)
	var matched_zone: Area2D = null
	for hit_any in hits:
		if typeof(hit_any) != TYPE_DICTIONARY:
			continue
		var hit: Dictionary = hit_any
		var collider_any = hit.get("collider", null)
		if collider_any == null or not (collider_any is Area2D):
			continue
		var area := collider_any as Area2D
		var script_obj: Script = area.get_script() as Script
		if script_obj == null:
			continue
		if String(script_obj.resource_path) != "res://scripts/encounter/DangerZone.gd":
			continue
		matched_zone = area
		break

	if matched_zone != null:
		var zone_id := str(_zone_prop_or(matched_zone, "zone_id", ""))
		var overrides := {}
		var dist_override = float(_zone_prop_or(matched_zone, "distance_threshold_override", -1.0))
		var chance_override = float(_zone_prop_or(matched_zone, "chance_override", -1.0))
		var cooldown_override = float(_zone_prop_or(matched_zone, "cooldown_distance_override", -1.0))
		var intro_override = str(_zone_prop_or(matched_zone, "intro_key_override", ""))
		if dist_override >= 0.0:
			overrides["distance_threshold"] = dist_override
		if chance_override >= 0.0:
			overrides["chance"] = chance_override
		if cooldown_override >= 0.0:
			overrides["cooldown_distance"] = cooldown_override
		if intro_override != "":
			overrides["intro_key"] = intro_override
		enter_danger_zone(zone_id, overrides)
		_encounter_distance_accum = 0.0
		var config = ZONE_CONFIG.get(zone_id, {})
		var soft_cooldown = _resolve_zone_value(config, "distance_threshold", 0.0) * 0.35
		_encounter_cooldown_distance = max(_encounter_cooldown_distance, soft_cooldown)
	else:
		in_danger_zone = false
		current_zone_id = ""
		_zone_overrides = {}
		_encounter_distance_accum = 0.0

	_encounter_paused = was_paused

func _zone_prop_or(area: Object, prop: String, fallback):
	if area == null:
		return fallback
	var value = area.get(prop)
	return fallback if value == null else value

func _pause_for_battle() -> void:
	lock_for_battle()

func lock_for_battle() -> void:
	can_move = false
	velocity = Vector2.ZERO
	_encounter_paused = true
	if animated_sprite:
		animated_sprite.stop()

func restore_after_battle() -> void:
	visible = true
	can_move = true
	velocity = Vector2.ZERO
	_encounter_paused = false
	_restore_idle_animation()

func _restore_idle_animation() -> void:
	override_idle_animation = false
	if animated_sprite:
		animated_sprite.frame = 0
		animated_sprite.play(get_idle_anim_name(last_direction))

func battle_restore() -> void:
	visible = true
	can_move = true
	velocity = Vector2.ZERO
	_encounter_paused = false
	set_process_input(true)
	set_physics_process(true)
	_restore_idle_animation()

func _resolve_zone_value(config: Dictionary, key: String, fallback: float) -> float:
	if _zone_overrides.has(key):
		return float(_zone_overrides[key])
	return float(config.get(key, fallback))

func _resolve_zone_intro_key() -> String:
	if _zone_overrides.has("intro_key"):
		return str(_zone_overrides["intro_key"])
	var config = ZONE_CONFIG.get(current_zone_id, {})
	return str(config.get("intro_key", "default"))

func _process(delta):
	if GlobalState.get_meta("menu_open", false):
		return  # 系統選單開啟時不讓角色動
	# 正常移動邏輯
	
	# 角色的 z_index 隨 y 座標更新（整數避免浮點亂序）
	z_index = int(global_position.y + z_index_offset)

func _play_encounter_transition(style: Dictionary = {}) -> void:
	_encounter_transition_playing = true
	var game_root = get_node_or_null("/root/GameRoot")
	var cam: Camera2D = null
	var base_zoom := Vector2.ONE
	if game_root:
		cam = game_root.get_node_or_null("MainCamera") as Camera2D
	if cam:
		base_zoom = cam.zoom

	var layer := CanvasLayer.new()
	layer.name = "EncounterTransitionLayer"
	layer.layer = 120
	get_tree().root.add_child(layer)

	var black := ColorRect.new()
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.color = Color(0.03, 0.03, 0.04, 0.0)
	layer.add_child(black)

	var white := ColorRect.new()
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	white.color = Color(1, 1, 1, 0.0)
	layer.add_child(white)

	var ink := TextureRect.new()
	ink.set_anchors_preset(Control.PRESET_CENTER)
	ink.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ink.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ink.size = Vector2(1320, 792)
	ink.position = Vector2(-660, -396)
	var texture_path := str(style.get("texture_path", ENCOUNTER_STYLE_DEFAULT_TEXTURE))
	ink.texture = load(texture_path)
	if ink.texture == null:
		push_warning("❗ 找不到遭遇轉場渲染圖：%s" % texture_path)
	ink.modulate = Color(1, 1, 1, 0.0)
	layer.add_child(ink)

	var war_label := Label.new()
	war_label.set_anchors_preset(Control.PRESET_CENTER)
	war_label.offset_left = -220
	war_label.offset_top = -190
	war_label.offset_right = 220
	war_label.offset_bottom = 190
	war_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	war_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	war_label.text = str(style.get("glyph", "戰"))
	war_label.add_theme_font_size_override("font_size", 200)
	var font_color_any = style.get("font_color", Color(0.95, 0.18, 0.16, 1.0))
	var font_color: Color = font_color_any if typeof(font_color_any) == TYPE_COLOR else Color(0.95, 0.18, 0.16, 1.0)
	war_label.add_theme_color_override("font_color", font_color)
	var war_font: Font = load(ENCOUNTER_TRANSITION_FONT_PATH) as Font
	if war_font != null:
		war_label.add_theme_font_override("font", war_font)
	else:
		push_warning("❗ 找不到戰鬥轉場字型：%s" % ENCOUNTER_TRANSITION_FONT_PATH)
	war_label.modulate = Color(1, 1, 1, 0.0)
	layer.add_child(war_label)

	if ENCOUNTER_DEBUG_LOG:
		print("[EncounterTransition] style=", style.get("style_key", "default"), " glyph=", war_label.text, " texture_path=", texture_path)
		print("[EncounterTransition] node=InkScreen visible=", ink.visible, " z_index=", ink.z_index, " modulate=", ink.modulate, " texture_ok=", ink.texture != null)
		print("[EncounterTransition] node=BlackOverlay visible=", black.visible, " z_index=", black.z_index, " modulate=", black.modulate)
		print("[EncounterTransition] node=WarLabel visible=", war_label.visible, " z_index=", war_label.z_index, " modulate=", war_label.modulate)

	var sfx := AudioStreamPlayer.new()
	sfx.bus = "Master"
	sfx.stream = load(ENCOUNTER_IMPACT_SFX_PATH)
	layer.add_child(sfx)
	if sfx.stream:
		sfx.play()
	else:
		push_warning("❗ 找不到遭遇轉場音效：%s" % ENCOUNTER_IMPACT_SFX_PATH)

	await get_tree().create_timer(0.08).timeout
	var t1 := create_tween()
	t1.tween_property(black, "color:a", 0.45, 0.18)
	t1.parallel().tween_property(ink, "modulate:a", 0.50, 0.18)
	t1.parallel().tween_property(war_label, "modulate:a", 1.0, 0.20)
	if cam:
		t1.parallel().tween_property(cam, "zoom", base_zoom * ENCOUNTER_ZOOM_SCALE, ENCOUNTER_ZOOM_DURATION)
	await t1.finished

	var flash := create_tween()
	flash.tween_property(white, "color:a", 0.72, 0.08)
	flash.tween_property(white, "color:a", 0.0, 0.16)
	var ink_breath := create_tween()
	ink_breath.tween_property(ink, "modulate:a", 0.30, 0.26)

	await get_tree().create_timer(ENCOUNTER_WAR_HOLD_DURATION).timeout
	var t2 := create_tween()
	t2.tween_property(war_label, "modulate:a", 0.0, ENCOUNTER_WAR_FADE_DURATION)
	t2.parallel().tween_property(black, "color:a", 1.0, ENCOUNTER_WAR_FADE_DURATION)
	t2.parallel().tween_property(ink, "modulate:a", 0.30, ENCOUNTER_WAR_FADE_DURATION)
	if cam:
		t2.parallel().tween_property(cam, "zoom", base_zoom, ENCOUNTER_WAR_FADE_DURATION)
	await t2.finished

	layer.queue_free()
	_encounter_transition_playing = false

func _resolve_encounter_transition_style(enemies: Array) -> Dictionary:
	var counts := {}
	for enemy_any in enemies:
		if typeof(enemy_any) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_any
		var archetype := str(enemy.get("archetype", ""))
		var style_key := str(ENCOUNTER_STYLE_BY_ARCHETYPE.get(archetype, "default"))
		counts[style_key] = int(counts.get(style_key, 0)) + 1

	var selected_key := "default"
	var selected_count := -1
	for key_any in counts.keys():
		var key := str(key_any)
		var c := int(counts[key_any])
		if c > selected_count:
			selected_key = key
			selected_count = c

	var profile: Dictionary = ENCOUNTER_STYLE_PROFILES.get(selected_key, ENCOUNTER_STYLE_PROFILES["default"])
	var glyphs: Array = profile.get("glyphs", ["戰"])
	var colors: Array = profile.get("colors", [Color(0.95, 0.18, 0.16, 1.0)])
	var glyph := "戰"
	if not glyphs.is_empty():
		glyph = str(glyphs[_encounter_rng.randi_range(0, glyphs.size() - 1)])
	var color := Color(0.95, 0.18, 0.16, 1.0)
	if not colors.is_empty():
		var picked_color = colors[_encounter_rng.randi_range(0, colors.size() - 1)]
		if typeof(picked_color) == TYPE_COLOR:
			color = picked_color

	var glyph_texture_paths: Dictionary = profile.get("glyph_texture_paths", {})
	var generic_texture_path := str(profile.get("generic_texture_path", ENCOUNTER_STYLE_DEFAULT_TEXTURE))
	var texture_path := str(glyph_texture_paths.get(glyph, generic_texture_path))
	if texture_path == "":
		texture_path = ENCOUNTER_STYLE_DEFAULT_TEXTURE

	var result := {
		"style_key": selected_key,
		"glyph": glyph,
		"font_color": color,
		"texture_path": texture_path
	}
	if ENCOUNTER_DEBUG_LOG:
		print("[EncounterStyle] archetype_counts=", counts, " selected=", selected_key, " glyph=", glyph, " texture=", texture_path)
	return result
