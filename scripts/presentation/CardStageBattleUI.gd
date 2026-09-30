extends "res://scripts/presentation/StageBattleUI.gd"
## CARD_STAGE view. Everything (commands, ItemLists, target picking, log, F8)
## is inherited from STAGE_25D; only the 3D stage it builds is different.

const CardStageScene = preload("res://scenes/presentation/card_stage_3d.tscn")


func _create_stage() -> Node3D:
	return CardStageScene.instantiate()
