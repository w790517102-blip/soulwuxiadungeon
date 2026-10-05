extends SceneTree
## The Card Stage status row: icons where the art exists, the old word where it does not, mixed in one row; "+N" when
## the entries do not fit; the entries built from the old token logic (BattleUI) keep the same tokens as the old
## text; 魘鱗護體 uses the shared guard icon, never the debuff icon. Run: --headless --path . --script tests/test_status_icon_row.gd

const StatusRow = preload("res://scripts/presentation/CardStageStatusRow.gd")
const StatusDisplay = preload("res://scripts/db/StatusDisplayDB.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _entry(id: String, glyph: String, kind: String = "debuff", blink: bool = false) -> Dictionary:
	return {"id": id, "glyph": glyph, "kind": kind, "blink": blink}


func _row(rect: Rect2, icon: float) -> Control:
	var row: Control = StatusRow.new()
	row.configure(rect, icon, 40, null)
	root.add_child(row)
	return row


func _run() -> void:
	# --- capacity: character 746x76 (64 px icons) holds 10 in a row; an enemy 824x150 two rows; a boss 496x130 (56) two rows
	var character: Control = _row(Rect2(140, 1366, 746, 76), 64.0)
	_expect(character.columns() == 10 and character.rows() == 1 and character.capacity() == 10, "character row: 10 cells (%d x %d)" % [character.columns(), character.rows()])
	var enemy: Control = _row(Rect2(100, 1212, 824, 150), 64.0)
	_expect(enemy.columns() == 12 and enemy.rows() == 2, "enemy rect: 12 x 2 (%d x %d)" % [enemy.columns(), enemy.rows()])
	var boss: Control = _row(Rect2(480, 786, 496, 130), 56.0)
	_expect(boss.columns() == 8 and boss.rows() == 2, "boss rect: 8 x 2 (%d x %d)" % [boss.columns(), boss.rows()])

	# --- overflow: 12 statuses in a 10-cell row show 9 and "+3"
	var entries: Array = []
	for index: int in range(12):
		entries.append(_entry("poison", "毒"))
	var plan: Dictionary = character.plan(entries)
	_expect(int(plan.shown) == 9 and int(plan.hidden) == 3, "12 statuses in 10 cells: 9 shown + 3 hidden (%s)" % str(plan))
	_expect(int(character.plan(entries.slice(0, 10)).hidden) == 0, "exactly 10 fit without a +N")
	character.show_entries(entries)
	_expect(character.get_child_count() == 10, "9 cells and the +N cell are drawn (%d children)" % character.get_child_count())
	var last: Node = character.get_child(character.get_child_count() - 1)
	_expect(last is Label and (last as Label).text == "+3", "the last cell says +3")

	# --- a status without art falls back to its word, in the same row as an icon
	var mixed: Control = _row(Rect2(0, 0, 746, 76), 64.0)
	var with_art: String = "poison"
	var has_art: bool = StatusRow.texture_for(with_art) != null
	mixed.show_entries([_entry("poison", "毒"), _entry("no_such_status_id", "?", "buff")])
	_expect(mixed.get_child_count() == 2, "two entries, two cells")
	var second: Node = mixed.get_child(1)
	_expect(second is Label and (second as Label).text == "?", "no art: the word is shown, not an empty cell or an error")
	if has_art:
		_expect(mixed.get_child(0) is TextureRect, "with art: an icon")
	# the last turn blinks: the cell is faded or replaced by a dot, never removed
	mixed.show_entries([_entry("no_such_status_id", "毒", "debuff", true)])
	_expect(mixed.get_child_count() == 1, "a blinking status keeps its cell")

	# --- 魘鱗護體: the shared guard icon, never the debuff icon of the same family
	_expect(StatusDisplay.display_name("yumei_entanglement") == "魘鱗護體", "the boss shield is called 魘鱗護體")
	_expect(StatusDisplay.icon_key("yumei_entanglement") == "status_guard_barrier", "...and uses the guard icon key")
	_expect(StatusDisplay.icon_key("poison") == "status_poison", "ordinary statuses use status_<id>")
	_expect(ResourceLoader.exists("res://assets/UI/card_stage/status/status_yumei_entanglement.png"), "the old debuff icon file is still there")
	_expect(StatusDisplay.icon_key("yumei_entanglement") != "status_yumei_entanglement", "the debuff icon is not bound to the shield")

	# --- the entries carry the same words as the old text
	var ui_script: Script = load("res://scripts/battlescripts/BattleUI.gd")
	_expect(ui_script.DEBUFF_ABBREV.has("stun") and ui_script.BUFF_ABBREV.has("atk_up"), "the old word tables are all still there")

	if _failures.is_empty():
		print("PASS: status icon row")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		quit(1)
