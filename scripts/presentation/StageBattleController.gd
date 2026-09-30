extends "res://scripts/battlescripts/BattleController.gd"

# Presentation-only override. Calculation, targeting, statuses, turn hand-off,
# rewards and story return remain inherited from the production controller.
func _play_attack_cinematic(attacker: Dictionary, target: Dictionary, skill_data: Dictionary, result: Dictionary) -> Array:
	if battle_ui == null or not bool(battle_ui.get("stage_enabled")):
		return await super._play_attack_cinematic(attacker, target, skill_data, result)
	if not target.is_empty():
		await battle_ui.stage.present_attack(attacker, target, skill_data, result)
	_update_ui_for_actor(target)
	_update_ui_for_actor(attacker)
	return result.get("log", [])
