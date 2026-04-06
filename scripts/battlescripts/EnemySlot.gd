extends HBoxContainer

const BATTLE_SLOT_FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const ENEMY_NAME_MIN_HEIGHT := 23.5
const ENEMY_HP_MIN_HEIGHT := 23.0
const ENEMY_ELEMENT_MIN_HEIGHT := 23.0
const ENEMY_HPBAR_MIN_HEIGHT := 25.0
const ENEMY_SPACER_MIN_HEIGHT := 14.0

@onready var portrait      : TextureRect      = $Portrait
@onready var status_ui     : VBoxContainer    = $StatusUI
@onready var name_label    : Label            = $StatusUI/Name
@onready var hp_bar        : ProgressBar      = $StatusUI/HPBar
@onready var hp_label      : Label            = $StatusUI/HPLabel
@onready var element_label : Label            = $StatusUI/ElementLabel
@onready var status_spacer : Control          = $StatusUI/Control
@onready var fx_hit        : AnimatedSprite2D = $FxHit   # 💥 被擊中特效

var actor_id: String = ""
var max_hp_cached: int = 0

var _turn_tween: Tween   = null   # ⭐ 輪到這隻敵人行動時的呼吸高亮
var _target_tween: Tween = null   # ⭐ 被選成目標時的確認閃爍
var _dodge_tween: Tween = null

func _ready() -> void:
	_reset_fx()
	_apply_enemy_label_style()
	_lock_status_layout_metrics()
	if name_label:
		name_label.clip_text = true
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if status_ui:
		status_ui.size_flags_horizontal = Control.SIZE_FILL
	if fx_hit and not fx_hit.animation_finished.is_connected(_on_fx_hit_finished):
		fx_hit.animation_finished.connect(_on_fx_hit_finished)

func _lock_status_layout_metrics() -> void:
	if name_label:
		name_label.custom_minimum_size = Vector2(name_label.custom_minimum_size.x, ENEMY_NAME_MIN_HEIGHT)
	if hp_label:
		hp_label.custom_minimum_size = Vector2(hp_label.custom_minimum_size.x, ENEMY_HP_MIN_HEIGHT)
	if status_spacer:
		status_spacer.custom_minimum_size = Vector2(status_spacer.custom_minimum_size.x, ENEMY_SPACER_MIN_HEIGHT)
	if element_label:
		element_label.custom_minimum_size = Vector2(element_label.custom_minimum_size.x, ENEMY_ELEMENT_MIN_HEIGHT)
	if hp_bar:
		hp_bar.custom_minimum_size = Vector2(hp_bar.custom_minimum_size.x, ENEMY_HPBAR_MIN_HEIGHT)

func _apply_enemy_label_style() -> void:
	for label in [name_label, hp_label, element_label]:
		if label == null:
			continue
		label.add_theme_font_override("font", BATTLE_SLOT_FONT)
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		label.add_theme_constant_override("outline_size", 4)

func setup_from_actor(actor: Dictionary) -> void:
	actor_id = str(actor.get("id", actor.get("name", "")))
	_lock_status_layout_metrics()
	_init_max_hp(actor)
	_update_all(actor)
	_reset_fx()

	# 初始顏色也歸零，避免上一隻怪的特效殘留
	self.modulate = Color(1, 1, 1, 1)
	if portrait:
		portrait.modulate = Color(1, 1, 1, 1)

func update_from_actor(actor: Dictionary) -> void:
	_lock_status_layout_metrics()
	var new_id = str(actor.get("id", actor.get("name", "")))
	if new_id != "" and new_id != actor_id:
		actor_id = new_id
		_init_max_hp(actor)
	_update_all(actor)

func _init_max_hp(actor: Dictionary) -> void:
	var cur_hp: int = int(actor.get("hp", 0))
	var m: int = int(actor.get("max_hp", cur_hp))

	if m <= 0:
		m = max(cur_hp, 1)
		push_warning("敵人 %s 缺少 max_hp，暫以當前 hp 當上限。" % actor.get("name", "???"))

	max_hp_cached = m

func _update_all(actor: Dictionary) -> void:
	name_label.text = str(actor.get("display_name", actor.get("name", "???")))

	var cur_hp: int = int(actor.get("hp", 0))
	if cur_hp < 0:
		cur_hp = 0

	if max_hp_cached <= 0:
		_init_max_hp(actor)

	hp_bar.max_value = max_hp_cached
	hp_bar.value = clamp(cur_hp, 0, max_hp_cached)
	hp_label.text = "生命值: %d / %d" % [cur_hp, max_hp_cached]

	var elem = str(actor.get("element", "未知"))
	if elem == "":
		elem = "未知"

	element_label.text = "屬性：%s" % elem
	var color = _get_element_color(elem)
	element_label.add_theme_color_override("font_color", color)

	var portrait_path = actor.get("portrait_path", "")
	if portrait_path != "":
		var tex = load(portrait_path)
		if tex:
			portrait.texture = tex

func _get_element_color(element: String) -> Color:
	match element:
		"快":
			return Color8(79, 195, 247)
		"剛":
			return Color8(255, 183, 77)
		"柔":
			return Color8(244, 143, 177)
		"遲":
			return Color8(179, 157, 219)
		_:
			return Color.WHITE

func clear_slot() -> void:
	actor_id = ""
	max_hp_cached = 0

	# 把高亮 / tween 都清掉
	if _turn_tween:
		_turn_tween.kill()
		_turn_tween = null
	if _target_tween:
		_target_tween.kill()
		_target_tween = null

	self.modulate = Color(1, 1, 1, 1)
	if portrait:
		portrait.modulate = Color(1, 1, 1, 1)

	name_label.text = ""
	hp_label.text = ""
	element_label.text = ""
	element_label.add_theme_color_override("font_color", Color.WHITE)

	hp_bar.max_value = 1
	hp_bar.value = 0
	portrait.texture = null
	_reset_fx()


# ===== FX：被打時播放的特效 =====

func _reset_fx() -> void:
	if fx_hit:
		fx_hit.visible = false
		fx_hit.stop()

func _on_fx_hit_finished() -> void:
	if fx_hit:
		fx_hit.visible = false
		fx_hit.stop()

func play_hit_fx(effect: String) -> void:
	if fx_hit == null:
		return
	if fx_hit.sprite_frames == null:
		return
	if not fx_hit.sprite_frames.has_animation(effect):
		push_warning("EnemySlot: Hit FX animation not found: %s" % effect)
		return

	# 播一次就好
	fx_hit.sprite_frames.set_animation_loop(effect, false)

	fx_hit.visible = true
	fx_hit.frame = 0
	fx_hit.play(effect)


# ===== 目標高亮：被選成攻擊目標時，整個 slot 持續閃爍 =====
func set_target_highlight(is_active: bool) -> void:
	if _target_tween:
		_target_tween.kill()
		_target_tween = null

	if not is_active:
		self.modulate = Color(1, 1, 1, 1)
		return

	self.modulate = Color(1, 1, 1, 1)

	_target_tween = create_tween()
	_target_tween.set_loops()  # ⭐ 一直亮亮暗暗，直到你說關

	_target_tween.tween_property(
		self, "modulate",
		Color(1.4, 1.4, 1.4, 1.0),  # 微亮
		0.4
	)
	_target_tween.tween_property(
		self, "modulate",
		Color(1, 1, 1, 1.0),        # 回到正常
		0.4
	)

# ⭐ 給 BattleUI 用的 alias（如果還沒加的話）
func set_target_focus(is_active: bool) -> void:
	set_target_highlight(is_active)

# ===== 回合高亮：輪到這個敵人行動時，頭像白色緩慢閃爍 =====

func set_turn_highlight(is_active: bool) -> void:
	if _turn_tween:
		_turn_tween.kill()
		_turn_tween = null

	if portrait == null:
		return

	if not is_active:
		portrait.modulate = Color(1, 1, 1, 1)
		return

	portrait.modulate = Color(1, 1, 1, 1)

	_turn_tween = create_tween()
	_turn_tween.set_loops()

	_turn_tween.tween_property(
		portrait, "modulate",
		Color(1, 1, 1, 0.6),
		0.6
	)
	_turn_tween.tween_property(
		portrait, "modulate",
		Color(1, 1, 1, 1.0),
		0.6
	)


# ===== 攻擊 / 受擊動作 =====

func play_attack_motion() -> void:
	var tween = create_tween()
	self.scale = Vector2.ONE
	tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.12)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.16)

func play_dodge_motion() -> void:
	if _dodge_tween:
		_dodge_tween.kill()
		_dodge_tween = null
	var start_pos := self.position
	var dodge_pos := start_pos + Vector2(-24, 0)
	_dodge_tween = create_tween()
	_dodge_tween.tween_property(self, "position", dodge_pos, 0.08)
	_dodge_tween.tween_interval(0.8)
	_dodge_tween.tween_property(self, "position", start_pos, 0.32)

func play_damage_react() -> void:
	var tween = create_tween()
	var original_modulate = self.modulate

	self.modulate = Color(1.2, 0.6, 0.6, original_modulate.a)
	self.scale = Vector2.ONE

	tween.tween_property(self, "scale", Vector2(0.92, 0.92), 0.12)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.16)
	tween.tween_callback(
		func () -> void:
			self.modulate = original_modulate
	)

# ===== 防禦姿態（預留給敵人）=====
func play_defend_pose() -> void:
	var tween = create_tween()
	var original_modulate = self.modulate

	self.scale = Vector2.ONE
	self.modulate = original_modulate

	tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.12)
	tween.tween_property(self, "modulate", Color(0.8, 0.9, 1.2, original_modulate.a), 0.12)
	tween.tween_callback(
		func ():
			self.modulate = Color(0.9, 0.95, 1.1, original_modulate.a)
	)

func clear_defend_pose() -> void:
	self.scale = Vector2.ONE
	self.modulate = Color(1, 1, 1, 1)

func play_guard_react() -> void:
	var tween = create_tween()
	var original_modulate = self.modulate
	var a = original_modulate.a

	self.scale = Vector2.ONE
	self.modulate = Color(0.8, 0.9, 1.4, a)

	# 敵人我讓他往右抖一下，你可以改數字
	tween.tween_property(self, "position", position + Vector2(6, 0), 0.06)
	tween.tween_property(self, "position", position, 0.08)
	tween.tween_callback(
		func ():
			self.modulate = Color(0.9, 0.95, 1.1, a)
	)
