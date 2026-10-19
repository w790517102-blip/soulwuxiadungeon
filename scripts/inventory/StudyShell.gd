extends Control
class_name StudyShell
# 選單共用的「外殼」：書房桌面背景（後層）＋桌上的前景物件（前層）。
# 所有新版系統頁共用，頁面自己的內容（卷軸、導航、清單…）放在中間。
# 用法：把 StudyShell 加到頁面裡就好。背景 z_index -1；後排前景（書）z 0，在背景之上、內容之下；前排前景（劍、茶壺、燈籠）z 10，蓋在介面上。都不吃滑鼠.
# 素材：assets/UI/inventory/bg_study.png（2432×1424，含四邊 64px 出血）、fg_<名稱>.png（各自獨立的透明圖）。
# 前景只放在安全位置（不遮介面）；檔案沒有就略過，所以素材沒到之前畫面也完整。

const DIR := "res://assets/UI/inventory/"

## 背景檔名（不含副檔名）。預設 bg_study；試別的背景時改這個（例如候選圖）。
static var bg_name := "bg_study"

## 前景物件：名稱 → 邏輯座標位置（物件圖的左上角）與錨點。位置對應修改請求第五節的三個安全區。
## anchor：用物件圖的哪個角貼到 pos（"bl" 左下、"br" 右下、"tr" 右上）
## layer：back＝畫在介面下面（背景之上）；front＝畫在介面上面（離鏡頭最近，會遮住卷軸框與分類欄）。
## rot：順時針度數（以物件中心旋轉）。位置用「錨點角」貼，數字可超出畫面（物件被畫面邊緣切掉）。
## 前景＝概念圖的原像素摳圖（沒有重畫）。照概念圖的位置貼在畫面邊角。
## scale：每個素材像素佔幾個邏輯像素（摳圖來自概念圖的局部截圖，概念圖寬 1672 px 對應邏輯 1152，所以 1152/1672 = 0.689 就是「概念圖佔多少就佔多少」（量過：摳圖的像素大小約等於概念圖像素））。
## layer：back＝介面下面；front＝介面上面（最靠近鏡頭）。
## 前景方案（可切換）：
##   "concept"（預設）＝概念圖原像素摳圖，照概念圖的大小與位置（0.689）。
##   "demo"（備案 1）＝照使用者自己做的 DEMO 版面：左下書、劍橫在按鈕列後面、右下大茶壺、右緣燈籠。
##   "cloth_big"（備案 2）＝概念圖摳圖，但左下的劍與青布放大（0.99），青布上緣蓋住分類欄下緣的框約 8px。
## 切換：StudyShell.preset = "demo"（要在開頁面之前設）。
static var preset := "concept"

const PRESETS := {
	"concept": {
		"fg_cloth_sword": {"pos": Vector2(0, 648), "anchor": "bl", "layer": "front", "scale": 0.689},    # 左下：布＋劍
		"fg_teapot_corner": {"pos": Vector2(1152, 648), "anchor": "br", "layer": "front", "scale": 0.689}, # 右下：茶壺（只露邊角）
		"fg_candle_corner": {"pos": Vector2(1152, 28), "anchor": "tr", "layer": "front", "scale": 0.689},   # 右上：燭台
		"fg_tassel_right": {"pos": Vector2(1124, 398), "anchor": "tl", "layer": "front", "scale": 0.689},   # 卷軸右側垂下的流蘇
	},
	"cloth_big": {
		"fg_cloth_sword": {"pos": Vector2(0, 648), "anchor": "bl", "layer": "front", "scale": 0.99},    # 青布上緣蓋住分類欄下緣的框約 8px
		"fg_teapot_corner": {"pos": Vector2(1152, 648), "anchor": "br", "layer": "front", "scale": 0.689},
		"fg_candle_corner": {"pos": Vector2(1152, 28), "anchor": "tr", "layer": "front", "scale": 0.689},
		"fg_tassel_right": {"pos": Vector2(1124, 398), "anchor": "tl", "layer": "front", "scale": 0.689},
	},
	"demo": {
		"fg_demo_book": {"pos": Vector2(-30, 662), "anchor": "bl", "layer": "front", "scale": 0.5},        # 左下：翻開的書（遮住左下框）
		"fg_demo_sword": {"pos": Vector2(250, 668), "anchor": "bl", "layer": "back", "scale": 0.5},        # 劍橫在按鈕列後面（介面之下）
		"fg_demo_teapot": {"pos": Vector2(1250, 676), "anchor": "br", "layer": "front", "scale": 0.5},     # 右下：大茶壺，只露一半
		"fg_demo_lantern": {"pos": Vector2(1152, 0), "anchor": "tr", "layer": "front", "scale": 0.5},       # 右緣：燈籠
	},
}

var _fg_root: Control
var _fg_front: Control
var _bg: TextureRect

func _ready() -> void:
	name = "StudyShell"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 後層：2432×1424 縮半 → 1216×712，左上角 (-32, -32)（四邊各出血 32 邏輯 px）
	_bg = TextureRect.new()
	_bg.texture = load("%s%s.png" % [DIR, bg_name]) as Texture2D
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.position = Vector2(-32, -32)
	_bg.size = Vector2(1216, 712)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.z_index = -1      # 背景畫在頁面內容之下
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_bg)
	_fg_root = Control.new()
	_fg_root.name = "Foreground"
	_fg_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fg_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fg_root.z_index = 0      # 背景（-1）之上、頁面內容之下：被卷軸、按鈕、分類欄擋住也沒關係
	add_child(_fg_root)
	_fg_front = Control.new()
	_fg_front.name = "ForegroundFront"
	_fg_front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fg_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fg_front.z_index = 10      # 頁面內容（z 0）之上：最靠近鏡頭的物件，會蓋住卷軸框、分類欄
	add_child(_fg_front)
	_build_foreground()

func _build_foreground() -> void:
	var foreground: Dictionary = PRESETS.get(preset, PRESETS["concept"])
	for fg_name in foreground.keys():
		var path := "%s%s.png" % [DIR, fg_name]
		if not ResourceLoader.exists(path):
			continue
		var tex := load(path) as Texture2D
		var def: Dictionary = foreground[fg_name]
		var size := tex.get_size() * float(def.get("scale", 0.5))     # 預設素材是 2 倍
		var pos: Vector2 = def["pos"]
		match String(def["anchor"]):
			"bl": pos -= Vector2(0, size.y)
			"br": pos -= size
			"tr": pos -= Vector2(size.x, 0)
		var r := TextureRect.new()
		r.name = fg_name
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.position = pos
		r.size = size
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if def.has("rot"):
			r.pivot_offset = size * 0.5
			r.rotation_degrees = float(def["rot"])
		(_fg_front if String(def.get("layer", "back")) == "front" else _fg_root).add_child(r)

