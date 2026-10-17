extends Node

# ------------------------------------------------------------
# 探索模式的中央互動裁決器（Autoload：InteractionResolver）
#
# 責任：
#   1. 所有「已遷移」的普通 NPC 互動（掛了 InteractionTarget 的目標）都經過這裡：一次輸入最多觸發一個互動，
#      而且互動進行中（對話、選項、劇情、黑幕、選單）不接受新的互動。
#   2. 滑鼠：Hover 選目標、游標切換、左鍵按住朝滑鼠方向移動（八方向、放開即停）、鎖定目標靠近後互動。
#   3. 空白鍵：依劉語塵腳底到各目標有效區域的距離選唯一目標。
# 沒有遷移的舊 NPC（自己監聽 Space 的腳本、Area2D 劇情觸發區、傳送入口）不受影響，仍然照舊運作。
#
# 輸入鎖定沿用既有機制，不另外建旗標：劉語塵的 can_move、DialogManager.dialog_active、GlobalState 的 menu_locked／menu_open、
# GameRoot.is_map_transition_locked()、get_tree().paused（系統選單開著時整棵樹暫停）。
# ------------------------------------------------------------

## 滑鼠游標種類 → 游標圖檔（沒有圖檔就用 Godot 內建的游標形狀代替）。圖檔放好之後這裡的路徑就會被用到。
const CURSOR_KINDS := {
	"talk": {"texture": "res://assets/UI/cursor/cursor_talk.png", "hotspot": Vector2(4, 4), "fallback_shape": Input.CURSOR_POINTING_HAND},
	"inspect": {"texture": "res://assets/UI/cursor/cursor_inspect.png", "hotspot": Vector2(4, 4), "fallback_shape": Input.CURSOR_POINTING_HAND},
}
## 滑鼠離劉語塵腳底這麼近就不動（避免角色跨過滑鼠位置後左右抖動）。
const MOUSE_DEAD_ZONE := 14.0
## 兩個目標的滑鼠距離差在這個範圍內，視為一樣近（用優先權與固定順序決定）；已經選中的目標要被超過這個差距才會換掉（不閃爍）。
const TIE_EPSILON := 0.5
const HOVER_HYSTERESIS := 4.0

const PLAYER_PATH := "/root/GameRoot/LiuYu"
const DIALOG_PATH := "/root/GameRoot/DialogManager"

var hovered_target: InteractionTarget = null
var _cursor_kind_shown: String = ""
var _custom_cursor_cache: Dictionary = {}

# 左鍵按住的狀態
var _mouse_down: bool = false
var _mouse_move_active: bool = false
var _locked_target: InteractionTarget = null
var _interaction_running: bool = false


# ------------------------------------------------------------
# 選目標（純函式，方便測試）
# ------------------------------------------------------------
## 滑鼠選目標：比較「滑鼠到目標可見範圍」的距離；在範圍內是 0。距離一樣時依優先權、再依節點路徑（固定排序）。
## previous 是目前已選中的目標：它沒有被別人超過 HOVER_HYSTERESIS 就維持不變（游標微動不會在兩個目標之間閃爍）。
static func pick_hover(world_point: Vector2, targets: Array, previous: InteractionTarget = null) -> InteractionTarget:
	var best: InteractionTarget = null
	var best_distance: float = INF
	for target_any in targets:
		var target := target_any as InteractionTarget
		if target == null or not target.is_available():
			continue
		var distance: float = target.hover_distance(world_point)
		if distance > target.hover_margin:
			continue
		if best == null or _hover_better(distance, target, best_distance, best):
			best = target
			best_distance = distance
	if best != null and previous != null and previous != best and is_instance_valid(previous) and previous.is_available() and targets.has(previous):
		var previous_distance: float = previous.hover_distance(world_point)
		if previous_distance <= previous.hover_margin and previous_distance <= best_distance + HOVER_HYSTERESIS:
			return previous
	return best


static func _hover_better(distance: float, target: InteractionTarget, best_distance: float, best: InteractionTarget) -> bool:
	if absf(distance - best_distance) > TIE_EPSILON:
		return distance < best_distance
	if target.priority != best.priority:
		return target.priority > best.priority
	# 蛋黃區重疊、滑鼠同時在兩個裡面：選畫面上在前面的那個（底邊 y 較大）
	if absf(target.depth_y() - best.depth_y()) > TIE_EPSILON:
		return target.depth_y() > best.depth_y()
	return str(target.get_path()) < str(best.get_path())


## 空白鍵選目標：只看劉語塵現在「能互動」的目標；比較劉語塵腳底到各目標有效區域的距離，近的先。
## 距離差在 TIE_EPSILON 內時，依面向（臉朝向它的先）、優先權、固定順序。
static func pick_keyboard(player: Node2D, facing: Vector2, targets: Array) -> InteractionTarget:
	var feet: Vector2 = InteractionGeometry.feet(player)
	var best: InteractionTarget = null
	var best_distance: float = INF
	var best_facing: float = -2.0
	for target_any in targets:
		var target := target_any as InteractionTarget
		if target == null or not target.is_available() or not target.in_interaction_range(player):
			continue
		if not target.facing_ok(player, facing):
			continue
		var distance: float = target.interaction_distance(player)
		var focus: Vector2 = target.selection_center() if target.require_facing else target.anchor_point()
		var to_target: Vector2 = focus - feet
		var facing_dot: float = 0.0
		if to_target.length() > 0.001 and facing != Vector2.ZERO:
			facing_dot = facing.normalized().dot(to_target.normalized())
		var take: bool = false
		if best == null:
			take = true
		elif absf(distance - best_distance) > TIE_EPSILON:
			take = distance < best_distance
		elif not is_equal_approx(facing_dot, best_facing):
			take = facing_dot > best_facing
		elif target.priority != best.priority:
			take = target.priority > best.priority
		elif absf(target.depth_y() - best.depth_y()) > TIE_EPSILON:
			take = target.depth_y() > best.depth_y()
		else:
			take = str(target.get_path()) < str(best.get_path())
		if take:
			best = target
			best_distance = distance
			best_facing = facing_dot
	return best


# ------------------------------------------------------------
# 環境
# ------------------------------------------------------------
func _player() -> Node2D:
	var player := get_node_or_null(PLAYER_PATH)
	return player if player is Node2D else null


func _dialog_active() -> bool:
	var dialog := get_node_or_null(DIALOG_PATH)
	return dialog != null and bool(dialog.get("dialog_active"))


## 現在能不能接受探索輸入（對話、選單、轉場、劇情控制鎖定中都不行）。
func exploration_input_allowed() -> bool:
	var player := _player()
	if player == null or not player.visible:
		return false
	if get_tree().paused or _interaction_running or _dialog_active():
		return false
	if not bool(player.get("can_move")):
		return false
	var global_state := get_node_or_null("/root/GlobalState")
	if global_state != null and (bool(global_state.get_meta("menu_locked", false)) or bool(global_state.get_meta("menu_open", false))):
		return false
	var game_root := get_node_or_null("/root/GameRoot")
	if game_root != null and game_root.has_method("is_map_transition_locked") and bool(game_root.is_map_transition_locked()):
		return false
	return true


func _targets() -> Array:
	return get_tree().get_nodes_in_group("interaction_target")


## 測試用：不是 null 時當作滑鼠的世界座標（headless 測試沒有真的滑鼠）。
var mouse_world_override: Variant = null


func _mouse_world(player: Node2D) -> Vector2:
	if mouse_world_override is Vector2:
		return mouse_world_override
	return player.get_global_mouse_position()


## 滑鼠現在是不是在「介面」上（對話框、選項、選單、背包）。只算 CanvasLayer 上的 Control：場景裡放在世界座標的 Control（例如蓋住整個房間的 BlackOverlay
## ColorRect，淡出後仍然 visible）不是介面，不能擋住探索的滑鼠操作。
func _gui_has_mouse() -> bool:
	if mouse_world_override is Vector2:
		return false
	var control := get_viewport().gui_get_hovered_control()
	if control == null or control.mouse_filter == Control.MOUSE_FILTER_IGNORE or not control.is_visible_in_tree():
		return false
	return control.get_canvas_layer_node() != null


func _keyboard_move_pressed() -> bool:
	return Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down") \
		or Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right")


# ------------------------------------------------------------
# 輸入
# ------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_on_space_pressed()


func _input(event: InputEvent) -> void:
	# 左鍵放在 _input 處理：它比 GUI 先收到，不會被場景裡放在世界座標的 Control（BlackOverlay 之類）吃掉；
	# 按下時由 _on_left_pressed 自己判斷是不是點在介面上。放開一定要收得到（就算按下之後游標移到了 UI 上）：放開立即停止。
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_left_pressed()
		else:
			_on_left_released()


## 目前的輸入意圖（邏輯狀態，給除錯與測試用）：
##   IDLE               沒有探索輸入。
##   MOVE               按住普通地面，只有移動意圖。
##   INTERACT_APPROACH  點了某個目標的蛋黃區，已鎖定它並且正在靠近。
##   INTERACT_EXECUTE   已符合蛋白區條件，互動剛要開始（唯一的一次）。
##   INTERACTION_LOCKED 對話／選項／劇情／選單／黑幕進行中，不接受新的探索輸入。
func current_intent() -> String:
	if _interaction_running:
		return "INTERACTION_LOCKED" if _dialog_active() else "INTERACT_EXECUTE"
	if not exploration_input_allowed():
		return "INTERACTION_LOCKED"
	if _mouse_move_active:
		return "INTERACT_APPROACH" if _locked_target != null else "MOVE"
	return "IDLE"


func _on_space_pressed() -> void:
	if not exploration_input_allowed():
		return
	var player := _player()
	var target := pick_keyboard(player, player.get("last_direction") as Vector2, _targets())
	if target == null:
		return
	get_viewport().set_input_as_handled()
	_cancel_mouse_intent()
	_run_interaction(target)


## 左鍵按下 = 建立這一次的「意圖」，而且按住期間不會改變：
##   - 按在某個目標的蛋黃區 → INTERACT_APPROACH：鎖定那個目標，靠近到它的蛋白區才互動（只互動它）。
##   - 按在普通地面（沒有目標的蛋黃區）→ MOVE：只移動。之後不管走過多少目標的蛋白區、滑鼠滑進誰的蛋黃區，都還是 MOVE，不會自動變成互動；
##     要互動必須放開之後重新點擊目標的蛋黃區。
## 蛋白區本身從來不觸發任何事：它只是「已經提出互動命令之後，能不能執行」的距離資格。
func _on_left_pressed() -> void:
	_mouse_down = true
	_locked_target = null
	_mouse_move_active = false
	if not exploration_input_allowed() or _gui_has_mouse():
		# 這一次按下不是探索操作（例如在點對話或選單）：這次按住完全不產生移動或互動
		return
	var player := _player()
	_forget_freed_targets()
	_locked_target = pick_hover(_mouse_world(player), _targets(), hovered_target)
	_mouse_move_active = true


func _on_left_released() -> void:
	_mouse_down = false
	_cancel_mouse_intent()
	var player := _player()
	if player != null:
		player.set("mouse_move_direction", Vector2.ZERO)


## 目標被移除（queue_free）之後，手上留著的參考讀起來是 null，但把它當引數傳給有型別的函式還是會出錯（引數仍是失效的物件）；所以用之前一律明確地設成 null。
func _forget_freed_targets() -> void:
	if not is_instance_valid(hovered_target):
		hovered_target = null
	if not is_instance_valid(_locked_target):
		_locked_target = null


func _cancel_mouse_intent() -> void:
	_mouse_move_active = false
	_locked_target = null


# ------------------------------------------------------------
# 每個物理影格：滑鼠移動、靠近互動；每個畫面影格：Hover 與游標
# ------------------------------------------------------------
func _physics_process(_delta: float) -> void:
	var player := _player()
	if player == null:
		return
	if not _mouse_move_active:
		player.set("mouse_move_direction", Vector2.ZERO)
		return
	# 鍵盤優先：開始按 WASD 就放棄滑鼠移動與尚未完成的靠近互動（不讓兩種輸入向量相加）
	if _keyboard_move_pressed() or not _mouse_down:
		player.set("mouse_move_direction", Vector2.ZERO)
		_cancel_mouse_intent()
		return
	if not exploration_input_allowed():
		player.set("mouse_move_direction", Vector2.ZERO)
		return
	# 已經鎖定的目標被移除或變成不能互動：安全取消鎖定，但還是可以繼續往滑鼠方向走
	if _locked_target != null and (not is_instance_valid(_locked_target) or not _locked_target.is_available()):
		_locked_target = null
	# 進入鎖定目標的互動距離：停下、互動一次；這次按住到此為止（放開再按才能再發出下一次意圖）
	if _locked_target != null and _locked_target.in_interaction_range(player):
		var target := _locked_target
		player.set("mouse_move_direction", Vector2.ZERO)
		_mouse_move_active = false
		_locked_target = null
		_run_interaction(target)
		return
	var feet: Vector2 = InteractionGeometry.feet(player)
	var to_mouse: Vector2 = _mouse_world(player) - feet
	if to_mouse.length() <= MOUSE_DEAD_ZONE:
		player.set("mouse_move_direction", Vector2.ZERO)
	else:
		player.set("mouse_move_direction", InteractionGeometry.quantize_8(to_mouse))


func _process(_delta: float) -> void:
	var player := _player()
	if player == null or not exploration_input_allowed() or _gui_has_mouse():
		hovered_target = null
		_show_cursor("")
		return
	_forget_freed_targets()
	hovered_target = pick_hover(_mouse_world(player), _targets(), hovered_target)
	_show_cursor(hovered_target.cursor_kind if hovered_target != null else "")


func _run_interaction(target: InteractionTarget) -> void:
	if _interaction_running or target == null:
		return
	_interaction_running = true
	var player := _player()
	if player != null:
		player.set("mouse_move_direction", Vector2.ZERO)
	_show_cursor("")
	# handler 在這裡（裁決器）等它跑完，不是在目標節點裡等：互動途中目標被移除（例如書眠入隊後離開場景）時，這邊仍然會正常結束，
	# 不會讓「互動進行中」永遠卡住。
	var handler: Callable = target.handler
	if handler.is_valid():
		await handler.call(player)
	if is_instance_valid(target):
		target.interacted.emit(player)
	_interaction_running = false


# ------------------------------------------------------------
# 游標
# ------------------------------------------------------------
func _show_cursor(kind: String) -> void:
	if kind == _cursor_kind_shown:
		return
	_cursor_kind_shown = kind
	if kind == "" or not CURSOR_KINDS.has(kind):
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	var entry: Dictionary = CURSOR_KINDS[kind]
	var texture_path := String(entry.get("texture", ""))
	if texture_path != "" and ResourceLoader.exists(texture_path):
		if not _custom_cursor_cache.has(texture_path):
			_custom_cursor_cache[texture_path] = load(texture_path)
		Input.set_custom_mouse_cursor(_custom_cursor_cache[texture_path], Input.CURSOR_ARROW, entry.get("hotspot", Vector2.ZERO))
	else:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		Input.set_default_cursor_shape(int(entry.get("fallback_shape", Input.CURSOR_POINTING_HAND)))
