@tool
class_name ChatterVersionRule
extends Resource

@export var version_id: int = 0
@export var enabled: bool = true
@export var lines: Array[String] = []

func _to_string() -> String:
	var flag := "on" if enabled else "off"
	return "Version %d (%s)" % [version_id, flag]
