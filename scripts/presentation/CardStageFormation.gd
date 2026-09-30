extends RefCounted
## Card Stage formation: a fixed, readable slot table. Presentation only.
##
## Not a tactics grid. Each side has up to three slots that express
## front/back (X toward the centre + Z toward the camera), fast/slow and
## vanguard/support. Who stands where is decided once per set_teams() from the
## actor's existing `speed` (optional `formation` hint); nothing is written back
## to the actor dictionaries.

enum Role { VANGUARD, MID, SUPPORT }
const ROLE_NAMES: Array[String] = ["vanguard", "mid", "support"]

# Per occupancy: Vector3(distance from centre line, height, depth offset from
# the side's base depth). Index 0 is always the vanguard. The vanguard stands
# nearest the centre exchange zone and nearest the camera; support stands
# outermost and deepest. Height follows a ground plane (nearer = lower, deeper =
# higher), so the slots read as one diagonal converging on the centre.
const LAYOUTS: Dictionary = {
	1: [Vector3(4.9, 0.3, 0.9)],
	2: [Vector3(4.9, -1.0, 0.9), Vector3(6.3, 1.7, -0.7)],
	3: [Vector3(4.8, -1.5, 0.9), Vector3(6.0, 0.85, -0.2), Vector3(6.7, 3.2, -1.2)],
}
const ROLES: Dictionary = {
	1: [Role.VANGUARD],
	2: [Role.VANGUARD, Role.SUPPORT],
	3: [Role.VANGUARD, Role.MID, Role.SUPPORT],
}


static func slot(count: int, rank: int, enemy: bool, base_depth: float) -> Dictionary:
	count = clampi(count, 1, 3)
	rank = clampi(rank, 0, count - 1)
	var layout: Vector3 = LAYOUTS[count][rank]
	var side: float = 1.0 if enemy else -1.0
	var role: int = ROLES[count][rank]
	return {
		"rank": rank,
		"role": role,
		"role_name": ROLE_NAMES[role],
		"position": Vector3(side * layout.x, layout.y, base_depth + layout.z),
	}


## Returns, for each actor index, the slot rank (0 = vanguard). Faster actors
## take the front; ties keep their original order; guests always stand last.
static func assign_ranks(actors: Array) -> Array[int]:
	var order: Array[int] = []
	for index: int in range(actors.size()):
		order.append(index)
	order.sort_custom(func(a: int, b: int) -> bool:
		var actor_a: Dictionary = actors[a]
		var actor_b: Dictionary = actors[b]
		var guest_a: bool = bool(actor_a.get("is_guest", false))
		var guest_b: bool = bool(actor_b.get("is_guest", false))
		if guest_a != guest_b:
			return guest_b
		var hint_a: int = _hint(actor_a)
		var hint_b: int = _hint(actor_b)
		if hint_a != hint_b:
			return hint_a > hint_b
		var speed_a: float = float(actor_a.get("speed", 0))
		var speed_b: float = float(actor_b.get("speed", 0))
		if not is_equal_approx(speed_a, speed_b):
			return speed_a > speed_b
		return a < b
	)
	var ranks: Array[int] = []
	ranks.resize(actors.size())
	for rank: int in range(order.size()):
		ranks[order[rank]] = rank
	return ranks


static func _hint(actor: Dictionary) -> int:
	match String(actor.get("formation", "")):
		"vanguard": return 1
		"support": return -1
	return 0
