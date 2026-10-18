extends SceneTree
# 一次性工具：把游標素材總覽圖（白底、多個獨立元件）自動去背並切成獨立 PNG。
# 用法：Godot --headless --script tools/cutout_cursor_sheet.gd -- <sheet.png> <輸出前綴> <欄數> <列數>
# 以連通區塊找出每個元件（忽略太小的雜點），依「列由上而下、欄由左而右」編號輸出 <前綴>_<列>_<欄>.png，並印出各自的原始座標。

func _is_bg(r: int, g: int, b: int) -> bool:
	return r >= 235 and g >= 235 and b >= 235

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var img := Image.load_from_file(args[0])
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var radius := int(args[4]) if args.size() > 4 else 6   # 膨脹半徑：同一元件裡被隔開的小塊（例如閃光）要靠這個合併
	var fg := PackedByteArray()
	fg.resize(w * h)
	for p in w * h:
		# 素材本身是透明底 PNG：不透明度 > 10% 的算前景；若是白底圖則白色視為背景
		if data[3] < 10:
			fg[p] = 1 if data[p * 4 + 3] > 25 else 0
		else:
			fg[p] = 0 if _is_bg(data[p * 4], data[p * 4 + 1], data[p * 4 + 2]) else 1
	# 膨脹 3px 後找連通區塊（讓同一元件內被白色隔開的小塊，例如閃光，不會被拆開）
	var dil := PackedByteArray()
	dil.resize(w * h)
	for y in h:
		for x in w:
			if fg[y * w + x] == 1:
				for dy in range(-radius, radius + 1):
					for dx in range(-radius, radius + 1):
						var nx := x + dx
						var ny := y + dy
						if nx >= 0 and ny >= 0 and nx < w and ny < h:
							dil[ny * w + nx] = 1
	var label := PackedInt32Array()
	label.resize(w * h)
	var comps: Array = []
	var next_id := 1
	for start in w * h:
		if dil[start] == 0 or label[start] != 0:
			continue
		var q: Array[int] = [start]
		label[start] = next_id
		var minx := w; var miny := h; var maxx := 0; var maxy := 0; var size := 0
		while not q.is_empty():
			var p2: int = q.pop_back()
			var x2 := p2 % w
			var y2 := p2 / w
			size += 1
			minx = mini(minx, x2); maxx = maxi(maxx, x2); miny = mini(miny, y2); maxy = maxi(maxy, y2)
			for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
				var nx: int = x2 + d[0]
				var ny: int = y2 + d[1]
				if nx >= 0 and ny >= 0 and nx < w and ny < h:
					var np := ny * w + nx
					if dil[np] == 1 and label[np] == 0:
						label[np] = next_id
						q.append(np)
		if size > 4000:
			comps.append({"id": next_id, "rect": Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)})
		next_id += 1
	var cols := int(args[2])
	var rows := int(args[3])
	# 依位置排序：先分列（y 中心），再列內由左到右
	comps.sort_custom(func(a, b): return a.rect.get_center().y < b.rect.get_center().y)
	var idx := 0
	for r in rows:
		var row: Array = comps.slice(r * cols, (r + 1) * cols)
		row.sort_custom(func(a, b): return a.rect.get_center().x < b.rect.get_center().x)
		for c in row.size():
			var comp: Dictionary = row[c]
			var rect: Rect2i = comp.rect
			var out := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
			out.fill(Color(0, 0, 0, 0))
			for y in rect.size.y:
				for x in rect.size.x:
					var sx := rect.position.x + x
					var sy := rect.position.y + y
					var p3 := sy * w + sx
					if fg[p3] == 1 and dil[p3] == 1 and label[p3] == int(comp.id):
						var col := Color8(data[p3 * 4], data[p3 * 4 + 1], data[p3 * 4 + 2], data[p3 * 4 + 3])
						out.set_pixel(x, y, col)
			var path := "%s_%d_%d.png" % [args[1], r + 1, c + 1]
			out.save_png(path)
			print("CUT ", path, " rect=", rect)
			idx += 1
	quit()
