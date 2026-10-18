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
	_expect(C.category_of({"type": "food"}) == "consumable", "food counts as consumable")
	_expect(C.category_of({"type": "equipment"}) == "equipment", "equipment")
	_expect(C.category_of({"type": "book"}) == "book", "book type")
	_expect(C.category_of({"type": "consumable", "category": "book"}) == "book", "explicit category wins")
	for t in ["material", "quest", "tool", "misc", "", "weird"]:
		_expect(C.category_of({"type": t}) == "other", "type %s -> other" % t)
	_expect(C.category_of({}) == "other", "empty dict -> other")
	_expect(C.category_of({"type": "consumable", "category": "nonsense"}) == "consumable", "invalid explicit category ignored")
	# 真實道具資料：每個道具都有且只有一個分類；統計各類數量
	var db = load("res://scripts/db/ItemDB.gd")
	var counts := {"consumable": 0, "book": 0, "equipment": 0, "other": 0}
	for id in db.ITEM_DEFS.keys():
		var cat: String = C.category_of(db.ITEM_DEFS[id])
		_expect(counts.has(cat), "item %s has a valid category" % id)
		counts[cat] = int(counts.get(cat, 0)) + 1
	print("COUNTS ", counts)
	print("PASS test_item_category" if fails == 0 else "FAIL test_item_category failures=%d" % fails)
	quit(1 if fails else 0)
