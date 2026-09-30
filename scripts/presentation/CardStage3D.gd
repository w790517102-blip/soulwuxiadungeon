extends "res://scripts/presentation/CombatStage25D.gd"
## Card Stage: the same camera, background, FX volume and command tray as
## STAGE_25D, with cards placed in formation slots (see CardStageFormation).
## Yaw stays at the inherited baseline; empty slots are not drawn.

const CardStageActorCard = preload("res://scripts/presentation/CardStageActorCard.gd")
const Formation = preload("res://scripts/presentation/CardStageFormation.gd")

## actor key -> {rank, role, role_name, position}; read by tests and debug tools.
var slots: Dictionary = {}


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
		card.slot_role = slot.role_name
		var key: String = actor_key(actor)
		card.name = "Card_%s_%s" % [slot.role_name, key.replace("#", "_")]
		cards[key] = card
		slots[key] = slot
