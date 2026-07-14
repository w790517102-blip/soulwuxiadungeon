class_name MapTransitionGuard
extends RefCounted

static func can_transition(body: Node, area: Area2D = null) -> bool:
	if body == null or body.name != "LiuYu":
		return false
	var game_root = body.get_node_or_null("/root/GameRoot")
	if game_root != null and game_root.has_method("can_use_map_transition"):
		return bool(game_root.call("can_use_map_transition", body, area))
	if GlobalState != null:
		if bool(GlobalState.get("is_loading")):
			return false
		if bool(GlobalState.get_meta("map_transition_locked", false)):
			return false
	return true
