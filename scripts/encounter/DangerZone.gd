extends Area2D

@export var zone_id := ""
@export var distance_threshold_override := -1.0
@export var chance_override := -1.0
@export var cooldown_distance_override := -1.0
@export var intro_key_override := ""

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	_refresh_player_inside_state.call_deferred()

func _on_body_entered(body: Node2D) -> void:
	if body.name != "LiuYu":
		return
	_register_player_inside()

func _on_body_exited(body: Node2D) -> void:
	if body.name != "LiuYu":
		return
	var liuyu = get_node_or_null("/root/GameRoot/LiuYu")
	if liuyu == null:
		push_warning("DangerZone 找不到 /root/GameRoot/LiuYu")
		return
	liuyu.exit_danger_zone(zone_id)

func _refresh_player_inside_state() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	for body in get_overlapping_bodies():
		if body is Node2D and body.name == "LiuYu":
			_register_player_inside()
			return

func _register_player_inside() -> void:
	var liuyu = get_node_or_null("/root/GameRoot/LiuYu")
	if liuyu == null:
		push_warning("DangerZone 找不到 /root/GameRoot/LiuYu")
		return
	var overrides := {}
	if distance_threshold_override >= 0.0:
		overrides["distance_threshold"] = distance_threshold_override
	if chance_override >= 0.0:
		overrides["chance"] = chance_override
	if cooldown_distance_override >= 0.0:
		overrides["cooldown_distance"] = cooldown_distance_override
	if intro_key_override != "":
		overrides["intro_key"] = intro_key_override

	var map_config := _get_map_encounter_config()
	var encounter_table: Array = map_config.get("encounter_table", [])
	var zone_config: Dictionary = map_config.get("zone_config", {})
	liuyu.enter_danger_zone(zone_id, overrides, encounter_table, zone_config)

func _get_map_encounter_config() -> Dictionary:
	var map_node := _find_map_config_provider()
	var encounter_table: Array = []
	var zone_config := {}
	if map_node != null:
		if map_node.has_method("get_encounter_table"):
			var table_any = map_node.call("get_encounter_table", zone_id)
			if typeof(table_any) == TYPE_ARRAY:
				encounter_table = table_any
		if map_node.has_method("get_encounter_zone_config"):
			var config_any = map_node.call("get_encounter_zone_config", zone_id)
			if typeof(config_any) == TYPE_DICTIONARY:
				zone_config = config_any
	return {
		"encounter_table": encounter_table,
		"zone_config": zone_config
	}

func _find_map_config_provider() -> Node:
	var node := get_parent()
	while node != null:
		if node.has_method("get_encounter_table") or node.has_method("get_encounter_zone_config"):
			return node
		node = node.get_parent()
	return null
