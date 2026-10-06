extends SceneTree
## One-off tool: shrinks the delivered battle-event banners (large transparent illustrations that carry their own
## word) to 512 px and saves them where BattleEvent looks for them (assets/UI/card_stage/event/event_<name>.png).
## Run: IMGDIR=folder godot --headless --path . --script tools/import_event_banners.gd
## The mapping below is file name in IMGDIR -> event icon key.

const SOURCES := {"55.webp": "event_nullified", "56.webp": "event_intercept", "57.webp": "event_block", "58.webp": "event_miss"}
const SIZE := 512
const OUT := "res://assets/UI/card_stage/event/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for file: String in SOURCES.keys():
		var image := Image.load_from_file("%s/%s" % [OS.get_environment("IMGDIR"), file])
		if image == null or image.is_empty():
			push_error("cannot read " + file)
			continue
		image.convert(Image.FORMAT_RGBA8)
		# premultiplied resize so the soft edges do not get a dark or white fringe
		image.premultiply_alpha()
		image.resize(SIZE, int(round(float(SIZE) * image.get_height() / image.get_width())), Image.INTERPOLATE_LANCZOS)
		for y: int in range(image.get_height()):
			for x: int in range(image.get_width()):
				var c: Color = image.get_pixel(x, y)
				if c.a > 0.001:
					image.set_pixel(x, y, Color(minf(c.r / c.a, 1.0), minf(c.g / c.a, 1.0), minf(c.b / c.a, 1.0), c.a))
				else:
					image.set_pixel(x, y, Color(0, 0, 0, 0))
		image.save_png(ProjectSettings.globalize_path("%s%s.png" % [OUT, SOURCES[file]]))
	print("banners imported")
	quit(0)
