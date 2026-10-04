extends RefCounted
## Who stands next to whom in a camp's ADB row, and which effects that gives them.
##
## A camp's row is the order the turn manager shows (`TurnManager.get_display_row`): index 0 is the
## next to act and stands NEAREST THE EXCHANGE ZONE (the right end of the party's row), the last index
## stands at the far (left) end. Rotation of the order is what moves a stage entity along the row;
## nothing here moves anything.
##
## Neighbours are the entries directly beside an entity in the row. They never reach across another
## card (a stage entity in between blocks the way unless it is itself a legal recipient), and the two
## ends of the row are not neighbours. Effects are grouped in FAMILIES with a stacking rule so the
## same kind of effect never adds up: by default only the highest source counts.

## Effect families and how sources of the same family combine.
const FAMILIES: Dictionary = {
	"DEFENSE_UP": {"stack_rule": "HIGHEST_ONLY"},
	"ATTACK_UP": {"stack_rule": "HIGHEST_ONLY"},
	"STRENGTH_UP": {"stack_rule": "HIGHEST_ONLY"},
	"CONSTITUTION_UP": {"stack_rule": "HIGHEST_ONLY"},
	"AGILITY_UP": {"stack_rule": "HIGHEST_ONLY"},
	"INTELLECT_UP": {"stack_rule": "HIGHEST_ONLY"},
	"LUCK_UP": {"stack_rule": "HIGHEST_ONLY"},
	"DAMAGE_REDUCTION": {"stack_rule": "HIGHEST_ONLY"},
	"PARRY_UP": {"stack_rule": "HIGHEST_ONLY"},
	"STATUS_RESIST": {"stack_rule": "HIGHEST_ONLY"},
}

const BOTH := "both"
const LEFT_ONLY := "left"
const RIGHT_ONLY := "right"


static func is_entity(entry: Variant) -> bool:
	return typeof(entry) == TYPE_DICTIONARY and bool((entry as Dictionary).get("is_stage_entity", false))


## The key that tells two row entries apart (a copy of an actor dictionary still has the same key).
static func key_of(entry: Dictionary) -> String:
	if bool(entry.get("is_stage_entity", false)):
		return "ent:%s" % String(entry.get("entity_id", ""))
	var uid: String = String(entry.get("battle_uid", ""))
	return uid if uid != "" else String(entry.get("id", ""))


static func index_of(row: Array, key: String) -> int:
	for index: int in range(row.size()):
		if key_of(row[index]) == key:
			return index
	return -1


## Positions of the neighbours of the entry at `index`, filtered by `pattern`. The party row is drawn
## with index 0 at the right, so "left" is the next index up and "right" the previous one.
static func neighbour_indices(row: Array, index: int, pattern: String = BOTH) -> Array[int]:
	var found: Array[int] = []
	if index < 0 or index >= row.size():
		return found
	if pattern != LEFT_ONLY and index - 1 >= 0:
		found.append(index - 1)
	if pattern != RIGHT_ONLY and index + 1 < row.size():
		found.append(index + 1)
	return found


## The actors an entity at `index` of `row` touches: a neighbour counts only if it is a living actor
## (a guest included); another stage entity beside it is not a recipient and nothing is skipped over.
static func recipients(row: Array, index: int, pattern: String = BOTH) -> Array:
	var result: Array = []
	for neighbour: int in neighbour_indices(row, index, pattern):
		var entry: Dictionary = row[neighbour]
		if is_entity(entry):
			continue
		if int(entry.get("hp", 0)) <= 0:
			continue
		result.append(entry)
	return result


## Combines effect sources: {family: value}. Same-family sources never add; with HIGHEST_ONLY (the
## default) the largest wins. Each source is a Dictionary {family, value, stack_rule?}.
static func resolve_effects(sources: Array) -> Dictionary:
	var result: Dictionary = {}
	for source_any: Variant in sources:
		if typeof(source_any) != TYPE_DICTIONARY:
			continue
		var source: Dictionary = source_any
		var family: String = String(source.get("family", ""))
		if family == "":
			continue
		var value: float = float(source.get("value", 0.0))
		var rule: String = String(source.get("stack_rule", FAMILIES.get(family, {}).get("stack_rule", "HIGHEST_ONLY")))
		if not result.has(family):
			result[family] = value
		elif rule == "ADD":
			result[family] = float(result[family]) + value
		else:
			result[family] = maxf(float(result[family]), value)
	return result
