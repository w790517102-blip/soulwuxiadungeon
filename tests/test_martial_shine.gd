extends SceneTree
## Every inner force x martial skill pairing must produce a linkage row with a shine tier, derived from data (no per-force
## special cases): a force's boost_weapon matching a skill's weapon_type is a tier-1 武器加成 row; each MartialSynergy record
## is a row with the tier of its linkage_kind.
## Run: --headless --path . --script tests/test_martial_shine.gd

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _run() -> void:
	var db = load("res://scripts/db/SkillDB.gd").new()
	var force_db = load("res://scripts/battlescripts/InnerForceDB.gd").new()
	var synergy = load("res://scripts/battlescripts/MartialSynergy.gd")
	var skills: Array = db.get_all_skills()
	for force_id: String in force_db.INNER_FORCES.keys():
		var force: Dictionary = force_db.get_force(force_id)
		var boost := String(force.get("boost_weapon", ""))
		var matched := 0
		for skill: Dictionary in skills:
			var rows: Array = db.get_inner_force_linkage_entries(skill, {}, force)
			var tier := 0
			for row: Dictionary in rows:
				if bool(row.get("met", false)):
					tier = maxi(tier, int(row.get("tier", 0)))
			var weapon := String(skill.get("weapon_type", ""))
			if boost != "" and weapon == boost:
				matched += 1
				_expect(tier >= 1, "%s x %s (%s) should shine" % [force_id, skill.get("id"), weapon])
			_expect(tier == 0 or tier >= 1, "tier is never negative")
		if boost != "":
			_expect(matched > 0, "%s boosts %s but no skill of that weapon exists" % [force_id, boost])
	for record: Dictionary in synergy.all():
		var skill: Dictionary = db.get_skill(String(record.martial_skill_id))
		var force: Dictionary = force_db.get_force(String(record.inner_skill_id))
		var found := false
		for row: Dictionary in db.get_inner_force_linkage_entries(skill, {}, force):
			if String(row.get("text_long", "")) == String(record.display_description):
				found = true
				_expect(int(row.get("tier", 0)) == synergy.shine_tier(String(record.linkage_kind)), "%s tier" % record.synergy_id)
		_expect(found, "%s row missing" % record.synergy_id)
	if _failures.is_empty():
		print("PASS: martial shine")
		quit(0)
	else:
		for message: String in _failures:
			push_error("FAIL: " + message)
		quit(1)
