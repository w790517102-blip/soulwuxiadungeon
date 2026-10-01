extends "res://scripts/battlescripts/StageEntity.gd"
## 替身符: a one-use paper charm standing in the party's card row. An enemy's single-target
## attack is drawn to it first; one hit of ANY size breaks it and nothing carries over
## to the party. It is not a little tank: HP is only an internal 1, the rule is
## `guard_charges`. Not healable.

var guard_charges: int = 1


func apply_config(config: Dictionary) -> void:
	super.apply_config(config)
	guard_charges = int(config.get("guard_charges", 1))
	damageable = true
	healable = false
	max_hp = 1
	current_hp = 1 if guard_charges > 0 else 0


func is_alive() -> bool:
	return guard_charges > 0


## A hit of any size spends the charge; the damage is absorbed, never passed on.
func take_damage(amount: int, _context: Dictionary = {}) -> Dictionary:
	if guard_charges <= 0 or amount <= 0:
		return {"damage": 0, "destroyed": guard_charges <= 0, "absorbed": 0}
	guard_charges -= 1
	current_hp = 0 if guard_charges <= 0 else 1
	changed.emit(self)
	return {"damage": amount, "destroyed": guard_charges <= 0, "absorbed": amount}


## Enemies strongly prefer the talisman over any actor (a big score, not a coin flip).
func modify_target_priority(attacker: Variant, candidate: Variant, score: float) -> float:
	if is_self(candidate) and attacker is Dictionary and is_alive():
		var attacker_faction: String = "enemy" if bool((attacker as Dictionary).get("is_enemy", false)) else "player"
		if attacker_faction == faction:
			return score
		return score + 1000000.0
	return score
