extends SceneTree
## Multi-strike skills log ONE entry for the whole action, however many segments land.
## Run with --headless --path . --script tests/test_multi_strike_log.gd.

var _failures: Array[String] = []
var _assertions: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	var fixture: Node = (load("res://scenes/presentation/card_stage_prototype.tscn") as PackedScene).instantiate()
	fixture.auto_start = false
	root.add_child(fixture)
	for frame: int in range(40):
		if fixture.prepared:
			break
		await process_frame
	var controller: Node = fixture.controller
	var context: Dictionary = fixture.build_preview_context()
	var actor: Dictionary = context.player_party[0]
	var skill: Dictionary = (load("res://scripts/db/SkillDB.gd").new() as Node).get_skill("skill_lianjuejian")
	_expect(not skill.is_empty() and int(skill.get("strike_count", 1)) == 3, "連決劍 strikes three times")
	var seen_miss := false
	var seen_all_hit := false
	var seen_crit := false
	for attempt: int in range(60):
		var target: Dictionary = (context.enemy_party[0] as Dictionary).duplicate(true)
		target["hp"] = 100000
		target["max_hp"] = 100000
		target["battle_uid"] = "dummy#%d" % attempt
		seed(1000 + attempt)
		var outcome: Dictionary = controller._execute_single_target_strikes(actor, target, skill, actor.get("inner_force", {}))
		var result: Dictionary = outcome.result
		var log_lines: Array = result.log
		_expect(log_lines.size() == 1, "the whole action is one log entry (attempt %d, got %d)" % [attempt, log_lines.size()])
		var entry: String = String(log_lines[0])
		_expect(entry.contains("第一段") and entry.contains("第二段") and entry.contains("第三段"), "every segment is named in the entry")
		_expect(not entry.contains("——"), "no per-segment headers remain")
		_expect(entry.split("\n").size() >= 3, "flourish, segments and reaction on separate lines of one entry")
		if entry.contains("閃開了攻勢") or entry.contains("讓過了這一擊") or entry.contains("避開了鋒芒"):
			seen_miss = true
			_expect(entry.contains("第") and bool(result.hit) == (entry.contains("傷害")), "the action counts as a hit exactly when some segment did damage")
		else:
			seen_all_hit = true
		if entry.contains("會心一擊"):
			seen_crit = true
			_expect(bool(result.crit), "a critical segment marks the action as critical")
		if attempt == 0:
			print("SAMPLE ENTRY:\n", entry)
	_expect(seen_miss and seen_all_hit, "both dodged and landed segments occur across attempts")
	fixture.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS: ", _assertions, " assertions; multi-strike skills log one entry")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("FAIL: " + failure)
		quit(1)
