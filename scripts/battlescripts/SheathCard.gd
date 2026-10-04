extends "res://scripts/battlescripts/StageEntity.gd"
## 持鞘: the scabbard 劉語塵 takes in his left hand with 拔劍持鞘. A real card in the party's row and
## in the turn order (speed 0), with a turn of its own but no player action; its position in the row
## decides what it does (a block while it stands at the right end, a strike with 鞘劍連擊).
## Whether 劉語塵 is holding the sheath is his stance (`stance` = HOLDING_SHEATH); this card only
## drives order, position, turn and the block.

const STANCE_ID := "HOLDING_SHEATH"

## Chance that a hit meant for the owner is blocked outright while this card stands at the right end.
var block_chance: float = 0.5


func apply_config(config: Dictionary) -> void:
	super.apply_config(config)
	joins_turn_order = true
	turn_speed = 0
	duration_turns = -1
	grants_stance = STANCE_ID
	spawn_beside_owner = true
	targetable = false
	damageable = false
	healable = false
	block_chance = float(config.get("block_chance", 0.5))
