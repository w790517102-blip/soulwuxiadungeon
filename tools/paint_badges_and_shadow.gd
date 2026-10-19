extends SceneTree
# 後製工具：① 把美術交的「平塗」類別章畫上油畫感紋理（深淺不均的筆觸、乾筆纖維、邊緣積墨），
# ② 用類別章的形狀做出 4 級稀有度章（改顏色），③ 用卷軸的輪廓做柔和落影。
# 來源平塗章保存在 docs/system_menu/inventory_ui_v1/badges_flat/（不會被改寫）。
# 用法：Godot --headless --script tools/paint_badges_and_shadow.gd

const SRC := "res://docs/system_menu/inventory_ui_v1/badges_flat/"
const OUT := "res://assets/UI/inventory/"
const CATEGORIES := ["consumable", "book", "equipment", "material", "quest", "other"]
## 稀有度章顏色（和 scripts/inventory/ItemRarity.gd 的 LEVELS 對應；這裡是「墨色」版，比 UI 色塊沉）
const RARITY := {1: Color("#6A655C"), 2: Color("#3A6650"), 3: Color("#45507F"), 4: Color("#8A5222")}

func _hash(ix: int, iy: int, seed: int) -> float:
	var h: int = (ix * 374761393 + iy * 668265263 + seed * 2246822519) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177 & 0x7fffffff
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0

func _vnoise(x: float, y: float, seed: int) -> float:
	var ix := int(floor(x)); var iy := int(floor(y))
	var fx := x - float(ix); var fy := y - float(iy)
	fx = fx * fx * (3.0 - 2.0 * fx); fy = fy * fy * (3.0 - 2.0 * fy)
	var a := _hash(ix, iy, seed); var b := _hash(ix + 1, iy, seed)
	var c := _hash(ix, iy + 1, seed); var d := _hash(ix + 1, iy + 1, seed)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)

## 畫上油畫質感。shape：平塗章（取 alpha 形狀），base：要上的顏色
func _paint(shape: Image, base: Color, seed: int) -> Image:
	var w := shape.get_width(); var h := shape.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var s := shape.get_pixel(x, y)
			if s.a <= 0.01:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			# 邊緣程度：周圍 3px 內有多少透明
			var open := 0.0; var n := 0.0
			for d in [[-3, 0], [3, 0], [0, -3], [0, 3], [-2, -2], [2, 2], [-2, 2], [2, -2]]:
				var px: int = x + d[0]; var py: int = y + d[1]
				var a := 0.0
				if px >= 0 and py >= 0 and px < w and py < h:
					a = shape.get_pixel(px, py).a
				open += 1.0 - a; n += 1.0
			var edge := open / n
			var low := _vnoise(float(x) / 26.0, float(y) / 14.0, seed)            # 大塊深淺
			var med := _vnoise(float(x) / 9.0, float(y) / 5.0, seed + 7)           # 中塊
			var streak := _vnoise(float(x) / 3.0, float(y) / 0.9, seed + 13)       # 橫向筆毛纖維
			var fine := _vnoise(float(x) / 1.6, float(y) / 1.6, seed + 29)         # 顆粒
			var lum := 0.90 + (low - 0.5) * 0.42 + (med - 0.5) * 0.26 + (streak - 0.5) * 0.30 + (fine - 0.5) * 0.10
			lum -= edge * 0.30                                                      # 邊緣積墨（較深）
			var c := base
			# 輕微色相／飽和變化：深處偏冷偏深，淺處偏暖
			var warm := (low - 0.5) * 0.06
			c = Color(c.r + warm, c.g + warm * 0.4, c.b - warm * 0.6, 1.0)
			c = Color(clampf(c.r * lum, 0, 1), clampf(c.g * lum, 0, 1), clampf(c.b * lum, 0, 1), 1.0)
			var alpha := s.a
			# 乾筆缺口：邊緣、筆毛纖維高的地方變透明
			alpha *= 1.0 - 0.75 * smoothstep(0.62, 0.92, streak) * clampf(edge * 2.2, 0.0, 1.0)
			out.set_pixel(x, y, Color(c.r, c.g, c.b, clampf(alpha, 0.0, 1.0)))
	return out

func _init() -> void:
	var shape := Image.load_from_file(SRC + "badge_consumable.png"); shape.convert(Image.FORMAT_RGBA8)
	var i := 0
	for cat in CATEGORIES:
		var src := Image.load_from_file(SRC + "badge_%s.png" % cat); src.convert(Image.FORMAT_RGBA8)
		# 基色：原章中心取色
		var base := src.get_pixel(src.get_width() / 2, src.get_height() / 2)
		base.a = 1.0
		_paint(src, base, 100 + i * 17).save_png(OUT + "badge_%s.png" % cat)
		print("PAINT badge_", cat)
		i += 1
	for level in RARITY.keys():
		_paint(shape, RARITY[level], 300 + int(level) * 23).save_png(OUT + "rarity_%d.png" % level)
		print("PAINT rarity_", level)
	_shadow()
	quit()

## 卷軸落影：卷軸輪廓縮小、模糊、往下位移，疊黑色半透明
func _shadow() -> void:
	var scroll := Image.load_from_file(OUT + "scroll_body.png"); scroll.convert(Image.FORMAT_RGBA8)
	# 邏輯 1×：卷軸 972×506；畫布四周多 48
	var pad := 48
	var cw := 972 + pad * 2; var ch := 506 + pad * 2
	var small := scroll.duplicate() as Image
	small.resize(972, 506, Image.INTERPOLATE_BILINEAR)
	var a := PackedFloat32Array(); a.resize(cw * ch)
	var off_y := 14
	for y in 506:
		for x in 972:
			a[(y + pad + off_y) * cw + (x + pad)] = small.get_pixel(x, y).a
	# 三次盒狀模糊（近似高斯），橫向、縱向各一
	for pass_i in 3:
		a = _blur_h(a, cw, ch, 10)
		a = _blur_v(a, cw, ch, 10)
	var out := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	for y in ch:
		for x in cw:
			out.set_pixel(x, y, Color(0.04, 0.02, 0.0, clampf(a[y * cw + x] * 0.78, 0.0, 1.0)))
	out.save_png(OUT + "scroll_shadow.png")
	print("PAINT scroll_shadow ", out.get_size())

func _blur_h(a: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var o := PackedFloat32Array(); o.resize(w * h)
	for y in h:
		var sum := 0.0
		for x in range(-r, r + 1):
			sum += a[y * w + clampi(x, 0, w - 1)]
		for x in w:
			o[y * w + x] = sum / float(2 * r + 1)
			sum += a[y * w + clampi(x + r + 1, 0, w - 1)] - a[y * w + clampi(x - r, 0, w - 1)]
	return o

func _blur_v(a: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var o := PackedFloat32Array(); o.resize(w * h)
	for x in w:
		var sum := 0.0
		for y in range(-r, r + 1):
			sum += a[clampi(y, 0, h - 1) * w + x]
		for y in h:
			o[y * w + x] = sum / float(2 * r + 1)
			sum += a[clampi(y + r + 1, 0, h - 1) * w + x] - a[clampi(y - r, 0, h - 1) * w + x]
	return o
