extends SceneTree
## Basic and water attacks use fist contact sounds; a guard layers its own impact over the weapon.

class ContactStage extends Node:
	signal attack_contact
	var reached_contact := false

	func present_attack(_attacker: Dictionary, _target: Dictionary, _skill: Dictionary, _result: Dictionary) -> void:
		await get_tree().create_timer(0.02).timeout
		reached_contact = true
		attack_contact.emit()


class StageUI extends Node:
	var stage_enabled := true
	var stage: Node = null


var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _sound_name(player: AudioStreamPlayer) -> String:
	return player.stream.resource_path.get_file() if player.stream != null else ""


func _overlay_with_name(player: AudioStreamPlayer, prefix: String) -> AudioStreamPlayer:
	for child: Node in player.get_children():
		if child is AudioStreamPlayer and _sound_name(child as AudioStreamPlayer).begins_with(prefix):
			return child as AudioStreamPlayer
	return null


func _run() -> void:
	var controller: Node = load("res://scripts/presentation/StageBattleController.gd").new()
	var player := AudioStreamPlayer.new()
	root.add_child(player)
	controller.battle_se_player = player
	var enemy: Dictionary = {"id": "enemy", "weapon_1": "槍"}
	var ally: Dictionary = {"id": "liuyu", "defending": false}
	var basic: Dictionary = {"id": "basic_attack"}
	var water: Dictionary = {"id": "skill_molin_water_bullet", "fx_style": "water_bullet", "weapon_type": "通用"}
	_expect(controller._resolve_weapon_se_key(enemy, basic) == "fist", "basic attack uses the fist sound family")
	_expect(controller._resolve_weapon_se_key(enemy, water) == "fist", "water bullet uses the fist sound family")
	controller._play_contact_se(enemy, ally, water, {"hit": true})
	_expect(_sound_name(player).begins_with("SE_fist_hit"), "water bullet contact plays a fist hit")
	controller._play_contact_se(enemy, ally, basic, {"hit": false, "dodged": true})
	var fist_dodge: AudioStreamPlayer = _overlay_with_name(player, "SE_fist_miss")
	_expect(fist_dodge != null, "basic attack dodge plays a fist miss")
	_expect(fist_dodge != null and is_equal_approx(fist_dodge.volume_db, player.volume_db + 4.0), "fist dodge alone gets a 4 dB lift")
	controller._play_contact_se(enemy, ally, water, {"hit": false, "dodged": true})
	_expect(_overlay_with_name(player, "SE_fist_miss") != null, "water bullet dodge plays a fist miss")
	controller._play_contact_se(enemy, ally, {"weapon_type": "槍"}, {"hit": false, "dodged": true})
	_expect(_sound_name(player).begins_with("SE_spear_miss") and is_zero_approx(player.volume_db), "other weapon dodges keep their original level")
	controller._play_contact_se(enemy, ally, {"weapon_type": "槍"}, {"hit": true, "target_defending": true})
	_expect(_sound_name(player).begins_with("SE_spear_hit"), "guard keeps the attacker's spear impact")
	_expect(_overlay_with_name(player, "SE_hit_onguard") != null, "guard sound layers over the weapon")
	controller._play_contact_se(enemy, ally, basic, {"hit": false, "dodged": false, "blocked": true})
	_expect(_sound_name(player).begins_with("SE_fist_hit"), "blocked basic attack is not treated as a dodge")
	var stage_ui := StageUI.new()
	stage_ui.stage = ContactStage.new()
	stage_ui.add_child(stage_ui.stage)
	root.add_child(stage_ui)
	controller.battle_ui = stage_ui
	player.stream = null
	controller._play_attack_se_from_result(enemy, ally, water, {"hit": true})
	_expect(player.stream == null, "stage sound is withheld while damage is calculated")
	await controller._play_attack_cinematic(enemy, ally, water, {"hit": true, "log": []})
	_expect(stage_ui.stage.reached_contact and _sound_name(player).begins_with("SE_fist_hit"), "stage sound plays when the attack reaches contact")
	stage_ui.queue_free()
	player.queue_free()
	controller.free()
	await process_frame
	if _failures.is_empty():
		print("PASS: basic attack, water bullet, dodge, and weapon guard sounds")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		quit(1)
