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

func _on_body_entered(body: Node2D) -> void:
	if body.name != "LiuYu":
		return
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

	liuyu.enter_danger_zone(zone_id, overrides)

func _on_body_exited(body: Node2D) -> void:
	if body.name != "LiuYu":
		return
	var liuyu = get_node_or_null("/root/GameRoot/LiuYu")
	if liuyu == null:
		push_warning("DangerZone 找不到 /root/GameRoot/LiuYu")
		return
	liuyu.exit_danger_zone(zone_id)
