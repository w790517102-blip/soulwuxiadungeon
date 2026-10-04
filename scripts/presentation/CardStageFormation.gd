extends RefCounted
## Card Stage line-up, expressed in SCREEN terms and converted to world space with
## the real perspective camera. Presentation only; not a tactics grid and not a set
## of battle roles.
##
## Each camp is ONE row of upright cards along the X axis. How big a card looks is
## decided by its distance from the camera (perspective), never by scale: the party
## camp is placed so its cards are about ALLY_HEIGHT of the screen tall, the enemy
## camp deeper so they are about ENEMY_HEIGHT tall. Both rows stand on one ground
## plane, so the farther enemy feet sit higher on screen.
##
## Speed only decides the initial inner-to-outer order (fastest nearest the
## exchange zone). Order is decided once in set_teams(); buffs never reshuffle it.

## Nominal card height as a fraction of the screen height (card turned square-on).
## A party card turned 45-55 degrees is enlarged on its near edge by perspective, so
## its on-screen height (rotated bounding box) lands at about 4/5, the enemy
## (nearly frontal) at about 2/5.
const ALLY_HEIGHT: float = 0.64
const ENEMY_HEIGHT: float = 0.37
## Screen fraction (from the top) where party card bottoms stand; just above the
## command tray. Enemy feet follow from the shared ground plane.
const ALLY_FEET: float = 0.79
## Row centres and spacing as fractions of the screen WIDTH (16:9 assumed).
const ALLY_LANE: float = 0.285
const ENEMY_LANE: float = 0.82
const ALLY_SPACING: float = 0.145
const ENEMY_SPACING: float = 0.085
const ASPECT: float = 16.0 / 9.0
## A row that carries sub cards keeps its outermost card centre at least this far (screen
## fraction) from the screen edge.
const OUTER_MARGIN: float = 0.12
## Tiny Z offset that orders overlapping cards: the party's fastest steps toward
## the camera; the enemy row stacks outer-in-front so every name stays readable.
const Z_STACK: float = 0.25


## `rank` 0 is the slot nearest the centre. Returns screen-space layout data.
## `size_ratio` shrinks a smaller card (a stage entity) while keeping its feet on the same
## ground line, so its apparent size comes from the card itself, never from scale.
static func slot(count: int, rank: int, enemy: bool, size_ratio: float = 1.0, gaps: Array = []) -> Dictionary:
	count = maxi(count, 1)
	rank = clampi(rank, 0, count - 1)
	var spacing: float = ENEMY_SPACING if enemy else ALLY_SPACING
	var base_spacing: float = spacing
	# A crowded row (4+ cards: actors plus row entities) squeezes to the width a row of 3 uses.
	if count > 3:
		spacing *= 2.0 / float(count - 1)
	var lane: float = ENEMY_LANE if enemy else ALLY_LANE
	var inner_first: float = float(count - 1) / 2.0 - float(rank)
	var screen_x: float = lane - inner_first * spacing if enemy else lane + inner_first * spacing
	# Optional per-boundary gap multipliers (gaps[r - 1] sits between rank r - 1 and rank r): a
	# sub card beside actors needs more room. The innermost card keeps its usual place; the
	# row grows outward, and if it would leave the screen it is squeezed to fit instead of
	# shoving the characters about.
	if gaps.size() == count - 1 and count > 1:
		# A row with a sub card keeps the full spacing and is squeezed only if it runs out of room.
		spacing = base_spacing
		var anchor: float = lane + float(maxi(count, 3) - 1) / 2.0 * spacing if not enemy else lane - float(maxi(count, 3) - 1) / 2.0 * spacing
		var total: float = 0.0
		for gap: Variant in gaps:
			total += float(gap)
		var offset: float = 0.0
		for step: int in range(rank):
			offset += float(gaps[step])
		var room: float = (anchor - OUTER_MARGIN) if not enemy else ((1.0 - OUTER_MARGIN) - anchor)
		var squeeze: float = minf(1.0, room / maxf(total * spacing, 0.0001))
		screen_x = anchor - offset * spacing * squeeze if not enemy else anchor + offset * spacing * squeeze
	var height: float = (ENEMY_HEIGHT if enemy else ALLY_HEIGHT) * size_ratio
	# Same ground plane for both rows: apparent feet offset from the horizon (0.5)
	# shrinks in proportion to the card's apparent size.
	var feet: float = 0.5 + (ALLY_FEET - 0.5) * ((ENEMY_HEIGHT if enemy else ALLY_HEIGHT) / ALLY_HEIGHT)
	var depth_t: float = clampf(float(rank) / 2.0, 0.0, 1.0)
	var z_stack: float = Z_STACK * (depth_t if enemy else 1.0 - depth_t)
	# A row with sub cards: every outer rank stands a little further back so two neighbours never meet in
	# the same plane (their edges would cut into each other).
	if gaps.size() == count - 1 and count > 1 and not enemy:
		z_stack -= 0.12 * float(maxi(rank - 1, 0))
	if count == 1:
		z_stack = Z_STACK * 0.5
	return {"rank": rank, "enemy": enemy, "screen_x": screen_x, "height": height, "feet": feet, "z_stack": z_stack}


## Distance in front of the camera at which a card of `card_height` world units
## fills `fraction` of a vertical field of view of `fov_degrees`.
static func distance_for_fraction(card_height: float, fraction: float, fov_degrees: float) -> float:
	return card_height / (2.0 * tan(deg_to_rad(fov_degrees) / 2.0) * fraction)


static func world_position(layout: Dictionary, card_height: float, camera_z: float, fov_degrees: float) -> Vector3:
	var distance: float = distance_for_fraction(card_height, layout.height, fov_degrees)
	var visible_height: float = 2.0 * distance * tan(deg_to_rad(fov_degrees) / 2.0)
	var centre_from_top: float = layout.feet - layout.height / 2.0
	return Vector3(
		(layout.screen_x - 0.5) * visible_height * ASPECT,
		(0.5 - centre_from_top) * visible_height,
		camera_z - distance + layout.z_stack
	)


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


## Placeholder slot for a stage entity card (small, in its own row below the actors).
## Real layouts (entities that queue in the turn row, covers in front of a camp...) come
## with the systems that need them; this only keeps a variable number of cards apart.
const ENTITY_HEIGHT: float = 0.2
const ENTITY_FEET: float = 0.96
const ENTITY_SPACING: float = 0.07


static func entity_slot(index: int, enemy: bool) -> Dictionary:
	var lane: float = ENEMY_LANE if enemy else ALLY_LANE
	var direction: float = 1.0 if enemy else -1.0
	return {"index": index, "enemy": enemy, "screen_x": lane + direction * float(index) * ENTITY_SPACING, "height": ENTITY_HEIGHT, "feet": ENTITY_FEET, "z_stack": 0.5}
