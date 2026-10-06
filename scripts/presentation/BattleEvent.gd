extends RefCounted
## Battle Event Presentation - the data side. Gameplay has already decided what happened; this describes it for the
## screen: what kind of event, which icon (if the art exists), what short text, which number, on whom. The renderer
## (BattleEventPresenter) decides how it moves. Nothing here reads a texture to decide anything: a missing icon only
## means the text is shown without it.
##
## Three kinds of information, three different looks:
##   Numeric       DAMAGE / HEAL: a number (damage accumulates over the strikes of one action)
##   Status/Event  CRITICAL ... STATUS_REMOVED: icon + short text beside the target
##   Announcement  ANNOUNCE: "第 3 回合開始", centred, no icon

const StatusDisplay = preload("res://scripts/db/StatusDisplayDB.gd")
const InspectData = preload("res://scripts/presentation/CardInspectData.gd")

# event_type
const DAMAGE := "damage"
const HEAL := "heal"
const MISS := "miss"
const BLOCK := "block"
const INTERCEPT := "intercept"
const IMMUNE := "immune"
const NULLIFIED := "nullified"
const STATUS_APPLIED := "status_applied"
const STATUS_REMOVED := "status_removed"
const CRITICAL := "critical"
const COUNTER := "counter"
const ANNOUNCE := "announce"

# result_type of one damaging strike
const NORMAL_HIT := "NORMAL"
const COUNTER_HIT := "COUNTER"
const CRITICAL_HIT := "CRITICAL"
const CRITICAL_COUNTER_HIT := "CRITICAL_COUNTER"

const STATUS_ICON_DIR := "res://assets/UI/card_stage/status/"
const EVENT_ICON_DIR := "res://assets/UI/card_stage/event/"

## Default words of the events that have no status to name them. An icon `event_<key>.png` is picked up from
## EVENT_ICON_DIR once the art exists; until then the word is all there is.
const EVENT_WORDS := {
	MISS: "MISS", BLOCK: "格擋", INTERCEPT: "攔截", IMMUNE: "免疫", NULLIFIED: "無效",
	CRITICAL: "會心", COUNTER: "相剋", STATUS_REMOVED: "解除",
}
const EVENT_ICON_KEYS := {
	MISS: "event_miss", BLOCK: "event_block", INTERCEPT: "event_intercept", IMMUNE: "event_immune",
	NULLIFIED: "event_nullified", CRITICAL: "event_critical", COUNTER: "event_counter", STATUS_REMOVED: "event_status_removed",
}
## Higher is drawn on top / kept longer when the screen is crowded.
const PRIORITY := {ANNOUNCE: 90, INTERCEPT: 60, BLOCK: 55, STATUS_APPLIED: 50, STATUS_REMOVED: 45, IMMUNE: 50, NULLIFIED: 50, MISS: 40, CRITICAL: 30, COUNTER: 30, DAMAGE: 20, HEAL: 20}
const DURATION := {STATUS_APPLIED: 1.5, STATUS_REMOVED: 1.2, ANNOUNCE: 1.6, MISS: 0.9, BLOCK: 0.9, INTERCEPT: 1.1, IMMUNE: 1.0, NULLIFIED: 1.0}

static var _textures: Dictionary = {}


## A generic event record: event_type, icon_key, primary_text, value, target, source, priority, duration.
static func make(event_type: String, target: Variant = null, primary_text: String = "", extra: Dictionary = {}) -> Dictionary:
	var event: Dictionary = {
		"event_type": event_type,
		"icon_key": String(EVENT_ICON_KEYS.get(event_type, "")),
		"primary_text": primary_text if primary_text != "" else String(EVENT_WORDS.get(event_type, "")),
		"value": 0,
		"target": target,
		"source": null,
		"priority": int(PRIORITY.get(event_type, 10)),
		"duration": float(DURATION.get(event_type, 1.0)),
	}
	for key: Variant in extra.keys():
		event[key] = extra[key]
	return event


## A status that was applied (or removed): the icon is the status icon the status row already uses.
static func status(status_id: String, applied: bool, target: Variant = null, source: Variant = null) -> Dictionary:
	var name: String = status_name(status_id)
	return make(STATUS_APPLIED if applied else STATUS_REMOVED, target, name if applied else "%s解除" % name, {
		"icon_key": StatusDisplay.icon_key(status_id), "status_id": status_id, "source": source,
		"is_debuff": InspectData.NEGATIVE.has(status_id) or status_id.begins_with("stat_debuff_"),
	})


static func status_name(status_id: String) -> String:
	return StatusDisplay.display_name(status_id, String(InspectData.STATUS_NAMES.get(status_id, status_id)))


static func announcement(text: String) -> Dictionary:
	return make(ANNOUNCE, null, text, {"icon_key": ""})


## One damaging strike of a damage sequence (the shape the renderer takes).
static func damage_hit(sequence_id: String, target: Variant, hit_index: int, hit_total: int, hit_value: int, cumulative_value: int, result_type: String, is_final_hit: bool) -> Dictionary:
	return make(DAMAGE, target, str(cumulative_value), {
		"sequence_id": sequence_id, "hit_index": hit_index, "hit_total": hit_total, "hit_value": hit_value,
		"cumulative_value": cumulative_value, "value": cumulative_value, "result_type": result_type, "is_final_hit": is_final_hit,
		"icon_key": "",
	})


static func heal_event(target: Variant, amount: int) -> Dictionary:
	return make(HEAL, target, "+%d" % amount, {"value": amount, "icon_key": ""})


static func result_type(crit: bool, counter: bool) -> String:
	if crit and counter:
		return CRITICAL_COUNTER_HIT
	if crit:
		return CRITICAL_HIT
	return COUNTER_HIT if counter else NORMAL_HIT


## The icon of an event, or null when the art is not there (the caller shows the text alone). Cached either way.
static func texture_for(icon_key: String) -> Texture2D:
	if icon_key == "":
		return null
	if _textures.has(icon_key):
		return _textures[icon_key]
	var texture: Texture2D = null
	for directory: String in [STATUS_ICON_DIR, EVENT_ICON_DIR]:
		var path: String = "%s%s.png" % [directory, icon_key]
		if ResourceLoader.exists(path):
			texture = load(path) as Texture2D
			break
	_textures[icon_key] = texture
	return texture
