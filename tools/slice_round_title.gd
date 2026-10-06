extends SceneTree
## One-off tool: cuts the delivered round-title art (three ink-and-gold blocks side by side: 第 / 回合 / 開始, transparent
## background) into assets/UI/card_stage/title/round_di.png, round_huihe.png, round_kaishi.png at 256 px high.
## Run: SHEET=path/to/sheet.webp godot --headless --path . --script tools/slice_round_title.gd

const NAMES: Array[String] = ["round_di", "round_huihe", "round_kaishi"]
const OUT := "res://assets/UI/card_stage/title/"
const TARGET_HEIGHT := 256
const MIN_GAP := 6


func _initialize() -> void:
	var image := Image.load_from_file(OS.get_environment("SHEET"))
	if image == null or image.is_empty():
		push_error("cannot read the sheet")
		quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)
	var width: int = image.get_width()
	var height: int = image.get_height()
	var hits: Array = []
	for x: int in range(width):
		var seen: bool = false
		for y: int in range(0, height, 2):
			if image.get_pixel(x, y).a > 0.6:
				seen = true
				break
		hits.append(seen)
	var bands: Array = []
	var start: int = -1
	var last: int = -1
	for x: int in range(width):
		if hits[x]:
			if start < 0:
				start = x
			elif x - last > MIN_GAP:
				bands.append(Vector2i(start, last))
				start = x
			last = x
	if start >= 0:
		bands.append(Vector2i(start, last))
	if bands.size() != 3:
		push_error("expected 3 blocks, found %d" % bands.size())
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for index: int in range(3):
		var band: Vector2i = bands[index]
		# vertical extent of this block
		var top: int = height
		var bottom: int = 0
		for y: int in range(height):
			for x: int in range(band.x, band.y + 1, 2):
				if image.get_pixel(x, y).a > 0.05:
					top = mini(top, y)
					bottom = maxi(bottom, y)
					break
		var crop: Image = image.get_region(Rect2i(band.x, top, band.y - band.x + 1, bottom - top + 1))
		crop.premultiply_alpha()
		var scale: float = float(TARGET_HEIGHT) / float(crop.get_height())
		crop.resize(maxi(1, int(round(crop.get_width() * scale))), TARGET_HEIGHT, Image.INTERPOLATE_LANCZOS)
		for y: int in range(crop.get_height()):
			for x: int in range(crop.get_width()):
				var c: Color = crop.get_pixel(x, y)
				if c.a > 0.001:
					crop.set_pixel(x, y, Color(minf(c.r / c.a, 1.0), minf(c.g / c.a, 1.0), minf(c.b / c.a, 1.0), c.a))
				else:
					crop.set_pixel(x, y, Color(0, 0, 0, 0))
		crop.save_png(ProjectSettings.globalize_path("%s%s.png" % [OUT, NAMES[index]]))
	print("title pieces sliced")
	quit(0)
