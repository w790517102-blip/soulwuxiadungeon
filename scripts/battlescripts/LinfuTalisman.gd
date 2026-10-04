extends "res://scripts/battlescripts/StageEntity.gd"
## A 臨符 card (the first is 護脈符): not a buff hung on a character but a real card in the camp's ADB
## row. It has its own place in the turn order and its own activations, and protects whoever stands
## next to it AT THE MOMENT it matters (an enemy really striking), decided from the live row, never at
## cast time. Moving along the row is nothing but the order rotating.
##
## `adjacency_effects` is a list of {family, value, stack_rule?}; `adjacency_pattern` says which
## neighbours it touches ("both", "left", "right"). `duration_turns` counts its OWN activations.

var adjacency_effects: Array = []
var adjacency_pattern: String = "both"


func apply_config(config: Dictionary) -> void:
	super.apply_config(config)
	adjacency_effects = (config.get("adjacency_effects", []) as Array).duplicate(true)
	adjacency_pattern = String(config.get("adjacency_pattern", "both"))
	joins_turn_order = true
	if not config.has("targetable"):
		targetable = false
	if not config.has("duration_turns"):
		duration_turns = 3


## One activation of the card's own turn. Returns true when it has run out and must leave.
func activate(context: Dictionary = {}) -> bool:
	on_activation(context)
	return advance_duration()
