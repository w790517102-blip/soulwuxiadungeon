extends SceneTree
## 拔劍持鞘 series must be known by 劉語塵 in a new game and in a legacy save that lacks it.
## Run: --headless --path . --script tests/test_liuyu_sheath_known.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var team: Node = root.get_node("TeamData")
	var ids := ["skill_bajian_chishao", "skill_shaojian_lianji", "skill_shouqiao_beibei"]
	team.reset_to_initial_team_state()
	var skills = load("res://scripts/battlescripts/CharacterSkill.gd").new()
	var actor: Dictionary = {"id": "liuyu", "level": 1, "weapon_aptitudes": ["劍", "通用"]}
	var fresh: Array = skills.get_effective_skill_ids_for_actor("liuyu", actor)
	for id: String in ids:
		if not fresh.has(id):
			failures.append("new game: %s missing" % id)
	# a legacy save that stored the old list
	team.import_team_state({"known_skill_ids_by_actor": {"liuyu": ["skill_lianjuejian", "skill_badaozhan"]}})
	var legacy: Array = skills.get_effective_skill_ids_for_actor("liuyu", actor)
	for id: String in ids:
		if not legacy.has(id):
			failures.append("legacy save: %s missing" % id)
	if not legacy.has("skill_lianjuejian"):
		failures.append("legacy save lost an old skill")
	var shared: Array = skills.get_effective_skill_ids_for_actor("shumian", {"id": "shumian", "level": 10, "weapon_aptitudes": ["筆", "劍", "通用"]})
	for id: String in ids:
		if shared.has(id):
			failures.append("%s leaked to shumian" % id)
	if failures.is_empty():
		print("PASS: liuyu sheath skills known")
		quit(0)
	else:
		for f: String in failures:
			push_error("FAIL: " + f)
		quit(1)
