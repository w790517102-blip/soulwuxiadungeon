# OverheadChatterByStage_Resource — 左到右打字 + 換行支援
# 變更：
# 1) 打字改用 visible_characters（保證從左到右），避免置中對齊造成「從中間長出」。
# 2) 新增對齊與換行參數：
#    - align_left：強制左對齊（建議開啟）
#    - enable_wrap：啟用自動換行（用 wrap_width_px 設寬度）
#    - wrap_width_px：換行寬度（像素）
#    - 支援在 lines 直接寫 \n 手動換行

extends Label

@export var type_time: float = 0.5
@export var hold_time: float = 3.0
@export var gap_time: float = 0.3
@export var random_gap_jitter: float = 0.15
@export var random_start_index: bool = true

@export var stage_rules: Array[ChatterStageRule] = []

@export var only_when_player_near: bool = true
@export var trigger_distance: float = 320.0
@export var quest_manager_path: NodePath
@export var autoload_name: String = "QuestManager"
@export var refresh_interval: float = 0.5

# ▼ 新增：對齊／換行設定
@export var align_left: bool = true               # 務必左對齊，打字從左到右
@export var enable_wrap: bool = false             # 是否自動換行
@export var wrap_width_px: float = 140.0          # 自動換行寬度（像素）

var _cur_lines: Array[String] = []
var _i: int = 0
var _t: float = 0.0
var _state: int = 0  # 0 typing, 1 hold, 2 gap
var _active: bool = false
var _player: Node2D = null
var _last_stage: int = -999999
var _accum: float = 0.0

# 內部：目前這句完整文字（含 \n）
var _display_text: String = ""

func _ready() -> void:
	# 對齊 & 換行
	if align_left:
		horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if enable_wrap:
		autowrap_mode = TextServer.AUTOWRAP_WORD  # 也可改 AUTOWRAP_ARBITRARY
		custom_minimum_size.x = wrap_width_px
		size.x = wrap_width_px
		clip_text = false
	else:
		autowrap_mode = TextServer.AUTOWRAP_OFF
		clip_text = true

	vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_apply_stage(_get_stage())
	set_process(true)

func _process(delta: float) -> void:
	_accum += delta
	if _accum >= refresh_interval:
		_accum = 0.0
		var st := _get_stage()
		if st != _last_stage:
			_apply_stage(st)

	if not _active:
		return

	if only_when_player_near:
		if _player == null:
			_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player and global_position.distance_to(_player.global_position) > trigger_distance:
			return

	var vis := get_node_or_null("../VisibleOnScreenNotifier2D") as VisibleOnScreenNotifier2D
	if vis and not vis.is_on_screen():
		return

	_t += delta
	match _state:
		0:
			if type_time <= 0.0:
				visible_characters = -1  # 顯示全部
				_state = 1
				_t = 0.0
			else:
				var r: float = clamp(_t / type_time, 0.0, 1.0)
				var total: int = _display_text.length()
				var count: int = int(round(total * r))
				visible_characters = max(0, count)
				if r >= 1.0:
					_state = 1
					_t = 0.0
		1:
			if _t >= hold_time:
				_state = 2
				_t = 0.0
				visible_characters = 0
				text = ""
		2:
			var gap: float = max(0.0, gap_time + randf_range(-random_gap_jitter, random_gap_jitter))
			if _t >= gap:
				_next_index()
				_reset_cycle()

func refresh_from_story() -> void:
	_apply_stage(_get_stage())

func _apply_stage(stage: int) -> void:
	_last_stage = stage
	var rule := _pick_rule(stage)
	if rule == null:
		_set_enabled(false)
		return
	_cur_lines = rule.lines
	_set_enabled(rule.enabled and _cur_lines.size() > 0)
	if _active:
		if random_start_index and _cur_lines.size() > 0:
			_i = randi() % _cur_lines.size()
		else:
			_i = 0
		_reset_cycle()

func _pick_rule(stage: int) -> ChatterStageRule:
	for r in stage_rules:
		if stage >= r.min and stage <= r.max:
			return r
	return null

func _set_enabled(on: bool) -> void:
	_active = on
	visible = on
	if not on:
		text = ""
		visible_characters = 0

func _reset_cycle() -> void:
	_t = 0.0
	_state = 0
	_display_text = _cur_lines[_i] if _cur_lines.size() > 0 else ""
	text = _display_text
	visible_characters = 0

func _next_index() -> void:
	if _cur_lines.size() == 0:
		return
	_i = (_i + 1) % _cur_lines.size()

func _get_stage() -> int:
	var qm: Node = null
	if quest_manager_path != NodePath():
		qm = get_node_or_null(quest_manager_path)
	if qm == null:
		qm = get_node_or_null("/root/%s" % autoload_name)
	if qm and qm.has_method("get_main_quest_state"):
		var state: Dictionary = (qm as Object).call("get_main_quest_state") as Dictionary
		if state.has("stage"):
			return int(state["stage"])
	if qm and qm.has_variable("main_quest"):
		var dq: Dictionary = qm.get("main_quest") as Dictionary
		if dq.has("stage"):
			return int(dq["stage"])
	return 0

# 使用方式：
# - 要「左到右」→ 保持 align_left=true。
# - 要手動換行 → 在 lines 裡寫 "第一行\n第二行"。
# - 要自動換行 → enable_wrap=true，wrap_width_px 設寬度（像素）。
