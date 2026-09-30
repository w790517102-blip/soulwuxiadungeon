extends SceneTree

const TeamDataManagerScript = preload("res://scripts/battlescripts/TeamDataManager.gd")
const InventorySyncScript = preload("res://scripts/battlescripts/InventorySync.gd")

const SHUMIAN_INITIAL_SKILLS := [
	"skill_luobichengshi",
	"skill_mobishuxin",
	"skill_smoky_ink_blind",
	"skill_linfu_humai",
	"skill_zhengxinquan",
]

var _failures: Array[String] = []


func _initialize() -> void:
	_test_exists_unlock_and_reserve_are_separate()
	_test_roster_unlock_survives_export_import()
	_test_companion_insight_requires_roster_unlock()
	_test_shumian_canonical_initial_card()
	_test_initial_card_is_idempotent()
	_test_existing_save_progression_is_preserved()
	_test_alias_uses_one_progression_state()
	_test_shumian_initial_equipment()
	_test_existing_equipment_is_not_reinitialized()

	if _failures.is_empty():
		print("PASS: Phase 3 roster and canonical initial state")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: %s" % failure)
		quit(1)


func _test_exists_unlock_and_reserve_are_separate() -> void:
	var team = _make_team()
	_expect(team.character_exists("shumian"), "Shumian exists before roster unlock")
	_expect(team.character_exists("lieshao"), "Lieshao exists before roster unlock")
	_expect(not team.is_roster_unlocked("shumian"), "existing Shumian starts roster locked")
	_expect(not team.is_roster_unlocked("lieshao"), "existing Lieshao starts roster locked")
	_expect(not team.get_reserve_actor_ids().has("shumian"), "locked Shumian is hidden from reserve")
	team.unlock_roster("shumian")
	_expect(team.get_reserve_actor_ids().has("shumian"), "unlocked Shumian appears in reserve")
	team.current_team_ids = ["liuyu", "shumian"]
	_expect(not team.get_reserve_actor_ids().has("shumian"), "active Shumian is not duplicated in reserve")
	team.free()


func _test_roster_unlock_survives_export_import() -> void:
	var team = _make_team()
	team.unlock_roster("lieshao")
	var saved: Dictionary = team.export_team_state()
	var loaded = TeamDataManagerScript.new()
	loaded.import_team_state(saved)
	_expect(loaded.is_roster_unlocked("lieshao"), "roster unlock survives team-state save/load")
	loaded.free()
	team.free()


func _test_companion_insight_requires_roster_unlock() -> void:
	var team = _make_team()
	_expect(not team.knows_skill("liuyu", "skill_luobichengshi"), "existing but locked Shumian is not a Companion Insight source")
	team.current_team_ids = ["liuyu", "shumian"]
	team.refresh_liuyu_companion_insights()
	_expect(not team.knows_skill("liuyu", "skill_luobichengshi"), "temporary active Shumian still does not unlock Companion Insight")
	team.unlock_roster("shumian")
	_expect(team.knows_skill("liuyu", "skill_luobichengshi"), "roster-unlocked Shumian becomes a Companion Insight source")
	team.free()


func _test_shumian_canonical_initial_card() -> void:
	var team = _make_team()
	var actor: Dictionary = team.get_character_by_id("shumian")
	_expect(int(actor.get("level", 0)) == 6, "new canonical Shumian starts at Lv6")
	_expect(int(actor.get("exp", -1)) == 0, "new canonical Shumian starts with zero EXP")
	_expect(int(actor.get("base_max_hp", 0)) == 190, "Lv6 base HP is produced by five spellcaster growth steps")
	_expect(int(actor.get("base_max_mp", 0)) == 160, "Lv6 base MP is produced by five spellcaster growth steps")
	_expect(team.get_known_skill_ids("shumian") == SHUMIAN_INITIAL_SKILLS, "new Shumian has exactly the five initial Personal Known skills")
	_expect(actor.get("known_inner_force_ids", []) == ["meng_ying_xinfa", "ling_feng_jue"], "new Shumian knows both initial inner forces")
	_expect(String(actor.get("inner_force_id", "")) == "meng_ying_xinfa", "Meng Ying Xinfa is the initial current inner force")
	_expect(String(actor.get("weapon_2", "occupied")) == "", "canonical Shumian has no secondary weapon")
	_expect(int(actor.get("hp", 0)) == int(actor.get("max_hp", -1)), "initial HP is full")
	_expect(int(actor.get("mp", 0)) == int(actor.get("max_mp", -1)), "initial MP is full")
	team.free()


func _test_existing_save_progression_is_preserved() -> void:
	var team = _make_team()
	var actor: Dictionary = team.get_character_by_id("shumian")
	actor["level"] = 12
	actor["exp"] = 31
	actor["inner_force_id"] = "ling_feng_jue"
	team.all_characters["shumian"] = actor
	var legacy_skills: Array = SHUMIAN_INITIAL_SKILLS.duplicate()
	legacy_skills.append_array(["skill_bisaoyanxia", "skill_qihui_talisman"])
	team.known_skill_ids_by_actor["shumian"] = legacy_skills
	var saved: Dictionary = team.export_team_state()
	var loaded = TeamDataManagerScript.new()
	loaded.import_team_state(saved)
	_expect(int(loaded.get_character_by_id("shumian").get("level", 0)) == 12, "existing save keeps Shumian level")
	_expect(int(loaded.get_character_by_id("shumian").get("exp", 0)) == 31, "existing save keeps Shumian EXP")
	_expect(String(loaded.get_character_by_id("shumian").get("inner_force_id", "")) == "ling_feng_jue", "existing save keeps current inner force")
	_expect(loaded.get_known_skill_ids("shumian") == legacy_skills, "existing save keeps learned skills beyond the initial card")
	loaded.free()
	team.free()


func _test_initial_card_is_idempotent() -> void:
	var team = _make_team()
	var actor: Dictionary = team.get_character_by_id("shumian")
	actor["level"] = 8
	actor["exp"] = 17
	team.all_characters["shumian"] = actor
	team.known_skill_ids_by_actor["shumian"].append("skill_bisaoyanxia")
	team._initialize_canonical_character_states_once()
	_expect(int(team.get_character_by_id("shumian").get("level", 0)) == 8, "rebuild does not reset Shumian level")
	_expect(int(team.get_character_by_id("shumian").get("exp", 0)) == 17, "rebuild does not reset Shumian EXP")
	_expect(team.get_known_skill_ids("shumian").has("skill_bisaoyanxia"), "rebuild does not remove learned skills")
	team.free()


func _test_alias_uses_one_progression_state() -> void:
	var team = _make_team()
	_expect(team.canonicalize_actor_id("su_mien") == "shumian", "legacy su_mien resolves to canonical shumian")
	_expect(team.get_character_by_id("su_mien") == team.get_character_by_id("shumian"), "alias reads the canonical progression state")
	_expect(not team.all_characters.has("su_mien"), "alias does not create a second character state")
	team.unlock_roster("su_mien")
	_expect(team.is_roster_unlocked("shumian"), "alias roster unlock writes the canonical ID")
	team.free()


func _test_shumian_initial_equipment() -> void:
	var inventory = InventorySyncScript.new()
	inventory._ready()
	var equipped: Dictionary = inventory.get_equipped("shumian")
	_expect(String(equipped.get("weapon_1", "")) == "ink_brush", "new Shumian has the ink brush in canonical equipment state")
	_expect(String(equipped.get("weapon_2", "")) == "", "new Shumian secondary weapon is empty")
	inventory.ensure_canonical_initial_equipment_once()
	_expect(String(inventory.get_equipped("shumian").get("weapon_1", "")) == "ink_brush", "initial equipment is applied only once")
	inventory.free()


func _test_existing_equipment_is_not_reinitialized() -> void:
	var inventory = InventorySyncScript.new()
	inventory._ready()
	inventory.unequip("weapon_1", "shumian")
	var saved: Dictionary = inventory.export_inventory_state()
	var loaded = InventorySyncScript.new()
	loaded.import_inventory_state(saved)
	loaded._ready()
	_expect(String(loaded.get_equipped("shumian").get("weapon_1", "")) == "", "existing save equipment is not reset to the initial ink brush")
	_expect(not loaded.equipped_by_actor.has("su_mien"), "legacy alias does not create a second equipment state")
	loaded.free()
	inventory.free()


func _make_team():
	var team = TeamDataManagerScript.new()
	team._ready()
	return team


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
