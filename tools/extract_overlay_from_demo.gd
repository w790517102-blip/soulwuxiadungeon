extends SceneTree
# 從「使用者的 DEMO 截圖」減去「同狀態、同大小、沒有前景的實機截圖」，取出前景像素，輸出整張透明疊圖。
# 這是還原 DEMO 位置的最準確辦法（沒有原圖層時）：像素位置 100% 相同；缺點是前景的半透明陰影、與介面同色的部分會有缺漏。
# 用法：Godot --headless --script tools/extract_overlay_from_demo.gd -- <base.png> <demo.webp> <輸出 png>
# 只在「前景可能出現的區域」取：左下、底部一條、右側一條（避開滑鼠游標、錄影軟體的紅點）。

func _in_zone(x: int, y: int, w: int, h: int) -> bool:
	var sx := float(w) / 1916.0
	var sy := float(h) / 1078.0
	var fx := float(x) / sx
	var fy := float(y) / sy
	if fx < 760.0 and fy > 800.0: return true               # 左下
	if fy > 925.0: return true                              # 底部一條
	if fx > 1780.0 and fy > 125.0: return true              # 右側一條（避開右上角的游標）
	return false

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var base := Image.load_from_file(a[0]); base.convert(Image.FORMAT_RGB8)
	var demo := Image.load_from_file(a[1]); demo.convert(Image.FORMAT_RGB8)
	var w := base.get_width(); var h := base.get_height()
	var mask := PackedByteArray(); mask.resize(w * h)
	for y in h:
		for x in w:
			if not _in_zone(x, y, w, h):
				continue
			var cb := base.get_pixel(x, y); var cd := demo.get_pixel(x, y)
			var d := absf(cb.r - cd.r) + absf(cb.g - cd.g) + absf(cb.b - cd.b)
			if d > 0.16:
				mask[y * w + x] = 1
	mask = _close(mask, w, h, 3)
	mask = _open(mask, w, h, 2)
	# 去掉小斑點
	mask = _drop_small(mask, w, h, 400)
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var count := 0
	for y in h:
		for x in w:
			if mask[y * w + x] == 1:
				var c := demo.get_pixel(x, y); c.a = 1.0
				out.set_pixel(x, y, c)
				count += 1
	# 邊緣羽化 1px：alpha 取周圍 3x3 的平均
	var soft := out.duplicate() as Image
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var s := 0.0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					s += out.get_pixel(x + dx, y + dy).a
			var c2 := out.get_pixel(x, y)
			if c2.a > 0.5 or s > 0.0:
				var src := demo.get_pixel(x, y)
				soft.set_pixel(x, y, Color(src.r, src.g, src.b, s / 9.0 if c2.a < 0.5 else 1.0))
	soft.save_png(a[2])
	print("EXTRACT size=", Vector2i(w, h), " opaque_px=", count)
	quit()

func _box(m: PackedByteArray, w: int, h: int, r: int, want: int) -> PackedByteArray:
	# want=1：膨脹（任何鄰居是 1 就是 1）；want=0：侵蝕（任何鄰居是 0 就是 0）
	var o := PackedByteArray(); o.resize(w * h)
	for y in h:
		for x in w:
			var v := 1 - want
			var hit := false
			for dy in range(-r, r + 1, 1):
				var yy := y + dy
				if yy < 0 or yy >= h: continue
				for dx in range(-r, r + 1, 1):
					var xx := x + dx
					if xx < 0 or xx >= w: continue
					if m[yy * w + xx] == want:
						hit = true; break
				if hit: break
			o[y * w + x] = want if hit else 1 - want
	return o

func _close(m: PackedByteArray, w: int, h: int, r: int) -> PackedByteArray:
	return _box(_box(m, w, h, r, 1), w, h, r, 0)

func _open(m: PackedByteArray, w: int, h: int, r: int) -> PackedByteArray:
	return _box(_box(m, w, h, r, 0), w, h, r, 1)

func _drop_small(m: PackedByteArray, w: int, h: int, min_size: int) -> PackedByteArray:
	var seen := PackedByteArray(); seen.resize(w * h)
	var o := m.duplicate()
	for start in w * h:
		if m[start] != 1 or seen[start] == 1:
			continue
		var comp: Array[int] = []
		var stack: Array[int] = [start]
		seen[start] = 1
		while not stack.is_empty():
			var p: int = stack.pop_back()
			comp.append(p)
			var px := p % w; var py := p / w
			for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
				var nx: int = px + d[0]; var ny: int = py + d[1]
				if nx >= 0 and ny >= 0 and nx < w and ny < h:
					var np := ny * w + nx
					if m[np] == 1 and seen[np] == 0:
						seen[np] = 1; stack.append(np)
		if comp.size() < min_size:
			for p in comp: o[p] = 0
	return o
