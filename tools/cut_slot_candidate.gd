extends SceneTree
# 裝備格候選框（老闆提供的 webp）去背並縮成 200×192：背景是白色（或已有透明），從四邊往內洪水填色去掉跟外面連通的近白像素，
# 邊緣做 1px 內縮與羽化，避免白邊；輸出 assets/UI/equipment/slots/slot_frame_candidate.png。
# 用法：godot --headless --path . --script tools/cut_slot_candidate.gd

func _init() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://docs/system_menu/equipment_originals/slot_frame_candidate.webp"))
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	print("CAND size ", img.get_size(), " corner alpha ", img.get_pixel(2, 2).a, " corner rgb ", img.get_pixel(2, 2))
	var bg := PackedByteArray()
	bg.resize(w * h)
	var stack: Array[Vector2i] = []
	for x in w:
		stack.append(Vector2i(x, 0)); stack.append(Vector2i(x, h - 1))
	for y in h:
		stack.append(Vector2i(0, y)); stack.append(Vector2i(w - 1, y))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or bg[p.y * w + p.x] == 1:
			continue
		var c := img.get_pixel(p.x, p.y)
		var is_bg: bool = c.a < 0.1 or (c.r > 0.93 and c.g > 0.93 and c.b > 0.93)
		if not is_bg:
			continue
		bg[p.y * w + p.x] = 1
		stack.append(Vector2i(p.x + 1, p.y)); stack.append(Vector2i(p.x - 1, p.y)); stack.append(Vector2i(p.x, p.y + 1)); stack.append(Vector2i(p.x, p.y - 1))
	# 背景→透明；邊緣一圈（背景相鄰）半透明，去白邊
	var bb := Rect2i(w, h, 0, 0)
	var first := true
	for y in h:
		for x in w:
			var i := y * w + x
			if bg[i] == 1:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var near_bg := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and bg[ny * w + nx] == 1:
					near_bg = true
			var c := img.get_pixel(x, y)
			if near_bg:
				c.a *= 0.55
				img.set_pixel(x, y, c)
			if first:
				bb = Rect2i(x, y, 1, 1)
				first = false
			else:
				bb = bb.expand(Vector2i(x, y))
	print("CAND bbox ", bb)
	var cut := img.get_region(bb)
	cut.resize(200, 192, Image.INTERPOLATE_LANCZOS)
	cut.save_png(ProjectSettings.globalize_path("res://assets/UI/equipment/slots/slot_frame_candidate.png"))
	print("CAND done ", cut.get_size())
	quit()
