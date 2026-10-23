extends CanvasLayer
# 全遊戲的軟體游標（autoload：GameCursor）。畫在最上層，跟著滑鼠；系統游標隱藏。
#   待機（沒按滑鼠）  金色矛頭＋紅流蘇（一張圖，流蘇不動）
#   移動（左鍵按住）  矛頭（無流蘇）＋獨立流蘇：永遠垂在下方、鐘擺式慢速擺動，滑鼠加速時略為甩動
#   奔跑（右鍵按住）  亮色矛頭＋流蘇：依滑鼠「反方向」飄，速度越快越接近水平，像旗子一樣抖動
#   可互動的目標上   對話框 / 手：兩幀每 0.6 秒交替（一個循環 1.2 秒）
# 所有素材：assets/UI/cursor/，2 倍解析度，節點縮放 0.5。缺素材時自動退回系統游標。

const DIR := "res://assets/UI/cursor/"
const ART_SCALE := 0.5

## 箭頭尖端（熱點）、流蘇掛點與流蘇轉軸，單位：素材像素（由素材實測）
const ARROW_HOTSPOT := Vector2(3, 3)
const RING_ANCHOR := Vector2(61, 69)         # 無流蘇矛頭上，掛流蘇的小環
const TASSEL_PIVOT_MOVE := Vector2(17, 8)    # 流蘇最上面那顆珠子
const TASSEL_PIVOT_RUN := Vector2(22, 8)
## 兩幀圖示：[frame_a, frame_b, 熱點在「左下角起算」的位置（x, 距底部）]
const ICONS := {
	"talk": {"a": "cursor_talk_a", "b": "cursor_talk_b", "hot": Vector2(13, 3)},
	# 想對話、但劉語塵還沒走進蛋白區：靴子往對話框走（兩格走路動畫，比對話框的閃光快）
	"talk_walk": {"a": "cursor_talk_walk_a", "b": "cursor_talk_walk_b", "hot": Vector2(11, 34), "sec": 0.3},
	# 出口：滑鼠在出口的蛋黃區。劉語塵已在蛋白區＝箭頭指向開啟的門；還沒走到＝靴子走向門
	"exit": {"a": "cursor_exit_a", "b": "cursor_exit_b", "hot": Vector2(47, 30), "sec": 0.45},
	"exit_walk": {"a": "cursor_exit_walk_a", "b": "cursor_exit_walk_b", "hot": Vector2(47, 30), "sec": 0.3},
	"inspect": {"a": "cursor_inspect_a", "b": "cursor_inspect_b", "hot": Vector2(24, 88)},
}
const ICON_FRAME_SEC := 0.6

# 流蘇物理參數
const MOVE_OMEGA2 := 7.0        # 鐘擺自然頻率²：值小＝擺得慢（約 2.4 秒一個來回）
const MOVE_DAMP := 1.6
const MOVE_COUPLING := 0.0016   # 滑鼠水平加速度 → 角加速度
const MOVE_MAX_ANGLE := 1.15    # ±66°，永遠在下半部
const RUN_FULL_SPEED := 500.0   # 滑鼠速度到這個值時流蘇幾乎水平
const RUN_FOLLOW := 14.0        # 流蘇朝目標方向的跟隨速度
const RUN_BASE_STREAM := 0.88      # 奔跑時流蘇「順風飄」的程度（1＝完全水平，0＝垂下）
## 撞球桿式轉向：移動/奔跑時，矛頭的角度由「游標」相對「劉語塵（畫面位置）」的方位決定，尖端朝外（領著他走）；
## 轉軸在矛頭柄（掛流蘇的小環）；柄的位置固定在「待機時柄所在的地方」，所以按下滑鼠不會平移，只是繞著柄轉。要改成尖端朝向劉語塵，把下面這個改成 true。
const TIP_TOWARD_PLAYER := false
const MIN_AIM_DISTANCE := 4.0      # 游標離劉語塵太近時方位不穩，維持原角度

var follow: Node2D
var arrow: Sprite2D
var tassel: Sprite2D
var icon: Sprite2D
var _tex := {}
var _ready_ok := false
var _mouse_pos := Vector2.ZERO
var _prev_mouse := Vector2.ZERO
var _mouse_vel := Vector2.ZERO
var _vel_smooth := Vector2.ZERO
var _prev_vel := Vector2.ZERO
var _theta := 0.0
var _omega := 0.0
var _run_axis := Vector2.DOWN
var _t := 0.0
var _tip_dir := Vector2.RIGHT   # 目前矛頭尖端朝向（劉語塵前進的方向）；奔跑時流蘇朝它的反方向飄
var _arrow_rot := 0.0
var _target_rot := 0.0
var _last_aim_rot := 0.0   # 最後一次「還在追」時的矛頭角度；劉語塵停下後矛頭維持這個方向
var _hover_kind := ""
var _state := "idle"
## 測試用：不是 null 時當作滑鼠位置（headless 沒有真的滑鼠）
var mouse_override: Variant = null
var left_override: Variant = null
var right_override: Variant = null
var chasing_override: Variant = null   # 測試用：不是 null 時當作「劉語塵正在追滑鼠（還沒追上）」
var intent_override: Variant = null    # 測試用：不是 null 時當作「這次按住有移動意圖」
var player_screen_override: Variant = null   # 測試用：不是 null 時當作劉語塵在畫面上的位置

func _ready() -> void:
	layer = 4096
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in ["cursor_idle", "cursor_move", "cursor_run", "tassel_move", "tassel_run", "cursor_talk_a", "cursor_talk_b", "cursor_talk_walk_a", "cursor_talk_walk_b", "cursor_exit_a", "cursor_exit_b", "cursor_exit_walk_a", "cursor_exit_walk_b", "cursor_inspect_a", "cursor_inspect_b"]:
		var p := "%s%s.png" % [DIR, n]
		if not ResourceLoader.exists(p):
			push_warning("GameCursor: missing %s — falling back to the system cursor" % p)
			return
		_tex[n] = load(p)
	_ready_ok = true
	follow = Node2D.new()
	follow.name = "Follow"
	follow.scale = Vector2.ONE * ART_SCALE
	add_child(follow)
	arrow = Sprite2D.new()
	arrow.name = "Arrow"
	arrow.centered = false
	follow.add_child(arrow)
	# 流蘇畫在矛頭前面：矛頭尖端朝下時，垂下的流蘇才不會被矛頭擋住
	tassel = Sprite2D.new()
	tassel.name = "Tassel"
	tassel.centered = false
	tassel.visible = false
	follow.add_child(tassel)
	icon = Sprite2D.new()
	icon.name = "Icon"
	icon.centered = false
	icon.visible = false
	follow.add_child(icon)
	for s in [tassel, arrow, icon]:
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_apply_state("idle")

func is_active() -> bool:
	return _ready_ok

## 由 InteractionResolver 呼叫：目前滑鼠下的互動目標種類（""＝沒有）
func set_hover_kind(kind: String) -> void:
	_hover_kind = kind

func _has_intent() -> bool:
	if intent_override != null:
		return bool(intent_override)
	var resolver := get_node_or_null("/root/InteractionResolver")
	return resolver != null and resolver.has_method("has_mouse_move_intent") and bool(resolver.has_mouse_move_intent())

func _is_chasing() -> bool:
	if chasing_override != null:
		return bool(chasing_override)
	var resolver := get_node_or_null("/root/InteractionResolver")
	return resolver != null and resolver.has_method("is_chasing_mouse") and bool(resolver.is_chasing_mouse())

func _left_down() -> bool:
	return bool(left_override) if left_override != null else Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func _right_down() -> bool:
	return bool(right_override) if right_override != null else Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

func _process(delta: float) -> void:
	if not _ready_ok:
		return
	_t += delta
	_mouse_pos = mouse_override if mouse_override is Vector2 else get_viewport().get_mouse_position()
	follow.position = _mouse_pos
	if delta > 0.0:
		_mouse_vel = (_mouse_pos - _prev_mouse) / delta
	_prev_mouse = _mouse_pos
	_vel_smooth = _vel_smooth.lerp(_mouse_vel, clampf(delta * 12.0, 0.0, 1.0))

	# 按住且有移動意圖才用移動/奔跑樣式（被鎖定、在選單上按下則維持待機）。
	# 劉語塵追上滑鼠停下來時樣式不變：矛頭停在最後的方向，等滑鼠再移開又繼續轉（不會像彈珠台那樣彈回待機）。
	var wanted := "idle"
	if _hover_kind.ends_with("_walk") and ICONS.has(_hover_kind):
		wanted = "icon"   # 朝著可對話的人走過去（含按住追他的途中）：不管有沒有按住，都維持「靴子走向對話框」
	elif (_right_down() or _left_down()) and _has_intent():
		wanted = "run" if _right_down() else "move"
	elif _hover_kind != "" and ICONS.has(_hover_kind):
		wanted = "icon"
	if wanted != _state:
		_apply_state(wanted)

	_update_arrow_rotation(delta)
	match _state:
		"icon": _update_icon()
		"move": _update_move_tassel(delta)
		"run": _update_run_tassel(delta)
	_prev_vel = _vel_smooth

func _apply_state(new_state: String) -> void:
	_state = new_state
	_arrow_rot = 0.0
	arrow.rotation = 0.0
	arrow.position = Vector2.ZERO
	arrow.visible = new_state != "icon"
	icon.visible = new_state == "icon"
	tassel.visible = new_state == "move" or new_state == "run"
	match new_state:
		"idle":
			_set_arrow("cursor_idle", ARROW_HOTSPOT)   # 待機：尖端在滑鼠位置，角度不變
		"move":
			_set_arrow("cursor_move", RING_ANCHOR)     # 移動：轉軸在矛頭柄；柄的位置和待機時完全一樣（不會平移）
			arrow.position = RING_ANCHOR - ARROW_HOTSPOT
			tassel.texture = _tex["tassel_move"]
			tassel.offset = -TASSEL_PIVOT_MOVE
			tassel.scale = Vector2.ONE
			_theta = 0.0
			_omega = 0.0
		"run":
			_set_arrow("cursor_run", RING_ANCHOR)
			arrow.position = RING_ANCHOR - ARROW_HOTSPOT
			tassel.texture = _tex["tassel_run"]
			tassel.offset = -TASSEL_PIVOT_RUN
			_run_axis = Vector2.DOWN
		"icon":
			_t = 0.0   # 圖示從第 1 幀開始播

## 劉語塵目前在畫面上的位置（viewport 座標）；找不到時回傳 null
func _player_screen_pos() -> Variant:
	if player_screen_override is Vector2:
		return player_screen_override
	var player := get_node_or_null("/root/GameRoot/LiuYu") as Node2D
	if player == null or not player.is_inside_tree():
		return null
	# 用身體中心（肚子），和劉語塵追隨滑鼠的參考點相同；世界座標 → 畫面座標
	return player.get_canvas_transform() * InteractionGeometry.body_center(player)

## 矛頭角度：尖端方向 = 劉語塵 → 滑鼠 的方位（連續角度，不是八方向）。
func _aim_rotation() -> Variant:
	var p = _player_screen_pos()
	if p == null:
		return null
	# 滑鼠是基準：角度只看「劉語塵（肚子）→ 滑鼠」，與游標圖形的柄位置無關
	var to_cursor: Vector2 = _mouse_pos - (p as Vector2)
	if to_cursor.length() < MIN_AIM_DISTANCE:
		return null
	var tip_dir := to_cursor.angle() + (PI if TIP_TOWARD_PLAYER else 0.0)
	_tip_dir = Vector2.from_angle(tip_dir)
	# 素材：從柄（小環）到尖端的方向
	var base_angle := (ARROW_HOTSPOT - RING_ANCHOR).angle()
	return wrapf(tip_dir - base_angle, -PI, PI)

## 按下的那一刻就轉到位（_apply_state 呼叫），之後按住期間每一幀跟著游標與劉語塵的相對位置連續轉動。
func _update_arrow_rotation(_delta: float) -> void:
	if _state == "move" or _state == "run":
		# 還在追（身體中心離滑鼠超出死區）才更新角度；追上之後凍結在最後的方向
		if _is_chasing():
			var r = _aim_rotation()
			if r != null:
				_last_aim_rot = r
		_arrow_rot = _last_aim_rot
	else:
		_arrow_rot = 0.0
	arrow.rotation = _arrow_rot
	# 流蘇掛在柄上，柄就是轉軸，所以流蘇固定在滑鼠位置；流蘇本身的擺動仍是「世界方向」
	tassel.position = arrow.position

## 剛進入移動/奔跑：立刻轉到正確角度（不經過任何轉動過程）
func _snap_rotation() -> void:
	if _is_chasing():
		var r = _aim_rotation()
		if r != null:
			_last_aim_rot = r
	_arrow_rot = _last_aim_rot
	arrow.rotation = _arrow_rot

func _set_arrow(tex_name: String, pivot: Vector2) -> void:
	arrow.texture = _tex[tex_name]
	arrow.offset = -pivot

func _update_icon() -> void:
	var def: Dictionary = ICONS[_hover_kind]
	var frame_b := int(floor(_t / float(def.get("sec", ICON_FRAME_SEC)))) % 2 == 1
	var tex: Texture2D = _tex[def["b"] if frame_b else def["a"]]
	icon.texture = tex
	# 兩幀的畫布大小不同（第二幀多了閃光），所以以「左下角」對齊，熱點用「離底部的距離」
	var hot: Vector2 = def["hot"]
	icon.offset = Vector2(-hot.x, -(float(tex.get_height()) - hot.y))

## 移動：鐘擺。永遠在矛頭下方（角度被限制在 ±66°），擺得慢；滑鼠水平加速度會把它甩一下。
func _update_move_tassel(delta: float) -> void:
	var accel_x := (_vel_smooth.x - _prev_vel.x) / maxf(delta, 0.0001)
	var alpha := -MOVE_OMEGA2 * sin(_theta) - MOVE_DAMP * _omega + accel_x * MOVE_COUPLING
	_omega += alpha * delta
	_theta = clampf(_theta + _omega * delta, -MOVE_MAX_ANGLE, MOVE_MAX_ANGLE)
	if absf(_theta) >= MOVE_MAX_ANGLE:
		_omega *= 0.5
	tassel.rotation = _theta

## 奔跑：像被「與前進方向相反的風」吹著，流蘇整段時間都朝矛頭尖端的反方向飄（不論滑鼠有沒有在動），並帶著旗子般的快速抖動。
## 只有走路（移動）才是垂在下方的鐘擺。滑鼠本身移動得快時，飄得更平一點。
func _update_run_tassel(delta: float) -> void:
	var s := clampf(RUN_BASE_STREAM + _vel_smooth.length() / RUN_FULL_SPEED * 0.1, 0.0, 0.97)
	var target := (-_tip_dir * s + Vector2.DOWN * (1.0 - s)).normalized()
	_run_axis = _run_axis.lerp(target, clampf(delta * RUN_FOLLOW, 0.0, 1.0)).normalized()
	var flutter := sin(_t * 22.0) * 0.16 * (0.4 + s) + sin(_t * 37.0 + 1.3) * 0.07 * s
	tassel.rotation = atan2(-_run_axis.x, _run_axis.y) + flutter
	# 素材的流蘇尖端向右彎；往右飄時鏡像，讓彎勢順著風向
	tassel.scale = Vector2(-1.0 if _run_axis.x > 0.0 else 1.0, 1.0 + sin(_t * 26.0) * 0.05 * s)
