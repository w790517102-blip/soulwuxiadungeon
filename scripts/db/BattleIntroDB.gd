extends RefCounted
class_name BattleIntroDB

const INTRO_LINE_BY_KEY := {
	"yuheng_bamboo_outskirts_random": "霎時間風聲鶴唳，竹影間殺意驟起。",
	"bamboo_grove_suburb": "霎時間風聲鶴唳，竹影間殺意驟起。",
	"yuheng_sewer_random": "潺潺水聲裡，陰濕惡氣貼著牆根湧來。",
	"sewer": "潺潺水聲裡，陰濕惡氣貼著牆根湧來。",
	"yuheng_outskirts": "荒道風緊，來者不善，劍拔弩張。",
	"zueyue_teashop_training": "茶香未散，席間卻已暗自騰起試招的鋒芒。",
	"battle_intro_default": "四周氣氛驟沉，殺機一觸即發。",
	"default": "四周氣氛驟沉，殺機一觸即發。"
}

static func resolve_intro(context: Dictionary, tone_map = null) -> String:
	for key in get_candidate_keys(context):
		if tone_map != null and tone_map.has_method("get_tone_text"):
			var tone_line := String(tone_map.get_tone_text("battle_intro", key, "default")).strip_edges()
			if tone_line != "":
				return tone_line
		if INTRO_LINE_BY_KEY.has(key):
			return String(INTRO_LINE_BY_KEY[key])
	return String(INTRO_LINE_BY_KEY.get("default", ""))

static func get_candidate_keys(context: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	var tone_block: Dictionary = context.get("tone", {})
	_append_key(keys, tone_block.get("intro_key", ""))
	_append_key(keys, tone_block.get("tag", ""))
	_append_key(keys, context.get("battle_tag", ""))
	_append_key(keys, context.get("zone_id", ""))
	_append_key(keys, context.get("map_id", ""))
	_append_key(keys, context.get("scene_name", ""))
	_append_key(keys, tone_block.get("fallback_intro_key", "default"))
	_append_key(keys, "default")
	return keys

static func _append_key(keys: Array[String], raw_value) -> void:
	var key := String(raw_value).strip_edges()
	if key == "" or keys.has(key):
		return
	keys.append(key)
