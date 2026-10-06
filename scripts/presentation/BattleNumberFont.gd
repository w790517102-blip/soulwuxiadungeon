extends RefCounted
## Image digits for the battle popups, with the text label as the fallback. Nothing about the popup depends on the art
## format: this class answers "is there an image set for this style" and builds a row of images for a string; if the
## set is missing (or incomplete) the popup keeps using the font label, so a missing sheet never breaks the numbers.
##
## Art: one png per character in  <DIRECTORY>/<style>/<name>.png  where style is normal / counter / crit / heal and the
## names are 0 1 2 3 4 5 6 7 8 9 plus bang  (12 characters x 4 styles = 48 files). A style is used only if ALL the
## characters that style needs exist. To use a spritesheet or a bitmap font instead, change `texture_for` only.

const STYLES: Array[String] = ["normal", "counter", "crit", "heal"]
const CHARACTERS: Dictionary = {"0": "0", "1": "1", "2": "2", "3": "3", "4": "4", "5": "5", "6": "6", "7": "7", "8": "8", "9": "9", "+": "plus", "!": "bang"}

static var directory: String = "res://assets/UI/card_stage/numbers/"
## Set to false to force the text labels (for comparing, or if a sheet turns out wrong).
static var enabled: bool = true
static var _cache: Dictionary = {}


## "normal" / "counter" / "crit" / "heal" for a BattleEvent result type (crit wins over counter in this version).
static func style_key(result_type: String) -> String:
	match result_type:
		"CRITICAL", "CRITICAL_COUNTER":
			return "crit"
		"COUNTER":
			return "counter"
		"HEAL":
			return "heal"
	return "normal"


static func reset_cache() -> void:
	_cache.clear()


static func texture_for(style: String, character: String) -> Texture2D:
	var name: String = String(CHARACTERS.get(character, ""))
	if name == "":
		return null
	var key: String = "%s|%s|%s" % [directory, style, name]
	if _cache.has(key):
		return _cache[key]
	var texture: Texture2D = null
	var path: String = "%s%s/%s.png" % [directory, style, name]
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	elif path.begins_with("user://") and FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image != null and not image.is_empty():
			texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


## True when every character of `text` has an image in this style.
static func can_render(style: String, text: String) -> bool:
	if not enabled or text == "":
		return false
	for index: int in range(text.length()):
		if texture_for(style, text.substr(index, 1)) == null:
			return false
	return true


## A row of images for `text`, `height` pixels tall, centred in a box of `box` size; null when it cannot be drawn.
static func build_row(style: String, text: String, height: float, box: Vector2) -> Control:
	if not can_render(style, text):
		return null
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", -2)
	row.size = box
	row.position = Vector2(-box.x * 0.5, -box.y * 0.5)
	row.pivot_offset = box * 0.5
	for index: int in range(text.length()):
		var texture: Texture2D = texture_for(style, text.substr(index, 1))
		var image := TextureRect.new()
		image.texture = texture
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var aspect: float = float(texture.get_width()) / maxf(float(texture.get_height()), 1.0)
		image.custom_minimum_size = Vector2(height * aspect, height)
		row.add_child(image)
	return row
