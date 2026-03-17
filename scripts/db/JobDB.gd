extends Node
class_name JobDB

const JOBS := {
	"俠客": {
		"hp_per_level": 20,
		"mp_per_level": 8,
		"atk_per_level": 2,
		"def_per_level": 1,
		"stat_cycle": ["str", "agi", "int", "con", "luck"],
		"stat_to_atk": {"str": 2, "agi": 1, "int": 1},
	},
	"詩人": {
		"hp_per_level": 14,
		"mp_per_level": 12,
		"atk_per_level": 1,
		"def_per_level": 0,
		"stat_cycle": ["int", "str", "int", "agi", "int", "con", "int", "luck"],
		"stat_to_atk": {"int": 3},
	},
	"樂師": {
		"hp_per_level": 16,
		"mp_per_level": 10,
		"atk_per_level": 1,
		"def_per_level": 1,
		"stat_cycle": ["agi", "str", "agi", "int", "agi", "con", "agi", "luck"],
		"stat_to_atk": {"agi": 3},
	},
}

const DEFAULT_JOB := {
	"hp_per_level": 16,
	"mp_per_level": 8,
	"atk_per_level": 1,
	"def_per_level": 1,
	"stat_cycle": ["str", "agi", "int", "con", "luck"],
	"stat_to_atk": {"str": 1},
}

func get_job_def(job_name: String) -> Dictionary:
	var raw = JOBS.get(job_name, DEFAULT_JOB)
	if typeof(raw) != TYPE_DICTIONARY:
		return DEFAULT_JOB.duplicate(true)
	return (raw as Dictionary).duplicate(true)
