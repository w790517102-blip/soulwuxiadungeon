extends HBoxContainer

# 🧩 抓節點
@onready var portrait   : TextureRect      = $Portrait
@onready var status_ui  : VBoxContainer    = $StatusUI
@onready var name_label : Label            = $StatusUI/Name
@onready var hp_bar     : ProgressBar      = $StatusUI/HPBar
@onready var hp_label   : Label            = $StatusUI/HPLabel
@onready var mp_bar     : ProgressBar      = $StatusUI/MPBar
@onready var mp_label   : Label            = $StatusUI/MPLabel
@onready var fx_hit     : AnimatedSprite2D = $FxHit   # 💥 被擊中特效

var actor_id: String = ""
var _base_scale: Vector2 = Vector2.ONE   # 目前這個 slot 的「基準大小」
var _turn_tween: Tween   = null   # ⭐ 輪到自己行動時的白色呼吸
var _target_tween: Tween = null   # ⭐ 被選為目標時的確認閃爍

func _ready() -> void:
	_base_scale = self.scale
	_reset_fx()
	if fx_hit and not fx_hit.animation_finished.is_connected(_on_fx_hit_finished):
		fx_hit.animation_finished.connect(_on_fx_hit_finished)

# 戰鬥開始時第一次塞資料用
func setup_from_actor(actor: Dictionary) -> void:
	actor_id = str(actor.get("id", actor.get("name", "")))
	_update_all(actor)
	_reset_fx()
	# 保險：顏色也重置
	self.modulate = Color(1, 1, 1, 1)
	if portrait:
		portrait.modulate = Color(1, 1, 1, 1)

# 每回合／受傷／回復時更新
func update_from_actor(actor: Dictionary) -> void:
	_update_all(actor)

# 🔧 內部共用：同步名字＋頭像＋HP/MP＋Label
func _update_all(actor: Dictionary) -> void:
	# 名稱
	name_label.text = str(actor.get("display_name", actor.get("name", "???")))

	# --- HP ---
	var cur_hp: int = int(actor.get("hp", 0))
	var max_hp: int = int(actor.get("max_hp", cur_hp))  # 沒寫 max_hp 就用目前值當上限
	if max_hp <= 0:
		max_hp = 1

	hp_bar.max_value = max_hp
	hp_bar.value = clamp(cur_hp, 0, max_hp)
	hp_label.text = "生命值: %d / %d" % [cur_hp, max_hp]

	# 🩸 氣絕狀態：名字變成深灰色
	if cur_hp <= 0:
		name_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
	else:
		name_label.add_theme_color_override("font_color", Color(1, 1, 1))

	# --- MP / 內力 ---
	var cur_mp: int = int(actor.get("mp", 0))
	var max_mp: int = int(actor.get("max_mp", cur_mp))
	if max_mp < 0:
		max_mp = 0

	mp_bar.max_value = max_mp if max_mp > 0 else 1
	mp_bar.value = clamp(cur_mp, 0, mp_bar.max_value)
	mp_label.text = "內力值: %d / %d" % [cur_mp, mp_bar.max_value]

	# --- 頭像 ---
	var portrait_path = actor.get("portrait_path", "")
	if portrait_path != "":
		var tex := load(portrait_path)
		if tex:
			portrait.texture = tex


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
		push_warning("TeamMateSlot: Hit FX animation not found: %s" % effect)
		return

	# 保險：關掉 loop，播一次就好
	fx_hit.sprite_frames.set_animation_loop(effect, false)

	fx_hit.visible = true
	fx_hit.frame = 0
	fx_hit.play(effect)

func play_guard_fx() -> void:
	if fx_hit == null:
		return
	if fx_hit.sprite_frames == null:
		return
	
	var anim := "GuardShield"   # 👈 你 AnimatedSprite2D 裡的動畫名稱
	if not fx_hit.sprite_frames.has_animation(anim):
		push_warning("TeamMateSlot: GuardShield animation not found")
		return
	
	# 播一次就好
	fx_hit.sprite_frames.set_animation_loop(anim, false)
	fx_hit.visible = true
	fx_hit.frame = 0
	fx_hit.play(anim)

# ===== 回合高亮：輪到這個角色行動時，頭像白色緩慢閃爍 =====
func set_turn_highlight(is_active: bool) -> void:
	if _turn_tween:
		_turn_tween.kill()
		_turn_tween = null

	if portrait == null:
		return

	if not is_active:
		# 關閉高亮：還原顏色（注意：不動 self.modulate，避免影響 target 閃爍）
		portrait.modulate = Color(1, 1, 1, 1)
		return

	portrait.modulate = Color(1, 1, 1, 1)

	_turn_tween = create_tween()
	_turn_tween.set_loops()  # 無限循環

	# 用 alpha 做淡入淡出
	_turn_tween.tween_property(
		portrait, "modulate",
		Color(1, 1, 1, 0.5),   # 稍微淡掉一點
		0.4
	)
	_turn_tween.tween_property(
		portrait, "modulate",
		Color(1, 1, 1, 1.0),
		0.4
	)

# ===== 目標高亮：被選成攻擊 / 補血目標時，整個 slot 持續閃爍 =====
func set_target_highlight(is_active: bool) -> void:
	if _target_tween:
		_target_tween.kill()
		_target_tween = null

	if not is_active:
		# 關閉目標高亮：還原整個 slot 顏色
		self.modulate = Color(1, 1, 1, 1)
		return

	# 開啟目標高亮：讓整個 slot 做「持續呼吸閃爍」
	self.modulate = Color(1, 1, 1, 1)

	_target_tween = create_tween()
	_target_tween.set_loops()  # ⭐ 關鍵：無限循環，而不是只播一次

	# 變亮一點 → 回到原本亮度
	_target_tween.tween_property(
		self, "modulate",
		Color(1.4, 1.4, 1.4, 1.0),
		0.4
	)
	_target_tween.tween_property(
		self, "modulate",
		Color(1, 1, 1, 1.0),
		0.25
	)

# ⭐ BattleUI 目前叫的是 set_target_focus，所以加一個 alias
func set_target_focus(is_active: bool) -> void:
	set_target_highlight(is_active)


# ===== 攻擊 / 受擊動作（給 BattleUI 叫用）=====

func play_attack_motion() -> void:
	var tween := create_tween()

	# ⭐ 每次攻擊都從「當前基準」開始（可能是 1,1，也可能是 0.92,0.92）
	self.scale = _base_scale
	tween.tween_property(self, "scale", _base_scale * 1.08, 0.12)
	tween.tween_property(self, "scale", _base_scale,          0.16)

func play_damage_react() -> void:
	var tween := create_tween()
	var original_modulate := self.modulate

	self.modulate = Color(1.2, 0.6, 0.6, original_modulate.a)

	# ⭐ 用 _base_scale 當中心縮放，不要再回到 (1,1)
	self.scale = _base_scale
	tween.tween_property(self, "scale", _base_scale * 0.92, 0.12)
	tween.tween_property(self, "scale", _base_scale,          0.16)
	tween.tween_callback(
		func ():
			self.modulate = original_modulate
	)

func play_heal_react() -> void:
	var tween := create_tween()
	var original_modulate := self.modulate

	# ✅ 如果你之後在 FxHit 裡有做 "ItemHeal" 之類的動畫，這裡會順便播
	if fx_hit and fx_hit.sprite_frames and fx_hit.sprite_frames.has_animation("ItemHeal"):
		fx_hit.sprite_frames.set_animation_loop("ItemHeal", false)
		fx_hit.visible = true
		fx_hit.frame = 0
		fx_hit.play("ItemHeal")

	# 綠色微亮 + 微微膨脹，像氣脈回復
	self.scale = _base_scale
	self.modulate = Color(0.7, 1.2, 0.7, original_modulate.a)

	tween.tween_property(self, "scale", _base_scale * 1.06, 0.12)
	tween.tween_property(self, "scale", _base_scale,          0.16)
	tween.tween_callback(
		func () -> void:
			self.modulate = original_modulate
	)

# ===== 防禦姿態：進入防禦時的動畫 =====
func play_defend_pose() -> void:
	# ⭐ 防禦狀態的基準 size
	_base_scale = Vector2(0.92, 0.92)

	var tween := create_tween()
	var original_modulate := self.modulate

	# 從目前大小慢慢縮到 _base_scale
	tween.tween_property(self, "scale", _base_scale, 0.12)
	tween.tween_property(
		self, "modulate",
		Color(0.8, 0.9, 1.8, original_modulate.a),
		0.12
	)
	tween.tween_callback(
		func ():
			# 防禦中的淡藍色
			self.modulate = Color(0.9, 0.95, 1.7, original_modulate.a)
	)
	play_guard_fx()
	
# 防禦結束時（如果之後你想在回合開始清掉）
func clear_defend_pose() -> void:
	_base_scale = Vector2.ONE

	var tween := create_tween()
	tween.tween_property(self, "scale", _base_scale, 0.12)

	self.modulate = Color(1, 1, 1, 1)


# ===== 格擋反應：被打到但有防禦時 =====
func play_guard_react() -> void:
	var tween := create_tween()
	var original_modulate := self.modulate
	var a := original_modulate.a

	# 🛡️ 格檔瞬間，護盾亮一下
	play_guard_fx()

	# 格擋瞬間 → 偏更亮的藍
	self.modulate = Color(0.8, 0.9, 2.0, a)

	# 微微往後抖一下（只動 position）
	var original_pos := position
	tween.tween_property(self, "position", original_pos + Vector2(-6, 0), 0.06)
	tween.tween_property(self, "position", original_pos, 0.08)
	tween.tween_callback(
		func ():
			# 回到防禦中的淡藍色
			self.modulate = Color(0.9, 0.95, 1.7, a)
	)
