extends RefCounted
## Card Stage character art. The new battle illustrations are tall, transparent
## busts whose hair, sleeves and ink flow past any frame, so they live on their own
## layer instead of being stuffed into the card face. Actors without an entry here
## keep their existing portrait. DBs and the other presentations are untouched.
##
## `focus`  : where the face is in the image (0..1, y down).
## `size`   : world size of the (square) art quad on a 2.3 x 3.45 card.
## `target` : offset from the art-window centre where the face should land.

const ENTRIES: Dictionary = {
	"liuyu": {"path": "res://assets/sprites/battle_cards/liu_yu_battle_new.webp", "focus": Vector2(0.64, 0.27), "size": 2.6, "target": Vector2(-0.22, 0.15)},
	"shumian": {"path": "res://assets/sprites/battle_cards/su_mien_battle_new.webp", "focus": Vector2(0.55, 0.30), "size": 2.6, "target": Vector2(-0.24, 0.15)},
	"zuoyin": {"path": "res://assets/sprites/battle_cards/zuo_yin_battle_new.webp", "focus": Vector2(0.62, 0.27), "size": 2.6, "target": Vector2(-0.22, 0.15)},
}
const ALIASES: Dictionary = {
	"liu_yu": "liuyu", "su_mien": "shumian", "zuo_yin": "zuoyin",
	"zuoyin_stalactite_guest": "zuoyin",
}
## Fallback by the portrait file the databases already hand out.
const PORTRAIT_HINTS: Dictionary = {
	"liuyu_battle": "liuyu", "su_mien_battle": "shumian", "zuo_yin_battle": "zuoyin",
}


static func entry_for(actor: Dictionary) -> Dictionary:
	var key: String = String(actor.get("id", "")).to_lower()
	key = String(ALIASES.get(key, key))
	if not ENTRIES.has(key):
		var base: String = String(actor.get("portrait_path", "")).get_file().get_basename().to_lower()
		for hint: String in PORTRAIT_HINTS.keys():
			if base.begins_with(hint):
				key = String(PORTRAIT_HINTS[hint])
				break
	return ENTRIES.get(key, {})


## Card-local centre of the art quad so that `focus` lands on `target`.
static func quad_center(entry: Dictionary) -> Vector2:
	var focus: Vector2 = entry.focus
	var size: float = entry.size
	var target: Vector2 = entry.target
	return Vector2(target.x - (focus.x - 0.5) * size, target.y - (0.5 - focus.y) * size)
