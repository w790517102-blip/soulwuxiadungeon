extends RefCounted
## Card Stage character art. The art lives on its own layer behind the card face and
## is cropped to the template's art window. Actors without an entry here keep their
## existing portrait. DBs and the other presentations are untouched.
##
## Two placement modes:
##   "fit"   (party, tall busts)  : square quad of `size`, the face (`focus`, 0..1 with
##                                  y down) lands `target` away from the window centre.
##   "cover" (enemies, landscape) : the image is scaled just enough to cover the whole
##                                  window and slid so `focus` is as close to the window
##                                  centre as the window allows.

const DIR := "res://assets/sprites/battle_cards/"
const ENTRIES: Dictionary = {
	"liuyu": {"path": DIR + "liu_yu_battle_new.webp", "focus": Vector2(0.64, 0.27), "size": 2.6, "target": Vector2(-0.22, 0.15)},
	"shumian": {"path": DIR + "su_mien_battle_new.webp", "focus": Vector2(0.55, 0.30), "size": 2.6, "target": Vector2(-0.24, 0.15)},
	"zuoyin": {"path": DIR + "zuo_yin_battle_new.webp", "focus": Vector2(0.62, 0.27), "size": 2.6, "target": Vector2(-0.22, 0.15)},
	# Enemies: landscape illustrations, `focus` is the subject's centre of interest.
	"molin_yanjiang": {"path": DIR + "enemy_molin_phase1.webp", "mode": "cover", "focus": Vector2(0.50, 0.42)},
	"molin_yanjiang_phase2": {"path": DIR + "enemy_molin_phase2.webp", "mode": "cover", "focus": Vector2(0.50, 0.42)},
	"fidgety_sewer_fish": {"path": DIR + "enemy_fidgety_fish.webp", "mode": "cover", "focus": Vector2(0.42, 0.50)},
	"broken_string_tone_phantom": {"path": DIR + "enemy_broken_string.webp", "mode": "cover", "focus": Vector2(0.50, 0.40)},
	"turbid_tone_phantom": {"path": DIR + "enemy_turbid.webp", "mode": "cover", "focus": Vector2(0.50, 0.40)},
	"broken_talisman_tone_phantom": {"path": DIR + "enemy_broken_talisman.webp", "mode": "cover", "focus": Vector2(0.45, 0.30)},
	"bitterness_tone_phantom": {"path": DIR + "enemy_bitterness.webp", "mode": "cover", "focus": Vector2(0.50, 0.36)},
	"echo_tone_phantom": {"path": DIR + "enemy_echo.webp", "mode": "cover", "focus": Vector2(0.50, 0.38)},
	"fixation_tone_phantom": {"path": DIR + "enemy_fixation.webp", "mode": "cover", "focus": Vector2(0.50, 0.30)},
	"yumei_sewer_bat": {"path": DIR + "enemy_bat.webp", "mode": "cover", "focus": Vector2(0.50, 0.50)},
	"yumei_sewer_rat": {"path": DIR + "enemy_rat.webp", "mode": "cover", "focus": Vector2(0.40, 0.45)},
	"bamboo_wild_boar": {"path": DIR + "enemy_boar.webp", "mode": "cover", "focus": Vector2(0.50, 0.55)},
	"bamboo_bobcat": {"path": DIR + "enemy_bobcat.webp", "mode": "cover", "focus": Vector2(0.40, 0.42)},
	"bamboo_macaque": {"path": DIR + "enemy_macaque.webp", "mode": "cover", "focus": Vector2(0.50, 0.50)},
	"bamboo_poison_snake": {"path": DIR + "enemy_snake.webp", "mode": "cover", "focus": Vector2(0.55, 0.45)},
}
const ALIASES: Dictionary = {
	"liu_yu": "liuyu", "su_mien": "shumian", "zuo_yin": "zuoyin",
	"zuoyin_stalactite_guest": "zuoyin",
}
## Fallback by the portrait file the databases already hand out.
const PORTRAIT_HINTS: Dictionary = {
	"liuyu_battle": "liuyu", "su_mien_battle": "shumian", "zuo_yin_battle": "zuoyin",
	"molingyanjiang_phase1": "molin_yanjiang", "molingyanjiang_phase2": "molin_yanjiang_phase2",
	"fidgety_sewer_fish": "fidgety_sewer_fish", "broken_string_tone_phantom": "broken_string_tone_phantom",
	"turbid_tone_phantom": "turbid_tone_phantom", "broken_talisman_tone_phantom": "broken_talisman_tone_phantom",
	"bitterness_tone_phantom": "bitterness_tone_phantom", "echo_tone_phantom": "echo_tone_phantom",
	"fixation_tone_phantom": "fixation_tone_phantom", "yumei_sewer_bat": "yumei_sewer_bat",
	"yumei_sewer_rat": "yumei_sewer_rat", "wild_boar": "bamboo_wild_boar", "monkey": "bamboo_macaque",
	"poison_snake": "bamboo_poison_snake",
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


## "fit" mode: card-local centre (relative to the window centre) of the art quad so
## that `focus` lands on `target`.
static func quad_center(entry: Dictionary) -> Vector2:
	var focus: Vector2 = entry.focus
	var size: float = entry.size
	var target: Vector2 = entry.target
	return Vector2(target.x - (focus.x - 0.5) * size, target.y - (0.5 - focus.y) * size)


## "cover" mode: {size: Vector2, center: Vector2} relative to the window centre.
static func cover_layout(entry: Dictionary, window_size: Vector2, image_aspect: float) -> Dictionary:
	var height: float = window_size.y
	var width: float = height * image_aspect
	if width < window_size.x:
		width = window_size.x
		height = width / image_aspect
	var size := Vector2(width, height)
	var focus: Vector2 = entry.focus
	var centre := Vector2((0.5 - focus.x) * size.x, (focus.y - 0.5) * size.y)
	# Never slide so far that the window shows empty space.
	var slack := (size - window_size) / 2.0
	centre.x = clampf(centre.x, -slack.x, slack.x)
	centre.y = clampf(centre.y, -slack.y, slack.y)
	return {"size": size, "center": centre}
