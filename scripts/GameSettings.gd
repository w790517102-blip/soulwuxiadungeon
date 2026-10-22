extends Node
## 玩家設定（自動載入）：音量（音樂／音效／語音，各有靜音）與畫面（視窗／無框視窗／全螢幕、視窗解析度）。
## 存在玩家本機 user://settings.cfg，與存檔分開。沒有設定檔時完全不動目前的視窗與音量（專案預設無框全螢幕、音量 100%）。
## 音訊匯流排在這裡執行時建立：Music、SFX、Voice。場景裡的播放器若還在 Master，會依名稱自動歸到對應匯流排
## （名稱或上層名稱含 bgm／music → 音樂；含 voice → 語音；其他 → 音效），不需要逐一改場景。

signal settings_changed

const PATH := "user://settings.cfg"
const BUSES := ["Music", "SFX", "Voice"]
const BUS_LABELS := {"Music": "音樂", "SFX": "音效", "Voice": "語音"}
const MODES := ["windowed", "borderless", "fullscreen"]
const MODE_LABELS := {"windowed": "視窗", "borderless": "無框視窗", "fullscreen": "全螢幕"}
const RESOLUTIONS := [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]

var volume := {"Music": 100, "SFX": 100, "Voice": 100}        # 0–100
var muted := {"Music": false, "SFX": false, "Voice": false}
var display_mode := "borderless"
var resolution := Vector2i(1280, 720)
var _has_display_config := false
## 自動指派過匯流排的播放器（除錯與驗收用）：[{path, bus}]
var assigned: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	load_settings()
	apply_audio()
	if _has_display_config:
		apply_display()
	get_tree().node_added.connect(_on_node_added)

# ------------------------------------------------------------------
# 音訊
# ------------------------------------------------------------------
func _ensure_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")

func set_volume(bus: String, value: int) -> void:
	volume[bus] = clampi(value, 0, 100)
	_apply_bus(bus)
	save_settings()
	settings_changed.emit()

func set_muted(bus: String, value: bool) -> void:
	muted[bus] = value
	_apply_bus(bus)
	save_settings()
	settings_changed.emit()

func bus_db(bus: String) -> float:
	var v: int = int(volume.get(bus, 100))
	if v <= 0:
		return -80.0
	return linear_to_db(float(v) / 100.0)

func apply_audio() -> void:
	for b in BUSES:
		_apply_bus(b)

func _apply_bus(bus: String) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, bus_db(bus))
	AudioServer.set_bus_mute(idx, bool(muted.get(bus, false)) or int(volume.get(bus, 100)) <= 0)

## 依名稱決定匯流排
static func bus_for_name(node_path_lower: String) -> String:
	if node_path_lower.contains("voice"):
		return "Voice"
	if node_path_lower.contains("bgm") or node_path_lower.contains("music"):
		return "Music"
	return "SFX"

func _on_node_added(node: Node) -> void:
	if not (node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D):
		return
	if String(node.get("bus")) != "Master":
		return
	var chain := String(node.name).to_lower()
	var p := node.get_parent()
	var depth := 0
	while p != null and depth < 3 and p != get_tree().root:
		chain += "/" + String(p.name).to_lower()
		p = p.get_parent()
		depth += 1
	var bus := bus_for_name(chain)
	node.set("bus", bus)
	assigned.append({"path": String(node.name), "bus": bus})

# ------------------------------------------------------------------
# 畫面
# ------------------------------------------------------------------
func set_display_mode(mode: String) -> void:
	if not MODES.has(mode):
		return
	display_mode = mode
	_has_display_config = true
	apply_display()
	save_settings()
	settings_changed.emit()

func set_resolution(res: Vector2i) -> void:
	resolution = res
	_has_display_config = true
	if display_mode == "windowed":
		apply_display()
	save_settings()
	settings_changed.emit()

func resolution_enabled() -> bool:
	return display_mode == "windowed"

func apply_display() -> void:
	var sc := DisplayServer.window_get_current_screen()
	match display_mode:
		"windowed":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_size(resolution)
			var screen := DisplayServer.screen_get_size(sc)
			DisplayServer.window_set_position((screen - resolution) / 2 + DisplayServer.screen_get_position(sc))
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_position(DisplayServer.screen_get_position(sc))
			DisplayServer.window_set_size(DisplayServer.screen_get_size(sc))
		"fullscreen":
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

# ------------------------------------------------------------------
# 存取
# ------------------------------------------------------------------
func save_settings() -> void:
	var cfg := ConfigFile.new()
	for b in BUSES:
		cfg.set_value("audio", "%s_volume" % b, int(volume[b]))
		cfg.set_value("audio", "%s_muted" % b, bool(muted[b]))
	if _has_display_config:
		cfg.set_value("display", "mode", display_mode)
		cfg.set_value("display", "width", resolution.x)
		cfg.set_value("display", "height", resolution.y)
	cfg.save(PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for b in BUSES:
		volume[b] = clampi(int(cfg.get_value("audio", "%s_volume" % b, 100)), 0, 100)
		muted[b] = bool(cfg.get_value("audio", "%s_muted" % b, false))
	if cfg.has_section("display"):
		_has_display_config = true
		var m := String(cfg.get_value("display", "mode", "borderless"))
		display_mode = m if MODES.has(m) else "borderless"
		resolution = Vector2i(int(cfg.get_value("display", "width", 1280)), int(cfg.get_value("display", "height", 720)))
