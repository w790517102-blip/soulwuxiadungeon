extends "res://scripts/battlescripts/LogPanel.gd"

var stage_active: bool = true
var drawer_open: bool = false

func _input(event: InputEvent) -> void:
	# Reading/scrolling the archive must not silently confirm a combat checkpoint.
	if stage_active and (drawer_open or event is InputEventMouseButton):
		return
	super._input(event)

func accept_checkpoint() -> void:
	handle_message_input()

func _scroll_to_bottom() -> void:
	# Reopening / explicit latest is allowed; incoming log lines cannot move a
	# reader who is browsing the archive, even before the first manual scroll.
	if drawer_open: return
	super._scroll_to_bottom()

func scroll_archive_to_latest() -> void:
	super._scroll_to_bottom()


# --- Coloured copy for the three-line message box -------------------------------------------
# The box under the stage shows the last three lines of this log. It used to copy only the plain
# text, so the colours of the log (system blue, damage yellow, healing green ...) were lost. Every
# queued line is mirrored here per character (colour / bold), exactly as the log parses its own
# tags, so the box can show the same colours.

var _mirror_plain: String = ""
var _mirror_colors: PackedStringArray = PackedStringArray()
var _mirror_bold: PackedByteArray = PackedByteArray()
var _mirror_tags: RegEx = null


func _enqueue_line(text: String) -> void:
	_mirror_line(text)
	super._enqueue_line(text)


func _mirror_line(text: String) -> void:
	if _mirror_tags == null:
		_mirror_tags = RegEx.new()
		_mirror_tags.compile("\\[(color=#[0-9a-fA-F]{6,8}|/color|b|/b)\\]")
	var colour: String = ""
	var bold: int = 0
	var cursor: int = 0
	for found: RegExMatch in _mirror_tags.search_all(text):
		_mirror_append(text.substr(cursor, found.get_start() - cursor), colour, bold)
		var tag: String = found.get_string(1)
		if tag.begins_with("color="):
			colour = tag.trim_prefix("color=")
		elif tag == "/color":
			colour = ""
		elif tag == "b":
			bold = 1
		else:
			bold = 0
		cursor = found.get_end()
	_mirror_append(text.substr(cursor), colour, bold)
	_mirror_append("\n", "", 0)


func _mirror_append(piece: String, colour: String, bold: int) -> void:
	_mirror_plain += piece
	for index: int in range(piece.length()):
		_mirror_colors.append(colour)
		_mirror_bold.append(bold)


## BBCode for the last `max_lines` non-empty lines of `shown` (the log's visible text), with the
## log's own colours. Falls back to plain escaped text if the mirror does not line up.
func recent_bbcode(shown: String, max_lines: int) -> String:
	var aligned: bool = _mirror_plain.begins_with(shown)
	var ranges: Array = []
	var start: int = 0
	while start <= shown.length():
		var end: int = shown.find("\n", start)
		if end < 0:
			end = shown.length()
		if end > start and not shown.substr(start, end - start).strip_edges().is_empty():
			ranges.append([start, end])
		start = end + 1
	var out: String = ""
	for row: int in range(maxi(0, ranges.size() - max_lines), ranges.size()):
		if not out.is_empty():
			out += "\n"
		var span: Array = ranges[row]
		var open_colour: String = ""
		var open_bold: bool = false
		for index: int in range(span[0], span[1]):
			var colour: String = _mirror_colors[index] if aligned else ""
			var bold: bool = aligned and _mirror_bold[index] == 1
			if colour != open_colour or bold != open_bold:
				if open_bold:
					out += "[/b]"
				if open_colour != "":
					out += "[/color]"
				if colour != "":
					out += "[color=%s]" % colour
				if bold:
					out += "[b]"
				open_colour = colour
				open_bold = bold
			var letter: String = shown[index]
			out += "[lb]" if letter == "[" else letter
		if open_bold:
			out += "[/b]"
		if open_colour != "":
			out += "[/color]"
	return out
