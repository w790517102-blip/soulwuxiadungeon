extends RefCounted
## Card Stage line-up. Presentation only; not a tactics grid and not a set of
## battle roles.
##
## Each side is ONE row of upright cards along the X axis at almost the same
## depth. The enemy row is simply deeper and on the right, so perspective makes
## it look farther away. Speed only decides the initial left-to-right order
## (an ATB-style "who is nearest the exchange zone"): the fastest card stands
## closest to the centre and pokes out a few centimetres toward the camera.
## Order is decided once in set_teams() and never reshuffles on speed buffs.

## Distance between card centres along X (card width is 2.6, so neighbours
## overlap slightly and the nearer one occludes the outer one's inner edge).
const ALLY_SPACING: float = 2.1
const ENEMY_SPACING: float = 2.45
## Lane centre: distance from the centre line to the middle of each side's row.
const ALLY_LANE_X: float = 5.3
const ENEMY_LANE_X: float = 6.3
## Row height (card centre). Same for everyone so the cards share a ground line.
const ROW_Y: float = -0.2
## Fastest card steps forward by this much in Z; each slower neighbour by half less.
const FAST_POKE: float = 0.35


## `rank` 0 is the slot nearest the centre. Returns {rank, position}.
static func slot(count: int, rank: int, enemy: bool, base_depth: float) -> Dictionary:
	count = clampi(count, 1, 3)
	rank = clampi(rank, 0, count - 1)
	var side: float = 1.0 if enemy else -1.0
	var lane_x: float = ENEMY_LANE_X if enemy else ALLY_LANE_X
	# Centre the row in its lane; rank 0 is the inner end.
	var offset: float = (float(rank) - float(count - 1) / 2.0) * (ENEMY_SPACING if enemy else ALLY_SPACING)
	var poke: float = FAST_POKE * (1.0 - float(rank) / 2.0) if count > 1 else FAST_POKE * 0.5
	return {
		"rank": rank,
		"position": Vector3(side * (lane_x + offset), ROW_Y, base_depth + poke),
	}


## Returns, for each actor index, the slot rank (0 = nearest the centre). Faster
## actors take the inner slots; ties keep their original order; guests stand
## outermost. An actor's optional `formation` hint ("inner" / "outer") wins over
## speed.
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
		"inner": return 1
		"outer": return -1
	return 0
