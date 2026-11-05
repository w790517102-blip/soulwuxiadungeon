extends "res://scripts/battlescripts/BattleController.gd"

# Presentation-only override. Calculation, targeting, statuses, turn hand-off,
# rewards and story return remain inherited from the production controller.
func _uses_contact_se(skill_data: Dictionary) -> bool:
	return String(skill_data.get("id", "")) == "basic_attack" or String(skill_data.get("fx_style", "")) == "water_bullet"


func _uses_liuyu_single_sword_se(user: Dictionary, target: Dictionary, skill: Dictionary, result: Dictionary) -> bool:
	return String(user.get("id", "")) == "liuyu" and not bool(user.get("is_enemy", false)) \
		and _resolve_weapon_se_key(user, skill) == "sword" \
		and bool(result.get("hit", true)) and not bool(result.get("blocked", false)) \
		and not bool(result.get("target_defending", target.get("defending", false))) \
		and int(result.get("_played_strike_count", (result.get("strikes", []) as Array).size())) <= 1 \
		and String(skill.get("target_scope", "single")) in ["single", "enemy_single"]


func _play_attack_se_from_result(user: Dictionary, target: Dictionary, skill_data: Dictionary, result: Dictionary) -> void:
	# These sounds wait for their visible contact point; damage was already calculated.
	if battle_ui != null and bool(battle_ui.get("stage_enabled")) and (
			_uses_contact_se(skill_data)
			or _uses_liuyu_single_sword_se(user, target, skill_data, result)
			or _is_liuchen_lianjue_four_hit(user, skill_data, int(result.get("_played_strike_count", 0)))
	):
		return
	super._play_attack_se_from_result(user, target, skill_data, result)


func _play_contact_se(attacker: Dictionary, target: Dictionary, skill_data: Dictionary, result: Dictionary) -> void:
	if _uses_liuyu_single_sword_se(attacker, target, skill_data, result):
		preload("res://scripts/presentation/CardStageSound.gd").play(self, "SE_liuyu_sword_attack")
		return
	super._play_attack_se_from_result(attacker, target, skill_data, result)


func _play_attack_cinematic(attacker: Dictionary, target: Dictionary, skill_data: Dictionary, result: Dictionary) -> Array:
	if battle_ui == null or not bool(battle_ui.get("stage_enabled")):
		return await super._play_attack_cinematic(attacker, target, skill_data, result)
	if not target.is_empty():
		var contact_se: Callable = Callable()
		var contact_result: Dictionary = result
		var strikes: Array = result.get("strikes", [])
		var four_hit_contact := _is_liuchen_lianjue_four_hit(attacker, skill_data, strikes.size())
		if four_hit_contact:
			contact_result = result.duplicate()
			contact_result["_played_strike_count"] = strikes.size()
		if _uses_contact_se(skill_data) or four_hit_contact or _uses_liuyu_single_sword_se(attacker, target, skill_data, result):
			contact_se = _play_contact_se.bind(attacker, target, skill_data, contact_result)
			battle_ui.stage.attack_contact.connect(contact_se, CONNECT_ONE_SHOT)
		await battle_ui.stage.present_attack(attacker, target, skill_data, result)
		if contact_se.is_valid() and battle_ui.stage.attack_contact.is_connected(contact_se):
			battle_ui.stage.attack_contact.disconnect(contact_se)
			contact_se.call()
	_update_ui_for_actor(target)
	_update_ui_for_actor(attacker)
	return result.get("log", [])


# Presentation-only hook: the UI is not told when an enemy's turn begins, so give a
# view that wants to mark the acting enemy (CARD_STAGE) a chance to do so.
func perform_enemy_action(enemy: Dictionary) -> void:
	# Wait for the card line-up to finish reshuffling (CARD_STAGE) before this enemy acts.
	if battle_ui and battle_ui.get("stage") and battle_ui.stage.has_method("wait_for_lineup_settled") and bool(battle_ui.get("stage_enabled")):
		await battle_ui.stage.wait_for_lineup_settled()
		while battle_ui.stage.busy:
			await get_tree().process_frame
	if battle_ui and battle_ui.has_method("present_turn_marker"):
		battle_ui.present_turn_marker(enemy)
	await super.perform_enemy_action(enemy)
