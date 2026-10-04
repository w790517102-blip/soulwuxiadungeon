extends RefCounted
## A non-actor thing that stands on the battlefield: an echo, cover, tarot card, trap,
## summon, a skill that lingers... Actors (party / enemies / bosses) are NOT stage
## entities and keep their own dictionaries. Buffs, debuffs and marks are NOT stage
## entities either: they stay attached to whatever they affect.
##
## This is only the shared shape. Nothing here is used by any existing skill. A future
## entity subclasses this (or fills a dictionary through from_dict) and overrides the
## `on_*` hooks it cares about; every hook is a no-op by default.
##
## `entity_type` is a free tag ("echo", "cover", "tarot"...), `faction` is "player",
## "enemy" or "neutral". `card_kind` / `card_config` only tell a renderer how to draw it.

signal changed(entity)

var entity_id: String = ""
var entity_type: String = ""
var display_name: String = ""
var owner_id: String = ""
var faction: String = "neutral"
var targetable: bool = true
var damageable: bool = false
var healable: bool = false
var max_hp: int = 0
var current_hp: int = 0
## Turns the entity stays; -1 = until destroyed.
var duration_turns: int = -1
## Interaction / scheduling priority (higher = earlier); free to use.
var priority: int = 0
var tags: Array[String] = []
## "party" / "enemy": the entity stands IN that camp's card row (counted in positions from
## the outer/left end, guests excluded) instead of floating on its own. "" = not in a row.
var row: String = ""
var row_edge_distance: int = 0
## "none" or "round_end": a row entity advances `advance_amount` positions toward the
## exchange zone when a round ends, and leaves the stage past the edge if expire_at_edge.
var advance_policy: String = "none"
var advance_amount: int = 1
var expire_at_edge: bool = false
## true: the entity has a place in the turn order (ADB) and its own activations, like an actor with no
## command. `turn_speed` decides where it sorts in each new round (higher = earlier).
var joins_turn_order: bool = false
## A stance the entity puts its owner in for as long as it stands ("" = none). The owner's `stance`
## field is set when it appears and cleared when it leaves the stage.
var grants_stance: String = ""
## true: when the card joins the turn order it stands directly to the left of its owner in the row
## (instead of at the far left).
var spawn_beside_owner: bool = false
var turn_speed: int = 999   # unused by the line: cards have no speed
## true: when the character at its right ends his turn, this card goes to the far left with him (hen and chicks).
var follow_topology: bool = false
var card_kind: String = "default"
var card_config: Dictionary = {}
## Free-form data for the entity's own behaviour.
var data: Dictionary = {}


static func from_dict(config: Dictionary) -> RefCounted:
	var entity: RefCounted = load("res://scripts/battlescripts/StageEntity.gd").new()
	entity.apply_config(config)
	return entity


func apply_config(config: Dictionary) -> void:
	for key: String in ["entity_id", "entity_type", "display_name", "owner_id", "faction", "card_kind", "row", "advance_policy", "grants_stance"]:
		if config.has(key):
			set(key, String(config[key]))
	for key: String in ["targetable", "damageable", "healable", "expire_at_edge", "joins_turn_order", "spawn_beside_owner", "follow_topology"]:
		if config.has(key):
			set(key, bool(config[key]))
	for key: String in ["max_hp", "current_hp", "duration_turns", "priority", "row_edge_distance", "advance_amount", "turn_speed"]:
		if config.has(key):
			set(key, int(config[key]))
	if config.has("max_hp") and not config.has("current_hp"):
		current_hp = max_hp
	for tag: Variant in config.get("tags", []):
		tags.append(String(tag))
	card_config = (config.get("card_config", {}) as Dictionary).duplicate(true)
	data = (config.get("data", {}) as Dictionary).duplicate(true)


func is_alive() -> bool:
	return not damageable or current_hp > 0


func has_tag(tag: String) -> bool:
	return tags.has(tag)


## Returns {"damage": dealt, "destroyed": bool}. A non-damageable entity takes nothing.
func take_damage(amount: int, _context: Dictionary = {}) -> Dictionary:
	if not damageable or amount <= 0:
		return {"damage": 0, "destroyed": false}
	var dealt: int = mini(amount, current_hp)
	current_hp -= dealt
	changed.emit(self)
	return {"damage": dealt, "destroyed": current_hp <= 0}


## Returns {"healed": amount}. A non-healable entity takes nothing.
func heal(amount: int, _context: Dictionary = {}) -> Dictionary:
	if not healable or amount <= 0 or max_hp <= 0:
		return {"healed": 0}
	var restored: int = mini(amount, max_hp - current_hp)
	current_hp += restored
	changed.emit(self)
	return {"healed": restored}


## Counts one turn off `duration_turns`. Returns true once it has run out. Nothing calls
## this by itself; whoever owns the entity's timing decides when.
func advance_duration() -> bool:
	if duration_turns < 0:
		return false
	duration_turns = maxi(duration_turns - 1, 0)
	changed.emit(self)
	return duration_turns == 0


## AI hook: given the attacker, one candidate target (an actor dictionary or another
## entity) and the score so far, return the adjusted score. Cover would add to itself:
##   if is_self(candidate): return score + 100.0
func modify_target_priority(_attacker: Variant, _candidate: Variant, score: float) -> float:
	return score


# --- Lifecycle hooks (all no-ops; `context` is a Dictionary the dispatcher fills) ----
func on_spawn(_context: Dictionary) -> void: pass
## The entity's own turn in the order has come (only for entities with joins_turn_order).
func on_activation(_context: Dictionary) -> void: pass
func on_turn_start(_context: Dictionary) -> void: pass
func on_turn_end(_context: Dictionary) -> void: pass
func on_before_action(_context: Dictionary) -> void: pass
func on_after_action(_context: Dictionary) -> void: pass
func on_damage_taken(_context: Dictionary) -> void: pass
func on_healed(_context: Dictionary) -> void: pass
func on_destroyed(_context: Dictionary) -> void: pass
func on_expire(_context: Dictionary) -> void: pass
func on_manual_activate(_context: Dictionary) -> void: pass


## True when `candidate` (an actor dictionary or any entity) is this entity.
func is_self(candidate: Variant) -> bool:
	return candidate is Object and candidate == self
