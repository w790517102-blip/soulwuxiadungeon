extends RefCounted

const YUHENG_SEWER_PRESSURE_V1 := "yuheng_sewer_pressure_v1"

const PROFILES := {
	YUHENG_SEWER_PRESSURE_V1: {
		"pressure_checks": [
			{"distance": 1600.0, "chance": 0.15},
			{"distance": 2000.0, "chance": 0.35},
			{"distance": 2400.0, "chance": 0.85},
		],
		"max_pressure_interval": 400.0,
		"max_pressure_chance": 0.85,
	},
}

# 舊場景若尚未提供 map-level config/table，暫時由這裡承接相容資料；
# 新場景應由 Map / DangerZone 正式提供，不再把地區資料放進角色腳本。
const LEGACY_ZONE_CONFIGS := {
	"yuheng_sewer": {
		"distance_threshold": 240.0,
		"chance": 0.30,
		"cooldown_distance": 280.0,
		"intro_key": "yuheng_sewer_random",
	},
}

const LEGACY_ENCOUNTER_POOLS := {
	"yuheng_sewer": [
		{"w": 40, "enemies": ["yumei_sewer_rat", "yumei_sewer_rat"]},
		{"w": 30, "enemies": ["yumei_sewer_rat", "yumei_sewer_bat"]},
		{"w": 15, "enemies": ["yumei_sewer_bat", "yumei_sewer_bat"]},
		{"w": 10, "enemies": ["yumei_sewer_rat", "yumei_sewer_rat", "yumei_sewer_rat"]},
		{"w": 5, "enemies": ["turbid_tone_phantom", "yumei_sewer_rat"]},
	],
}


static func get_profile(profile_id: String) -> Dictionary:
	var profile_any = PROFILES.get(profile_id, {})
	if typeof(profile_any) != TYPE_DICTIONARY:
		return {}
	return (profile_any as Dictionary).duplicate(true)


static func get_legacy_zone_config(zone_id: String) -> Dictionary:
	var config_any = LEGACY_ZONE_CONFIGS.get(zone_id, {})
	if typeof(config_any) != TYPE_DICTIONARY:
		return {}
	return (config_any as Dictionary).duplicate(true)


static func get_legacy_encounter_pool(zone_id: String) -> Array:
	var pool_any = LEGACY_ENCOUNTER_POOLS.get(zone_id, [])
	if typeof(pool_any) != TYPE_ARRAY:
		return []
	return (pool_any as Array).duplicate(true)
