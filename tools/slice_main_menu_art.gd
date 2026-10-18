extends SceneTree
# 一次性工具：把主選單按鈕長圖（本身已是透明底）依列切成 5 顆 PNG。
# 用法：Godot --headless --script tools/slice_main_menu_art.gd -- <sheet.webp> <輸出前綴>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("need <sheet> <out_prefix>")
		quit(1)
		return
	var img := Image.load_from_file(args[0])
	if img == null:
		push_error("cannot load " + args[0])
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	# 一列是否屬於按鈕本體：不透明（>0.5）的像素夠多（排除只有外圍光暈的列）
	var bands: Array = []
	var start := -1
	for y in h:
		var solid := 0
		for x in w:
			if data[(y * w + x) * 4 + 3] > 128:
				solid += 1
		var has := solid > 40
		if has and start < 0:
			start = y
		elif not has and start >= 0:
			if y - start > 40:
				bands.append(Vector2i(start, y))
			start = -1
	if start >= 0:
		bands.append(Vector2i(start, h))
	print("bands=", bands.size(), " ", bands)
	var idx := 0
	for band in bands:
		idx += 1
		var y0: int = maxi(band.x - 45, 0)
		var y1: int = mini(band.y + 45, h)
		var crop := img.get_region(Rect2i(0, y0, w, y1 - y0))
		crop = crop.get_region(crop.get_used_rect())
		var path := "%s_%d.png" % [args[1], idx]
		crop.save_png(path)
		print("saved ", path, " ", crop.get_size())
	quit(0)
