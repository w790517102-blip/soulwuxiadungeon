extends RefCounted
class_name ChronicleSkin
# 《江湖行跡錄》貼圖皮膚：美術把去背 PNG 依規格檔名放進 assets/UI/chronicle/ 就會自動套用；
# 檔案不存在的元件，繼續使用程式畫的暫用色塊（StyleBoxFlat）。
# 貼圖一律是「2 倍解析度」（ART_SCALE）：邏輯畫面 1152×648，貼圖 = 邏輯尺寸 × 2。
# 九宮格的邊寬以「貼圖像素」計，可用 skin.json 的 "margins" 覆蓋預設值；文字顏色可用 skin.json 的 "colors" 覆蓋。

## 皮膚資料夾：assets/UI/chronicle/<皮膚 id>/（每套皮膚各一個資料夾，檔名相同）。
## 目前有：scroll_a（羊皮紙欄位版，預設）、dark_b（黑底欄位版，備用）。之後可以讓玩家自己選，換 skin_id 即可。
const ROOT := "res://assets/UI/chronicle/"
const DEFAULT_SKIN := "scroll_a"
const ART_SCALE := 2.0

## 預設九宮格邊寬（貼圖像素）
const DEFAULT_MARGINS := {
	"chronicle_frame": 48,
	"confirm_panel": 24,
	"slot_bg_normal": 12, "slot_bg_hover": 12, "slot_bg_selected": 12, "slot_bg_empty": 12, "slot_bg_corrupt": 12,
	"thumb_frame_small": 8, "preview_frame": 8,
	"btn_normal": 12, "btn_hover": 12, "btn_pressed": 12, "btn_disabled": 12,
	"btn_primary_normal": 12, "btn_primary_hover": 12, "btn_primary_pressed": 12, "btn_primary_disabled": 12,
}

## 預設文字顏色（暫用深色底版本；若美術做成淺色羊皮紙底，請在 skin.json 改成深色字）
## 文字上提（邏輯 px）：貼圖底部有陰影，框體可見部分偏上
const TEXT_LIFT := 3

const DEFAULT_COLORS := {
	"title": Color(0.86, 0.72, 0.38),
	"gold": Color(0.86, 0.72, 0.38),
	"text": Color(0.91, 0.86, 0.75),
	"dim": Color(0.55, 0.50, 0.42),
	"button_text": Color(0.86, 0.72, 0.38),
	"button_text_hover": Color(1, 0.92, 0.7),
	"button_text_disabled": Color(0.4, 0.36, 0.3),
	"corrupt": Color(0.9, 0.45, 0.35),
	"toast": Color(1, 0.93, 0.7),
	# 存檔欄位上的文字（欄位底的明暗和右側資訊區的底可能不同，所以分開設定；沒設定就用上面對應的顏色）
	"slot_gold": Color(0.86, 0.72, 0.38),
	"slot_text": Color(0.91, 0.86, 0.75),
	"slot_dim": Color(0.55, 0.50, 0.42),
	"slot_corrupt": Color(0.9, 0.45, 0.35),
	# 空白紀錄的欄位底可能比一般欄位淡（淺色），所以文字顏色另外設定
	"slot_empty_gold": Color(0.86, 0.72, 0.38),
	"slot_empty_text": Color(0.91, 0.86, 0.75),
	"slot_empty_dim": Color(0.55, 0.50, 0.42),
	"page": Color(0.91, 0.86, 0.75),
}

static var skin_id: String = DEFAULT_SKIN
static var _tex_cache: Dictionary = {}
static var _config: Dictionary = {}
static var _config_loaded := false

static func _load_config() -> void:
	if _config_loaded:
		return
	_config_loaded = true
	var config_path := dir() + "skin.json"
	if FileAccess.file_exists(config_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(config_path))
		if typeof(parsed) == TYPE_DICTIONARY:
			_config = parsed

## 測試／熱重載用：清掉貼圖與設定快取
static func dir() -> String:
	return "%s%s/" % [ROOT, skin_id]

## 換皮膚（下次開啟《江湖行跡錄》時生效）
static func set_skin(new_skin_id: String) -> void:
	skin_id = new_skin_id
	reset_cache()

## 目前有資料夾的皮膚 id
static func available_skins() -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(ROOT)
	if d != null:
		for n in d.get_directories():
			out.append(n)
	return out

## 清掉貼圖與設定快取
static func reset_cache() -> void:
	_tex_cache.clear()
	_config.clear()
	_config_loaded = false

static func texture(skin_name: String) -> Texture2D:
	if _tex_cache.has(skin_name):
		return _tex_cache[skin_name]
	var tex: Texture2D = null
	var path := "%s%s.png" % [dir(), skin_name]
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_tex_cache[skin_name] = tex
	return tex

static func has(skin_name: String) -> bool:
	return texture(skin_name) != null

static func color(key: String) -> Color:
	_load_config()
	var colors = _config.get("colors", {})
	if typeof(colors) == TYPE_DICTIONARY and colors.has(key):
		return Color.html(String(colors[key]))
	return DEFAULT_COLORS.get(key, Color.WHITE)

## 左右邊寬（九宮格）：skin.json 的 "margins_h"；沒設定就同 margin()。按鈕用它蓋住整個左右端飾。
static func margin_h(skin_name: String) -> int:
	_load_config()
	var mh = _config.get("margins_h", {})
	if typeof(mh) == TYPE_DICTIONARY and mh.has(skin_name):
		return int(mh[skin_name])
	return margin(skin_name)

static func margin(skin_name: String) -> int:
	_load_config()
	var margins = _config.get("margins", {})
	if typeof(margins) == TYPE_DICTIONARY and margins.has(skin_name):
		return int(margins[skin_name])
	return int(DEFAULT_MARGINS.get(skin_name, 16))

## 九宮格貼圖：節點大小 = 邏輯尺寸 × ART_SCALE，再整體縮放 1/ART_SCALE，所以邊飾以「貼圖像素 ÷ 2」顯示，不會被放大。
static func make_nine(skin_name: String, logical_size: Vector2) -> NinePatchRect:
	var tex := texture(skin_name)
	if tex == null:
		return null
	var n := NinePatchRect.new()
	n.name = "Skin_" + skin_name
	n.texture = tex
	var m := margin(skin_name)
	var mh2 := margin_h(skin_name)
	n.patch_margin_left = mh2
	n.patch_margin_right = mh2
	n.patch_margin_top = m
	n.patch_margin_bottom = m
	n.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	n.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	n.size = logical_size * ART_SCALE
	n.scale = Vector2.ONE / ART_SCALE
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n

## 固定尺寸貼圖（不切九宮格）
static func make_image(skin_name: String, logical_size: Vector2) -> TextureRect:
	var tex := texture(skin_name)
	if tex == null:
		return null
	var t := TextureRect.new()
	t.name = "Skin_" + skin_name
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.size = logical_size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## 把 Button 換成貼圖皮膚（prefix：btn 或 btn_primary；需要 <prefix>_normal，其餘狀態缺的用 normal）。
## 回傳 true = 已套用貼圖。貼圖畫在按鈕文字「後面」（show_behind_parent）。
## keep_aspect = true：按鈕圖不變形。以「按鈕高度 ÷ 貼圖原始高度」為統一縮放比，邊角裝飾跟著等比放大，只拉長中間；
## 按鈕的長寬比最好接近貼圖（368×72 ≈ 5.1:1）。false 則維持邏輯尺寸 × 2 的原本做法（邊角固定大小）。
static func skin_button(btn: Button, prefix: String, keep_aspect := false) -> bool:
	if not has(prefix + "_normal"):
		return false
	var bg := make_nine(prefix + "_normal", btn.size)
	if keep_aspect:
		var tex_h := float(texture(prefix + "_normal").get_height())
		var k := btn.size.y / (tex_h / ART_SCALE)
		bg.scale = Vector2.ONE * (k / ART_SCALE)
		bg.size = btn.size / bg.scale
	bg.name = "SkinBg"
	bg.show_behind_parent = true
	btn.add_child(bg)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var empty := StyleBoxEmpty.new()
		empty.content_margin_top = 0.0
		empty.content_margin_bottom = TEXT_LIFT * 2.0   # 按鈕貼圖底部有陰影，文字上提才看起來在框中央
		btn.add_theme_stylebox_override(state, empty)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var update := func() -> void:
		var state := "normal"
		match btn.get_draw_mode():
			BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED: state = "pressed"
			BaseButton.DRAW_HOVER: state = "hover"
			BaseButton.DRAW_DISABLED: state = "disabled"
		var tex := texture("%s_%s" % [prefix, state])
		if tex == null:
			tex = texture(prefix + "_normal")
		if bg.texture != tex:
			bg.texture = tex
			var m := margin("%s_%s" % [prefix, state]) if has("%s_%s" % [prefix, state]) else margin(prefix + "_normal")
			var mh3 := margin_h("%s_%s" % [prefix, state]) if has("%s_%s" % [prefix, state]) else margin_h(prefix + "_normal")
			bg.patch_margin_left = mh3
			bg.patch_margin_right = mh3
			bg.patch_margin_top = m
			bg.patch_margin_bottom = m
	btn.draw.connect(update)
	update.call()
	return true
