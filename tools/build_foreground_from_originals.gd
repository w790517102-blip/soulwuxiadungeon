extends SceneTree
# 用美術的「原檔」（沒有被擠壓變形）做前景：裁掉透明邊、等比縮放到指定寬度（2 倍像素）。
# 美術第一版交的前景為了塞進安全區，被垂直壓扁（原檔劍 2.7:1 → 交付 5.5:1）。這裡改用原檔等比縮放。
# 原檔放在 docs/system_menu/fg_originals/。用法：Godot --headless --script tools/build_foreground_from_originals.gd
const SRC := "res://docs/system_menu/fg_originals/"
const OUT := "res://assets/UI/inventory/"
## 名稱 → [原檔, 輸出寬度（2× 像素）]
const JOBS := {
	"fg_sword": ["sword_original.webp", 560],
	"fg_book": ["book_original.webp", 340],
	"fg_teapot": ["teapot_original.webp", 244],
}

func _init() -> void:
	for name in JOBS.keys():
		var im := Image.load_from_file(SRC + JOBS[name][0])
		im.convert(Image.FORMAT_RGBA8)
		im = im.get_region(im.get_used_rect())
		var w: int = JOBS[name][1]
		var h := int(round(float(im.get_height()) * float(w) / float(im.get_width())))
		im.resize(w, h, Image.INTERPOLATE_LANCZOS)
		im.save_png(OUT + name + ".png")
		print("FGO ", name, " ", Vector2i(w, h), " aspect=", snappedf(float(w) / float(h), 0.01))
	quit()
