extends RefCounted

const EncounterProfiles = preload("res://scripts/encounter/EncounterProfiles.gd")
const MAX_ENCOUNTER_CHANCE := 0.85

signal roll_evaluated(distance: float, chance: float, succeeded: bool)

var _active := false
var _region_id := ""
var _zone_config: Dictionary = {}
var _zone_overrides: Dictionary = {}
var _pressure_profile: Dictionary = {}
var _accumulated_distance := 0.0
var _next_pressure_check_index := 0
var _next_max_pressure_distance := 0.0
var _legacy_cooldown_distance := 0.0


func enter_region(zone_id: String, zone_config: Dictionary, overrides: Dictionary) -> void:
	var region_id := str(
		overrides.get(
			"encounter_region_id",
			zone_config.get("encounter_region_id", zone_id)
		)
	)
	if region_id == "":
		region_id = zone_id
	var region_changed := region_id != _region_id
	if region_changed:
		_reset_pressure()
		_region_id = region_id

	_zone_config = zone_config.duplicate(true)
	_zone_overrides = overrides.duplicate(true)
	_pressure_profile = _resolve_pressure_profile()
	if region_changed or _next_max_pressure_distance <= 0.0:
		_prepare_repeat_milestone()
	_active = true


func leave_region(_zone_id: String) -> void:
	# LiuYu 已先確認離開的是目前 Area；Area 的 zone_id 不一定等於較大的
	# encounter_region_id，因此此處只暫停，不清除該 region 的 pressure。
	_active = false


func suspend() -> void:
	_active = false


func reset_all() -> void:
	_active = false
	_region_id = ""
	_zone_config.clear()
	_zone_overrides.clear()
	_pressure_profile.clear()
	_reset_pressure()


func reset_pressure() -> void:
	_reset_pressure()


func advance_distance(distance: float, rng: RandomNumberGenerator) -> bool:
	if not _active or distance <= 0.0 or rng == null:
		return false
	if not _pressure_profile.is_empty():
		return _advance_pressure(distance, rng)
	return _advance_legacy(distance, rng)


func set_legacy_cooldown(distance: float) -> void:
	if _pressure_profile.is_empty():
		_legacy_cooldown_distance = max(distance, 0.0)


func apply_legacy_refresh_cooldown() -> void:
	if not _pressure_profile.is_empty():
		return
	_accumulated_distance = 0.0
	var threshold := _resolve_legacy_value("distance_threshold", 0.0)
	_legacy_cooldown_distance = max(_legacy_cooldown_distance, threshold * 0.35)


func get_region_id() -> String:
	return _region_id


func get_accumulated_distance() -> float:
	return _accumulated_distance


func uses_pressure_profile() -> bool:
	return not _pressure_profile.is_empty()


func _advance_pressure(distance: float, rng: RandomNumberGenerator) -> bool:
	_accumulated_distance += distance
	var checks_any = _pressure_profile.get("pressure_checks", [])
	var checks: Array = checks_any if typeof(checks_any) == TYPE_ARRAY else []

	while _next_pressure_check_index < checks.size():
		var check_any = checks[_next_pressure_check_index]
		if typeof(check_any) != TYPE_DICTIONARY:
			_next_pressure_check_index += 1
			continue
		var check := check_any as Dictionary
		var milestone: float = max(float(check.get("distance", 0.0)), 0.0)
		if _accumulated_distance < milestone:
			return false
		_next_pressure_check_index += 1
		var chance := _clamp_chance(float(check.get("chance", 0.0)))
		if _roll(rng, milestone, chance):
			_reset_pressure()
			return true

	var interval: float = max(
		float(_pressure_profile.get("max_pressure_interval", 0.0)),
		0.0
	)
	if interval <= 0.0:
		return false
	var chance := _clamp_chance(
		float(_pressure_profile.get("max_pressure_chance", MAX_ENCOUNTER_CHANCE))
	)
	while _accumulated_distance >= _next_max_pressure_distance:
		var milestone := _next_max_pressure_distance
		_next_max_pressure_distance += interval
		if _roll(rng, milestone, chance):
			_reset_pressure()
			return true
	return false


func _advance_legacy(distance: float, rng: RandomNumberGenerator) -> bool:
	if _legacy_cooldown_distance > 0.0:
		_legacy_cooldown_distance = max(_legacy_cooldown_distance - distance, 0.0)
		return false

	var threshold := _resolve_legacy_value("distance_threshold", 0.0)
	if threshold <= 0.0:
		return false
	_accumulated_distance += distance
	if _accumulated_distance < threshold:
		return false

	_accumulated_distance = 0.0
	var chance := clampf(_resolve_legacy_value("chance", 0.0), 0.0, 1.0)
	var succeeded := rng.randf() <= chance
	roll_evaluated.emit(threshold, chance, succeeded)
	if succeeded:
		_reset_pressure()
		return true
	_legacy_cooldown_distance = max(
		_resolve_legacy_value("cooldown_distance", 0.0),
		0.0
	)
	return false


func _roll(rng: RandomNumberGenerator, milestone: float, chance: float) -> bool:
	var succeeded := rng.randf() <= chance
	roll_evaluated.emit(milestone, chance, succeeded)
	return succeeded


func _resolve_pressure_profile() -> Dictionary:
	var inline_any = _zone_overrides.get(
		"encounter_profile",
		_zone_config.get("encounter_profile", {})
	)
	if typeof(inline_any) == TYPE_DICTIONARY and not (inline_any as Dictionary).is_empty():
		return (inline_any as Dictionary).duplicate(true)
	var profile_id := str(
		_zone_overrides.get(
			"encounter_profile_id",
			_zone_config.get("encounter_profile_id", "")
		)
	)
	return EncounterProfiles.get_profile(profile_id)


func _resolve_legacy_value(key: String, fallback: float) -> float:
	if _zone_overrides.has(key):
		return float(_zone_overrides[key])
	return float(_zone_config.get(key, fallback))


func _prepare_repeat_milestone() -> void:
	if _pressure_profile.is_empty():
		_next_max_pressure_distance = 0.0
		return
	var checks_any = _pressure_profile.get("pressure_checks", [])
	var checks: Array = checks_any if typeof(checks_any) == TYPE_ARRAY else []
	var last_distance := 0.0
	for check_any in checks:
		if typeof(check_any) == TYPE_DICTIONARY:
			last_distance = max(last_distance, float((check_any as Dictionary).get("distance", 0.0)))
	var interval: float = max(
		float(_pressure_profile.get("max_pressure_interval", 0.0)),
		0.0
	)
	_next_max_pressure_distance = last_distance + interval


func _reset_pressure() -> void:
	_accumulated_distance = 0.0
	_next_pressure_check_index = 0
	_legacy_cooldown_distance = 0.0
	_prepare_repeat_milestone()


func _clamp_chance(chance: float) -> float:
	return clampf(chance, 0.0, MAX_ENCOUNTER_CHANCE)
