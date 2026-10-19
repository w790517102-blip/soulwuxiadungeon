extends SceneTree
# 用美術的「原檔」（沒有被擠壓變形）做前景：以「不透明度 > 5%」裁掉透明邊，再等比縮放到指定尺寸（2 倍像素）。
# 原檔放在 docs/system_menu/fg_originals/。用法：Godot --headless --script tools/build_foreground_from_originals.gd
const SRC := "res://docs/system_menu/fg_originals/"
const OUT := "res://assets/UI/inventory/"
## 名稱 → [原檔, 模式, 數值]。模式 "w"＝指定輸出寬度（2× px）；"h"＝指定輸出高度（2× px）
const JOBS := {
	"fg_sword": ["sword_original.webp", "w", 1100],
	"fg_book": ["book_original.webp", "w", 660],
	"fg_teapot": ["teapot_original.webp", "w", 620],
	"fg_candle": ["lantern_original.png", "h", 1296],   # 燈籠：占滿畫面高度（邏輯 648）
}

func _bounds(im: Image) -> Rect2i:
	var minx := im.get_width(); var miny := im.get_height(); var maxx := 0; var maxy := 0
	for y in im.get_height():
		for x in im.get_width():
			if im.get_pixel(x, y).a > 0.05:
				minx = mini(minx, x); maxx = maxi(maxx, x); miny = mini(miny, y); maxy = maxi(maxy, y)
	return Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)

func _init() -> void:
	for name in JOBS.keys():
		var job: Array = JOBS[name]
		var im := Image.load_from_file(SRC + job[0])
		im.convert(Image.FORMAT_RGBA8)
		im = im.get_region(_bounds(im))
		var w: int; var h: int
		if job[1] == "w":
			w = int(job[2]); h = int(round(float(im.get_height()) * float(w) / float(im.get_width())))
		else:
			h = int(job[2]); w = int(round(float(im.get_width()) * float(h) / float(im.get_height())))
		im.resize(w, h, Image.INTERPOLATE_LANCZOS)
		im.save_png(OUT + name + ".png")
		print("FGO ", name, " ", Vector2i(w, h))
	quit()
