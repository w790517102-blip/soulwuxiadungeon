extends CharacterBody2D

const WALK_SPEED = 160
const RUN_SPEED = 400

var last_direction := Vector2(1, 1).normalized()
var direction := Vector2.ZERO
var can_move := true

@onready var animated_sprite := $AnimatedSprite2D
# 若角色腳底位置與 Sprite 原點不同，可調整這個偏移
@export var z_index_offset := 0
@export var random_encounter_enabled := false

const ZONE_ID := "yuheng_bamboo_outskirts"
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

const ENEMY_DB := {
	"bamboo_bandit_scout": {
		"id": "bamboo_bandit_scout",
		"display_name": "山賊探子",
		"hp": 60,
		"max_hp": 60,
		"mp": 10,
		"atk": 10,
		"def": 6,
		"speed": 10,
		"element": "遲"
	},
	"bamboo_bandit_archer": {
		"id": "bamboo_bandit_archer",
		"display_name": "山賊弓手",
		"hp": 50,
		"max_hp": 50,
		"mp": 15,
		"atk": 11,
		"def": 5,
		"speed": 12,
		"element": "巧"
	},
	"bamboo_wild_boar": {
		"id": "bamboo_wild_boar",
		"display_name": "野豬",
		"hp": 90,
		"max_hp": 90,
		"mp": 0,
		"atk": 13,
		"def": 7,
		"speed": 8,
		"element": "剛"
	},
	"bamboo_poison_snake": {
		"id": "bamboo_poison_snake",
		"display_name": "毒蛇",
		"hp": 45,
		"max_hp": 45,
		"mp": 0,
		"atk": 12,
		"def": 4,
		"speed": 14,
		"element": "毒"
	},
	"bamboo_youmei": {
		"id": "bamboo_youmei",
		"display_name": "語魅",
		"hp": 75,
		"max_hp": 75,
		"mp": 20,
		"atk": 12,
		"def": 7,
		"speed": 9,
		"element": "遲"
	},
	"sewer_rat_swarm": {
		"id": "sewer_rat_swarm",
		"display_name": "鼠群",
		"hp": 55,
		"max_hp": 55,
		"mp": 0,
		"atk": 10,
		"def": 5,
		"speed": 13,
		"element": "群"
	},
	"sewer_thug": {
		"id": "sewer_thug",
		"display_name": "下水道匪徒",
		"hp": 85,
		"max_hp": 85,
		"mp": 10,
		"atk": 13,
		"def": 7,
		"speed": 10,
		"element": "剛"
	},
	"sewer_ooze_slime": {
		"id": "sewer_ooze_slime",
		"display_name": "污泥怪",
		"hp": 110,
		"max_hp": 110,
		"mp": 0,
		"atk": 12,
		"def": 9,
		"speed": 6,
		"element": "濁"
	},
	"sewer_drowned_wight": {
		"id": "sewer_drowned_wight",
		"display_name": "溺魂",
		"hp": 120,
		"max_hp": 120,
		"mp": 25,
		"atk": 14,
		"def": 8,
		"speed": 8,
		"element": "陰"
	}
}

const ENCOUNTER_POOLS := {
	"yuheng_bamboo_outskirts": [
		{"w": 40, "enemies": ["bamboo_bandit_scout", "bamboo_bandit_scout"]},
		{"w": 25, "enemies": ["bamboo_bandit_scout", "bamboo_bandit_archer"]},
		{"w": 20, "enemies": ["bamboo_wild_boar"]},
		{"w": 10, "enemies": ["bamboo_poison_snake", "bamboo_poison_snake"]},
		{"w": 5, "enemies": ["bamboo_youmei"]}
	],
	"yuheng_sewer": [
		{"w": 35, "enemies": ["sewer_rat_swarm"]},
		{"w": 30, "enemies": ["sewer_thug", "sewer_thug"]},
		{"w": 20, "enemies": ["sewer_thug", "sewer_rat_swarm"]},
		{"w": 10, "enemies": ["sewer_ooze_slime"]},
		{"w": 5, "enemies": ["sewer_drowned_wight"]}
	]
}

var in_danger_zone := false
var _encounter_distance_accum := 0.0
var _encounter_cooldown_distance := 0.0
var _encounter_rng := RandomNumberGenerator.new()

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
	if _is_battle_active():
		return
	if not in_danger_zone:
		_encounter_distance_accum = 0.0
		return
	if direction == Vector2.ZERO:
		return

	var config = ZONE_CONFIG.get(ZONE_ID, {})
	var distance_threshold = float(config.get("distance_threshold", 0.0))
	var cooldown_distance = float(config.get("cooldown_distance", 0.0))
	var chance = float(config.get("chance", 0.0))

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
	var player_party = TeamData.get_active_party()
	if player_party.is_empty():
		push_warning("❗ 當前隊伍為空，無法啟動遭遇戰。")
		return

	var context = {
		"player_party": player_party,
		"enemy_party": _build_enemies_from_zone(ZONE_ID, ENCOUNTER_POOLS, ENEMY_DB),
		"ruleset": {"id": "default"},
		"regen_policy": {"id": "round_end_mp_regen_default"},
		"tone": {"intro_key": ZONE_CONFIG.get(ZONE_ID, {}).get("intro_key", "default")},
		"zone_id": ZONE_ID
	}

	if context["enemy_party"].is_empty():
		push_warning("❗ Encounter pool 產生空敵人，取消本次遭遇戰。")
		return

	GlobalState.set_meta("pending_battle_context", context)
	var game_root = get_node_or_null("/root/GameRoot")
	if game_root:
		game_root.change_map_to("res://scenes/battle_scene.tscn")
	else:
		push_warning("❗ 找不到 GameRoot，無法切換到戰鬥場景。")
	_encounter_cooldown_distance = float(
		ZONE_CONFIG.get(ZONE_ID, {}).get("cooldown_distance", 0.0)
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
	encounter_pools: Dictionary,
	enemy_db: Dictionary
) -> Array:
	var pool: Array = encounter_pools.get(zone_id, [])
	if pool.is_empty():
		push_warning("Encounter pool empty for zone_id=%s" % zone_id)
		return []

	var picked := _weighted_pick(pool)
	var ids: Array = picked.get("enemies", [])
	var enemies: Array = []

	for enemy_id in ids:
		var base: Dictionary = enemy_db.get(enemy_id, {})
		if base.is_empty():
			push_warning("Enemy not found: %s" % enemy_id)
			continue
		var enemy := base.duplicate(true)
		if not enemy.has("name"):
			enemy["name"] = enemy.get("display_name", enemy_id)
		if not enemy.has("display_name"):
			enemy["display_name"] = enemy.get("name")
		if enemy.has("hp") and not enemy.has("max_hp"):
			enemy["max_hp"] = enemy["hp"]
		enemies.append(enemy)

	return enemies

func _on_danger_zone_body_entered(body: Node2D) -> void:
	if body.name == "LiuYu":
		in_danger_zone = true

func _on_danger_zone_body_exited(body: Node2D) -> void:
	if body.name == "LiuYu":
		in_danger_zone = false
		_encounter_distance_accum = 0.0

func _process(delta):
	if GlobalState.get_meta("menu_open", false):
		return  # 系統選單開啟時不讓角色動
	# 正常移動邏輯
	
	# 角色的 z_index 隨 y 座標更新（整數避免浮點亂序）
	z_index = int(global_position.y + z_index_offset)
