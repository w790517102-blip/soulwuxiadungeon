extends RefCounted
## Target kinds for target selection and skill data, so that "who can I pick" no longer
## means only "an actor". Existing skills keep their `target_scope` strings and the
## existing get_valid_targets_for_* functions; `kind_for_scope` maps the old strings
## onto these kinds for code that wants to start using them.

enum Kind {
	ENEMY_ACTOR,
	ALLY_ACTOR,
	ANY_ACTOR,
	STAGE_ENTITY,
	ALLY_STAGE_ENTITY,
	ENEMY_STAGE_ENTITY,
	ANY_TARGETABLE,
}

const SCOPE_TO_KIND: Dictionary = {
	"enemy_single": Kind.ENEMY_ACTOR, "enemy_all": Kind.ENEMY_ACTOR, "all_enemies": Kind.ENEMY_ACTOR,
	"ally_single": Kind.ALLY_ACTOR, "ally_all": Kind.ALLY_ACTOR, "all_allies": Kind.ALLY_ACTOR,
	"all_single": Kind.ANY_ACTOR, "all": Kind.ANY_ACTOR,
}


static func kind_for_scope(scope: String, fallback: int = Kind.ENEMY_ACTOR) -> int:
	return int(SCOPE_TO_KIND.get(scope, fallback))


## Candidates for `kind`, seen from `user_faction` ("player" or "enemy"). `allies` and
## `enemies` are the user's camp and the opposing camp (actor dictionaries); `registry`
## is a StageEntityRegistry (may be null). Dead actors are dropped unless
## `include_dead`; entities that are not targetable or not alive are always dropped.
static func resolve(kind: int, user_faction: String, allies: Array, enemies: Array, registry: Object, include_dead: bool = false) -> Array:
	var result: Array = []
	if kind in [Kind.ENEMY_ACTOR, Kind.ANY_ACTOR, Kind.ANY_TARGETABLE]:
		result += _actors(enemies, include_dead)
	if kind in [Kind.ALLY_ACTOR, Kind.ANY_ACTOR, Kind.ANY_TARGETABLE]:
		result += _actors(allies, include_dead)
	if registry != null and kind in [Kind.STAGE_ENTITY, Kind.ALLY_STAGE_ENTITY, Kind.ENEMY_STAGE_ENTITY, Kind.ANY_TARGETABLE]:
		for entity: Object in registry.get_targetable_entities():
			var same_side: bool = String(entity.get("faction")) == user_faction
			var opposed: bool = not same_side and String(entity.get("faction")) != "neutral"
			if kind == Kind.ALLY_STAGE_ENTITY and not same_side:
				continue
			if kind == Kind.ENEMY_STAGE_ENTITY and not opposed:
				continue
			result.append(entity)
	return result


static func _actors(party: Array, include_dead: bool) -> Array:
	return party.filter(func(actor: Variant) -> bool:
		return typeof(actor) == TYPE_DICTIONARY and (include_dead or int((actor as Dictionary).get("hp", 0)) > 0)
	)
