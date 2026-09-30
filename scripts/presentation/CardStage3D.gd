extends "res://scripts/presentation/CombatStage25D.gd"
## Card Stage: the same camera, background, FX volume and command tray as
## STAGE_25D, with upright portrait cards placed in one row per side (see
## CardStageFormation). The enemy row is on the right and deeper in Z.
## Yaw stays at the inherited baseline; empty slots are not drawn.

const CardStageActorCard = preload("res://scripts/presentation/CardStageActorCard.gd")
const Formation = preload("res://scripts/presentation/CardStageFormation.gd")

## Enemy row depth: clearly deeper than the party row so perspective reads as distance.
const CARD_STAGE_ENEMY_DEPTH: float = -2.0

## actor key -> {rank, position}; read by tests and debug tools.
var slots: Dictionary = {}


func _ready() -> void:
	enemy_depth = CARD_STAGE_ENEMY_DEPTH
	super._ready()


func set_teams(allies: Array, enemies: Array, guest: Dictionary = {}, status_source: Callable = Callable()) -> void:
	_status_source = status_source
	for card in cards.values():
		card.queue_free()
	cards.clear()
	slots.clear()
	var party: Array = allies.duplicate()
	if not guest.is_empty() and party.size() < 3:
		var guest_view: Dictionary = guest.duplicate(true)
		guest_view["is_guest"] = true
		party.append(guest_view)
	_place_side(party, false)
	_place_side(enemies, true)


func _place_side(actors: Array, enemy: bool) -> void:
	var present: Array = []
	for actor: Dictionary in actors:
		if not actor.is_empty():
			present.append(actor)
	var ranks: Array[int] = Formation.assign_ranks(present)
	var base_depth: float = enemy_depth if enemy else player_depth
	for index: int in range(present.size()):
		var actor: Dictionary = present[index]
		var slot: Dictionary = Formation.slot(present.size(), ranks[index], enemy, base_depth)
		var card: Node3D = CardStageActorCard.new()
		actor_root.add_child(card)
		card.configure(actor, enemy, _status_text(actor))
		card.scale = Vector3.ONE
		var side: float = 1.0 if enemy else -1.0
		card.set_home(slot.position, -side * card_yaw_degrees)
		card.slot_rank = slot.rank
		var key: String = actor_key(actor)
		card.name = "Card_%d_%s" % [slot.rank, key.replace("#", "_")]
		cards[key] = card
		slots[key] = slot


# Cards here are portrait-sized, so picking and screen rectangles use each card's
# own size instead of the landscape constant in the inherited implementation.
func card_screen_rect(actor: Dictionary) -> Rect2:
	var card := card_for(actor)
	if not card:
		return Rect2()
	var half: Vector2 = card.card_size / 2.0
	var result := Rect2(camera.unproject_position(card.to_global(Vector3.ZERO)), Vector2.ZERO)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
		result = result.expand(camera.unproject_position(card.to_global(Vector3(corner.x * half.x, corner.y * half.y, 0))))
	return result


func pick_actor(screen_position: Vector2, candidates: Array, include_dead: bool = false) -> Dictionary:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var nearest: float = INF
	var selected: Dictionary = {}
	for actor: Dictionary in candidates:
		var card := card_for(actor)
		if not card or (int(actor.get("hp", 0)) <= 0 and not include_dead):
			continue
		var inverse := card.global_transform.affine_inverse()
		var local_origin: Vector3 = inverse * origin
		var local_direction: Vector3 = inverse.basis * direction
		if absf(local_direction.z) < 0.0001:
			continue
		var distance: float = -local_origin.z / local_direction.z
		var point: Vector3 = local_origin + local_direction * distance
		if distance > 0 and distance < nearest and absf(point.x) < card.card_size.x / 2.0 and absf(point.y) < card.card_size.y / 2.0:
			nearest = distance
			selected = actor
	return selected
