extends SceneTree
# 一次性工具：把「白底的單一圖示」去背（從邊緣往內洗掉接近白的背景）、裁切、縮成指定高度。
# 用法：Godot --headless --script tools/cutout_icon.gd -- <來源圖> <輸出 png> <輸出高度 px>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var img := Image.load_from_file(a[0])
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	if data[3] < 10:
		# 本來就是透明底：只裁切、縮放
		img = img.get_region(img.get_used_rect())
		var th0 := int(a[2])
		img.resize(int(round(float(img.get_width()) * float(th0) / float(img.get_height()))), th0, Image.INTERPOLATE_LANCZOS)
		img.save_png(a[1])
		print("ICON ", a[1], " ", img.get_size(), " (already transparent)")
		quit()
		return
	var bg := PackedByteArray()
	bg.resize(w * h)
	var stack: Array[int] = []
	for x in w:
		stack.append(x); stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w); stack.append(y * w + w - 1)
	while not stack.is_empty():
		var p: int = stack.pop_back()
		if bg[p] != 0:
			continue
		var r: int = data[p * 4]; var g: int = data[p * 4 + 1]; var b: int = data[p * 4 + 2]
		if mini(r, mini(g, b)) < 226 or (maxi(r, maxi(g, b)) - mini(r, mini(g, b))) > 18:
			continue
		bg[p] = 1
		var px := p % w; var py := p / w
		if px > 0: stack.append(p - 1)
		if px < w - 1: stack.append(p + 1)
		if py > 0: stack.append(p - w)
		if py < h - 1: stack.append(p + w)
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for p in w * h:
		var x := p % w; var y := p / w
		var c := Color8(data[p * 4], data[p * 4 + 1], data[p * 4 + 2], 255)
		if bg[p] == 1:
			c.a = 0.0
		else:
			# 緊鄰背景的邊緣像素做半透明，去掉白邊
			var near := false
			for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
				var nx: int = x + d[0]; var ny: int = y + d[1]
				if nx >= 0 and ny >= 0 and nx < w and ny < h and bg[ny * w + nx] == 1:
					near = true
			if near:
				var m := mini(data[p * 4], mini(data[p * 4 + 1], data[p * 4 + 2]))
				c.a = clampf((255.0 - float(m)) / 90.0, 0.35, 1.0)
		out.set_pixel(x, y, c)
	out = out.get_region(out.get_used_rect())
	var th := int(a[2])
	var tw := int(round(float(out.get_width()) * float(th) / float(out.get_height())))
	out.resize(tw, th, Image.INTERPOLATE_LANCZOS)
	out.save_png(a[1])
	print("ICON ", a[1], " ", out.get_size())
	quit()
