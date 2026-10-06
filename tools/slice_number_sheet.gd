extends SceneTree
## One-off tool: cuts the battle-number sheet (4 rows: normal / counter / crit / heal, 12 columns: 0-9 + !) into the 48
## files the game reads (assets/UI/card_stage/numbers/<style>/<name>.png). Italic glyphs and their flames overlap, so
## the cut is by shape, not by a grid: the solid body of each glyph is found (connected pixels), then every faint pixel is
## given to the nearest body. All glyphs get the SAME canvas height and baseline (only left/right is trimmed).
## Run: SHEET=path/to/sheet.webp godot --headless --path . --script tools/slice_number_sheet.gd
## (the sheet must have a transparent background)

const STYLES: Array[String] = ["normal", "counter", "crit", "heal"]
const NAMES: Array[String] = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "plus", "bang"]
const OUT := "res://assets/UI/card_stage/numbers/"
const TARGET_HEIGHT := 128
const CORE_ALPHA := 0.45
const FAINT_ALPHA := 0.05
const DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func _initialize() -> void:
	var image := Image.load_from_file(OS.get_environment("SHEET"))
	if image == null or image.is_empty():
		push_error("cannot read the sheet")
		quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)
	var height: int = image.get_height()
	var row_bands: Array = _bands(_row_hits(image, 0.4), 4)
	if row_bands.size() != 4:
		push_error("expected 4 rows, found %d" % row_bands.size())
		quit(1)
		return
	var canvas_height: int = 0
	for band: Vector2i in row_bands:
		canvas_height = maxi(canvas_height, band.y - band.x + 1 + 28)
	for row: int in range(4):
		var band: Vector2i = row_bands[row]
		# a little room above and below for the faint flame that belongs to the row
		var top: int = maxi(0, band.x - 8)
		var bottom: int = mini(height - 1, band.y + 8)
		var glyphs: Array = _glyphs_of_row(image, top, bottom)
		if glyphs.size() != 12:
			push_error("row %d: expected 12 glyphs" % row)
			quit(1)
			return
		for column: int in range(12):
			var glyph: Image = glyphs[column]
			var canvas := Image.create(glyph.get_width(), canvas_height, false, Image.FORMAT_RGBA8)
			canvas.blit_rect(glyph, Rect2i(0, 0, glyph.get_width(), glyph.get_height()), Vector2i(0, canvas_height - glyph.get_height()))
			var factor: float = float(TARGET_HEIGHT) / float(canvas_height)
			var resized: Image = _resize_premultiplied(canvas, maxi(1, int(round(canvas.get_width() * factor))), TARGET_HEIGHT)
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + STYLES[row]))
			resized.save_png(ProjectSettings.globalize_path("%s%s/%s.png" % [OUT, STYLES[row], NAMES[column]]))
	print("sliced 48 glyphs")
	quit(0)


func _row_hits(image: Image, threshold: float) -> Array:
	var hits: Array = []
	for y: int in range(image.get_height()):
		var seen: bool = false
		for x: int in range(0, image.get_width(), 2):
			if image.get_pixel(x, y).a > threshold:
				seen = true
				break
		hits.append(seen)
	return hits


func _bands(hits: Array, min_gap: int) -> Array:
	var bands: Array = []
	var start: int = -1
	var last: int = -1
	for index: int in range(hits.size()):
		if hits[index]:
			if start < 0:
				start = index
			elif index - last > min_gap:
				bands.append(Vector2i(start, last))
				start = index
			last = index
	if start >= 0:
		bands.append(Vector2i(start, last))
	return bands


## The 12 glyph images of one row, left to right, each holding only its own pixels (the neighbours' pixels removed). The
## image of a glyph is `rows` high (the row band), trimmed left and right.
func _glyphs_of_row(image: Image, top: int, bottom: int) -> Array:
	var width: int = image.get_width()
	var rows: int = bottom - top + 1
	var label: PackedInt32Array = PackedInt32Array()
	label.resize(width * rows)
	label.fill(-1)
	# 1. bodies: connected solid pixels
	var bodies: Array = []
	var next_label: int = 0
	for y: int in range(rows):
		for x: int in range(width):
			if label[y * width + x] != -1 or image.get_pixel(x, y + top).a <= CORE_ALPHA:
				continue
			var body: Dictionary = {"count": 0, "sum_x": 0, "min_x": x, "max_x": x}
			var queue: Array = [Vector2i(x, y)]
			label[y * width + x] = next_label
			var head: int = 0
			while head < queue.size():
				var p: Vector2i = queue[head]
				head += 1
				body["count"] = int(body["count"]) + 1
				body["sum_x"] = int(body["sum_x"]) + p.x
				body["min_x"] = mini(int(body["min_x"]), p.x)
				body["max_x"] = maxi(int(body["max_x"]), p.x)
				for d: Vector2i in DIRECTIONS:
					var q: Vector2i = p + d
					if q.x < 0 or q.y < 0 or q.x >= width or q.y >= rows or label[q.y * width + q.x] != -1:
						continue
					if image.get_pixel(q.x, q.y + top).a > CORE_ALPHA:
						label[q.y * width + q.x] = next_label
						queue.append(q)
			bodies.append(body)
			next_label += 1
	next_label = _split_merged_bodies(label, bodies, width, rows, next_label)
	# 2. small bodies (the dot of "!", chips) belong to the nearest big one
	var biggest: int = 0
	for body: Dictionary in bodies:
		biggest = maxi(biggest, int(body["count"]))
	var big: Array = []
	for index: int in range(bodies.size()):
		if float(bodies[index]["count"]) >= float(biggest) * 0.08:
			big.append(index)
	big.sort_custom(func(a: int, b: int) -> bool: return float(bodies[a]["sum_x"]) / float(bodies[a]["count"]) < float(bodies[b]["sum_x"]) / float(bodies[b]["count"]))
	if big.size() != 12:
		push_error("found %d glyph bodies in a row (12 expected)" % big.size())
		return []
	var remap: Dictionary = {}
	for rank: int in range(big.size()):
		remap[big[rank]] = rank
	for index: int in range(bodies.size()):
		if remap.has(index):
			continue
		var centre: float = float(bodies[index]["sum_x"]) / float(bodies[index]["count"])
		var best: int = 0
		var best_distance: float = INF
		for rank: int in range(big.size()):
			var other: float = float(bodies[big[rank]]["sum_x"]) / float(bodies[big[rank]]["count"])
			if absf(other - centre) < best_distance:
				best_distance = absf(other - centre)
				best = rank
		remap[index] = best
	var flood: Array = []
	for i: int in range(label.size()):
		if label[i] >= 0:
			label[i] = int(remap[label[i]])
			flood.append(i)
	# 3. every faint pixel goes to the nearest body (multi-source flood through the visible pixels)
	var cursor: int = 0
	while cursor < flood.size():
		var i: int = flood[cursor]
		cursor += 1
		var x: int = i % width
		var y: int = i / width
		for d: Vector2i in DIRECTIONS:
			var qx: int = x + d.x
			var qy: int = y + d.y
			if qx < 0 or qy < 0 or qx >= width or qy >= rows:
				continue
			var j: int = qy * width + qx
			if label[j] == -1 and image.get_pixel(qx, qy + top).a > FAINT_ALPHA:
				label[j] = label[i]
				flood.append(j)
	# 4. cut each glyph out
	var result: Array = []
	for glyph_index: int in range(12):
		var min_x: int = width
		var max_x: int = 0
		for i: int in range(label.size()):
			if label[i] == glyph_index:
				var x: int = i % width
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
		var glyph := Image.create(max_x - min_x + 1, rows, false, Image.FORMAT_RGBA8)
		for y: int in range(rows):
			for x: int in range(min_x, max_x + 1):
				if label[y * width + x] == glyph_index:
					glyph.set_pixel(x - min_x, y, image.get_pixel(x, y + top))
		result.append(glyph)
	return result


## Resize in premultiplied space so the transparent edge does not pick up a dark or white fringe.
func _resize_premultiplied(source: Image, new_width: int, new_height: int) -> Image:
	var image: Image = source.duplicate()
	image.premultiply_alpha()
	image.resize(new_width, new_height, Image.INTERPOLATE_LANCZOS)
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var c: Color = image.get_pixel(x, y)
			if c.a > 0.001:
				image.set_pixel(x, y, Color(minf(c.r / c.a, 1.0), minf(c.g / c.a, 1.0), minf(c.b / c.a, 1.0), c.a))
			else:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
	return image


## Neighbouring glyphs whose outlines touch come out as one body; cut such a body into as many parts as its width says,
## each cut at the thinnest column near where it should be. Appends the new bodies and returns the next free label.
func _split_merged_bodies(label: PackedInt32Array, bodies: Array, width: int, rows: int, next_label: int) -> int:
	var widths: Array = []
	var biggest: int = 0
	for body: Dictionary in bodies:
		biggest = maxi(biggest, int(body["count"]))
	for body: Dictionary in bodies:
		if float(body["count"]) >= float(biggest) * 0.08:
			widths.append(int(body["max_x"]) - int(body["min_x"]) + 1)
	widths.sort()
	var median: int = int(widths[widths.size() / 2]) if not widths.is_empty() else 1
	var original: int = bodies.size()
	for index: int in range(original):
		var body: Dictionary = bodies[index]
		var span: int = int(body["max_x"]) - int(body["min_x"]) + 1
		var parts: int = int(round(float(span) / float(median)))
		if parts < 2 or float(span) < float(median) * 1.45:
			continue
		var low: int = int(body["min_x"])
		var cuts: Array = []
		for part: int in range(1, parts):
			var expected: int = low + int(round(float(span) * float(part) / float(parts)))
			var best_x: int = expected
			var best_count: int = 1 << 30
			for x: int in range(expected - int(median * 0.25), expected + int(median * 0.25) + 1):
				var solid: int = 0
				for y: int in range(rows):
					if label[y * width + x] == index:
						solid += 1
				if solid < best_count:
					best_count = solid
					best_x = x
			cuts.append(best_x)
		# relabel: each segment after a cut becomes a new body
		var labels: Array = [index]
		for cut_index: int in range(cuts.size()):
			labels.append(next_label + cut_index)
		for y: int in range(rows):
			for x: int in range(low, int(body["max_x"]) + 1):
				if label[y * width + x] != index:
					continue
				var segment: int = 0
				for cut: int in cuts:
					if x >= cut:
						segment += 1
				label[y * width + x] = labels[segment]
		for cut_index: int in range(cuts.size()):
			bodies.append({"count": biggest, "sum_x": 0, "min_x": int(cuts[cut_index]), "max_x": int(body["max_x"])})
		next_label += cuts.size()
		# recompute the centre and size of every part from the pixels
	for index: int in range(bodies.size()):
		var count: int = 0
		var sum_x: int = 0
		var min_x: int = width
		var max_x: int = 0
		for y: int in range(rows):
			for x: int in range(width):
				if label[y * width + x] == index:
					count += 1
					sum_x += x
					min_x = mini(min_x, x)
					max_x = maxi(max_x, x)
		bodies[index]["count"] = maxi(count, 1)
		bodies[index]["sum_x"] = sum_x
		bodies[index]["min_x"] = min_x
		bodies[index]["max_x"] = max_x
	return next_label
