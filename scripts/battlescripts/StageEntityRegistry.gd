extends RefCounted
## Everything non-actor that currently stands on the battlefield. Owned by the battle
## controller (`controller.stage_entities`); presentations listen to its signals to draw
## and remove entity cards. Empty by default, so it changes nothing today.

signal entity_registered(entity)
signal entity_unregistered(entity)
## Every lifecycle event, after the entity's own hook has run.
signal entity_event(entity, event_name, context)

const EVENTS: Array[String] = [
	"on_spawn", "on_activation", "on_turn_start", "on_turn_end", "on_before_action", "on_after_action",
	"on_damage_taken", "on_healed", "on_destroyed", "on_expire", "on_manual_activate",
]

var _entities: Array = []
var _next_serial: int = 1


## Gives the entity its id now (registering does the same if it is called later). Whoever needs the
## id before the entity is shown - e.g. to give it a place in the turn order - calls this first.
func assign_entity_id(entity: Object) -> String:
	if String(entity.get("entity_id")) == "":
		var type_text: String = String(entity.get("entity_type"))
		entity.set("entity_id", "%s#%d" % [type_text if type_text != "" else "entity", _next_serial])
		_next_serial += 1
	return String(entity.get("entity_id"))


func register_stage_entity(entity: Object) -> bool:
	if entity == null or _entities.has(entity):
		return false
	assign_entity_id(entity)
	if get_entity(String(entity.get("entity_id"))) != null:
		return false
	_entities.append(entity)
	entity_registered.emit(entity)
	dispatch_to(entity, "on_spawn", {})
	return true


## Removes an entity without any lifecycle event (use destroy_entity / expire_entity for those).
func unregister_stage_entity(entity: Object) -> bool:
	if not _entities.has(entity):
		return false
	_entities.erase(entity)
	entity_unregistered.emit(entity)
	return true


## on_destroyed, then removal.
func destroy_entity(entity: Object, context: Dictionary = {}) -> void:
	if _entities.has(entity):
		dispatch_to(entity, "on_destroyed", context)
		unregister_stage_entity(entity)


## on_expire, then removal.
func expire_entity(entity: Object, context: Dictionary = {}) -> void:
	if _entities.has(entity):
		dispatch_to(entity, "on_expire", context)
		unregister_stage_entity(entity)


func get_stage_entities() -> Array:
	return _entities.duplicate()


func get_entity(entity_id: String) -> Object:
	for entity: Object in _entities:
		if String(entity.get("entity_id")) == entity_id:
			return entity
	return null


func get_targetable_entities() -> Array:
	return _entities.filter(func(entity: Object) -> bool: return bool(entity.get("targetable")) and entity.is_alive())


func get_entities_by_faction(faction: String) -> Array:
	return _entities.filter(func(entity: Object) -> bool: return String(entity.get("faction")) == faction)


func get_entities_by_tag(tag: String) -> Array:
	return _entities.filter(func(entity: Object) -> bool: return entity.has_tag(tag))


func get_entities_by_owner(owner_id: String) -> Array:
	return _entities.filter(func(entity: Object) -> bool: return String(entity.get("owner_id")) == owner_id)


func is_empty() -> bool:
	return _entities.is_empty()


# --- Lifecycle -------------------------------------------------------------------------

func dispatch_to(entity: Object, event_name: String, context: Dictionary) -> void:
	if entity.has_method(event_name):
		entity.call(event_name, context)
	entity_event.emit(entity, event_name, context)


## Sends a lifecycle event to every entity (in registration order, over a snapshot so
## a hook may register / remove entities).
func dispatch(event_name: String, context: Dictionary = {}) -> void:
	if _entities.is_empty():
		return
	for entity: Object in _entities.duplicate():
		if _entities.has(entity):
			dispatch_to(entity, event_name, context)


# --- AI ----------------------------------------------------------------------------------

## Folds every entity's opinion into one target score. With no entities it returns
## `base_score` untouched.
func modify_target_score(attacker: Variant, candidate: Variant, base_score: float) -> float:
	var score: float = base_score
	for entity: Object in _entities:
		score = float(entity.modify_target_priority(attacker, candidate, score))
	return score
