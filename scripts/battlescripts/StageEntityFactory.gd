extends RefCounted
## Builds a stage entity from a skill's `stage_entity` data block. New entity types only
## need a line in TYPES; skills stay data. Unknown types become a plain StageEntity.

const TYPES: Dictionary = {
	"substitute_talisman": "res://scripts/battlescripts/SubstituteTalisman.gd",
	"linfu_talisman": "res://scripts/battlescripts/LinfuTalisman.gd",
}


static func create(config: Dictionary, owner_id: String = "") -> RefCounted:
	var path: String = String(TYPES.get(String(config.get("entity_type", "")), "res://scripts/battlescripts/StageEntity.gd"))
	var entity: RefCounted = load(path).new()
	var merged: Dictionary = config.duplicate(true)
	if owner_id != "":
		merged["owner_id"] = owner_id
	entity.apply_config(merged)
	return entity
