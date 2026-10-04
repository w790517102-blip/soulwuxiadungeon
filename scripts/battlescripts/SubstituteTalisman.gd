extends "res://scripts/battlescripts/StageEntity.gd"
## 替身符: a one-use paper charm that stands in the party's row and in the turn order, like the 臨符
## cards. It does not draw anyone's attention and cannot be attacked. Whenever an enemy blow is about
## to land on a CHARACTER standing directly beside it (left or right in the row, nothing between), it
## takes that blow instead, and is spent. It never covers another stage card (not the 持鞘 card, not
## a 臨符), and it cannot reach across a card to a character behind it. One charge covers one blow
## (the first Hit) on each neighbour within one enemy action; it breaks when that action ends.

var guard_charges: int = 1


func apply_config(config: Dictionary) -> void:
	super.apply_config(config)
	guard_charges = int(config.get("guard_charges", 1))
	joins_turn_order = true
	targetable = false
	damageable = false
	healable = false
	max_hp = 1
	current_hp = 1 if guard_charges > 0 else 0


func is_alive() -> bool:
	return guard_charges > 0
