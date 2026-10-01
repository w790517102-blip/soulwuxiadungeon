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


# --- Colour coding of the battle log -------------------------------------------------------
# System lines are yellow; our characters sky blue; skills gold; enemies lavender; damage and
# critical / advantage text red (healing keeps its green). Presentation only: the text the
# combat code produces is unchanged apart from colour tags.

const COLOR_SYSTEM := "#ffe14d"
const COLOR_ALLY := "#6ec6ff"
const COLOR_SKILL := "#f2d46b"
const COLOR_ENEMY := "#c7a6ff"
const COLOR_DAMAGE := "#ff5a5a"
const COLOR_DAMAGE_SOURCE := "#ffd447"  # the tag the combat code uses around damage numbers
const SkillDBScript = preload("res://scripts/db/SkillDB.gd")

var _ally_names: Array[String] = []
var _enemy_names: Array[String] = []
var _skill_names: Array[String] = []
var _token_regex: RegEx = null
var _token_colors: Dictionary = {}
var _tag_regex: RegEx = null


## The party / enemy names to colour. Called when the teams are set.
func set_color_names(allies: Array, enemies: Array) -> void:
	_ally_names.clear()
	_enemy_names.clear()
	for actor: Variant in allies:
		if actor is Dictionary:
			_add_name(_ally_names, String(actor.get("name", "")))
	for actor: Variant in enemies:
		if actor is Dictionary:
			_add_name(_enemy_names, String(actor.get("name", "")))
	_token_regex = null


func _add_name(into: Array[String], value: String) -> void:
	if value.length() >= 2 and not into.has(value):
		into.append(value)


func _build_tokens() -> void:
	if _skill_names.is_empty():
		var db: Node = SkillDBScript.new()
		for skill: Variant in db.get_all_skills():
			if skill is Dictionary:
				_add_name(_skill_names, String(skill.get("name", "")))
		db.free()
	_token_colors.clear()
	# Skills first, then enemies, then our characters: a character's own name wins over a
	# skill that happens to contain it.
	for token: String in _skill_names:
		_token_colors[token] = COLOR_SKILL
	for token: String in _enemy_names:
		_token_colors[token] = COLOR_ENEMY
	for token: String in _ally_names:
		_token_colors[token] = COLOR_ALLY
	_token_colors["會心一擊"] = COLOR_DAMAGE
	var tokens: Array = _token_colors.keys()
	tokens.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var parts: PackedStringArray = []
	for token: String in tokens:
		parts.append(_escape(token))
	_token_regex = RegEx.new()
	_token_regex.compile("|".join(parts))


func _escape(text: String) -> String:
	var out: String = ""
	for index: int in range(text.length()):
		var letter: String = text[index]
		if ".^$*+?()[]{}|\\".contains(letter):
			out += "\\"
		out += letter
	return out


func colorize(text: String) -> String:
	if _token_regex == null:
		_build_tokens()
	if _tag_regex == null:
		_tag_regex = RegEx.new()
		_tag_regex.compile("\\[color=(#[0-9a-fA-F]{6})\\](.*?)\\[/color\\]")
	var result: String = ""
	var cursor: int = 0
	for found: RegExMatch in _tag_regex.search_all(text):
		result += _color_plain(text.substr(cursor, found.get_start() - cursor))
		var colour: String = found.get_string(1)
		if colour.to_lower() == COLOR_DAMAGE_SOURCE:
			colour = COLOR_DAMAGE
		result += "[color=%s]%s[/color]" % [colour, found.get_string(2)]
		cursor = found.get_end()
	result += _color_plain(text.substr(cursor))
	return result


func _color_plain(text: String) -> String:
	if text.is_empty() or _token_regex == null:
		return text
	var result: String = ""
	var cursor: int = 0
	for found: RegExMatch in _token_regex.search_all(text):
		result += text.substr(cursor, found.get_start() - cursor)
		result += "[color=%s]%s[/color]" % [_token_colors.get(found.get_string(), COLOR_ALLY), found.get_string()]
		cursor = found.get_end()
	return result + text.substr(cursor)


func log(text: String) -> void:
	super.log(colorize(text))


func log_narration(text: String) -> void:
	super.log_narration(colorize(text))


func log_system(text: String) -> void:
	_enqueue_line("[color=%s]%s[/color]" % [COLOR_SYSTEM, text])
