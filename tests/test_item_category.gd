extends SceneTree
# 用法：Godot --headless --script tests/test_item_category.gd
var fails := 0
func _expect(c: bool, m: String) -> void:
	if not c:
		fails += 1
		print("FAIL: ", m)
func _init() -> void:
	var C = load("res://scripts/items/ItemCategory.gd")
	_expect(C.category_of({"type": "consumable"}) == "consumable", "consumable")
	_expect(C.category_of({"type": "food"}) == "consumable", "food counts as consumable (藥物)")
	_expect(C.category_of({"type": "equipment"}) == "equipment", "equipment")
	_expect(C.category_of({"type": "book"}) == "book", "book type")
	_expect(C.category_of({"type": "material"}) == "material", "material")
	_expect(C.category_of({"type": "quest"}) == "quest", "quest")
	_expect(C.category_of({"type": "consumable", "category": "book"}) == "book", "explicit category wins")
	for t in ["tool", "misc", "", "weird"]:
		_expect(C.category_of({"type": t}) == "other", "type %s -> other" % t)
	_expect(C.category_of({}) == "other", "empty dict -> other")
	_expect(C.category_of({"type": "consumable", "category": "all"}) == "consumable", "'all' is not an item category")
	_expect(C.matches({"type": "quest"}, "all") and C.matches({"type": "quest"}, "quest") and not C.matches({"type": "quest"}, "book"), "matches()")
	_expect(C.TABS.size() == 7 and C.TABS[0]["id"] == "all" and C.TABS[6]["id"] == "other", "tab order")
	var db = load("res://scripts/db/ItemDB.gd")
	var counts := {"consumable": 0, "book": 0, "equipment": 0, "material": 0, "quest": 0, "other": 0}
	for id in db.ITEM_DEFS.keys():
		var cat: String = C.category_of(db.ITEM_DEFS[id])
		_expect(counts.has(cat), "item %s has a valid category" % id)
		counts[cat] = int(counts.get(cat, 0)) + 1
	print("COUNTS ", counts)
	print("PASS test_item_category" if fails == 0 else "FAIL test_item_category failures=%d" % fails)
	quit(1 if fails else 0)
