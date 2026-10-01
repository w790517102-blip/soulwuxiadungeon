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


# Presentation-only hook: the UI is not told when an enemy's turn begins, so give a
# view that wants to mark the acting enemy (CARD_STAGE) a chance to do so.
func perform_enemy_action(enemy: Dictionary) -> void:
	if battle_ui and battle_ui.has_method("present_turn_marker"):
		battle_ui.present_turn_marker(enemy)
	await super.perform_enemy_action(enemy)
