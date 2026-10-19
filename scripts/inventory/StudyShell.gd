extends Control
class_name StudyShell
# 選單共用的「外殼」：書房桌面背景（後層）＋桌上的前景物件（前層）。
# 所有新版系統頁共用，頁面自己的內容（卷軸、導航、清單…）放在中間。
# 用法：把 StudyShell 加到頁面裡就好。背景用 z_index -1 畫在內容下面，前景用 z_index 10 畫在內容上面，兩者都不吃滑鼠，不用管加入順序。
# 素材：assets/UI/inventory/bg_study.png（2432×1424，含四邊 64px 出血）、fg_<名稱>.png（各自獨立的透明圖）。
# 前景只放在安全位置（不遮介面）；檔案沒有就略過，所以素材沒到之前畫面也完整。

const DIR := "res://assets/UI/inventory/"

## 背景檔名（不含副檔名）。預設 bg_study；試別的背景時改這個（例如候選圖）。
static var bg_name := "bg_study"

## 前景物件：名稱 → 邏輯座標位置（物件圖的左上角）與錨點。位置對應修改請求第五節的三個安全區。
## anchor：用物件圖的哪個角貼到 pos（"bl" 左下、"br" 右下、"tr" 右上）
const FOREGROUND := {
	# 畫的順序 = 字典順序（後面的蓋在前面）：書在後、劍在前。位置用「錨點角」貼；數字可以超出畫面一點（物件被畫面邊緣切掉，更有近景感）
	"fg_book": {"pos": Vector2(0, 660), "anchor": "bl"},        # 左下：書
	"fg_sword": {"pos": Vector2(-30, 672), "anchor": "bl"},     # 左下：劍（前）
	"fg_teapot": {"pos": Vector2(1152, 650), "anchor": "br"},   # 右下：茶壺
	"fg_candle": {"pos": Vector2(1152, 70), "anchor": "tr"},    # 右緣：燈籠窄邊
}

var _fg_root: Control
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
	_fg_root.z_index = 10
	add_child(_fg_root)
	_build_foreground()

func _build_foreground() -> void:
	for fg_name in FOREGROUND.keys():
		var path := "%s%s.png" % [DIR, fg_name]
		if not ResourceLoader.exists(path):
			continue
		var tex := load(path) as Texture2D
		var def: Dictionary = FOREGROUND[fg_name]
		var size := tex.get_size() * 0.5     # 素材是 2 倍
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
		_fg_root.add_child(r)

