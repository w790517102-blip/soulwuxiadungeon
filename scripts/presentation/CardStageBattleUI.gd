extends "res://scripts/presentation/StageBattleUI.gd"
## CARD_STAGE view. Everything (commands, ItemLists, target picking, log, F8)
## is inherited from STAGE_25D; only the 3D stage it builds is different.

const CardStageScene = preload("res://scenes/presentation/card_stage_3d.tscn")


func _create_stage() -> Node3D:
	return CardStageScene.instantiate()


func _unhandled_input(event: InputEvent) -> void:
	# Dev aid for yaw comparison (22 / 28 / 32 degrees). Debug builds only.
	if OS.is_debug_build() and stage_enabled and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9 and stage.has_method("cycle_yaw_preset"):
		var yaw: float = stage.cycle_yaw_preset()
		print("Card Stage yaw: %d°" % int(yaw))
		var scene: Node = get_parent().get_parent() if get_parent() else null
		if scene and scene.has_method("_show_presentation_badge") and scene.get("_presentation_badge") != null:
			scene._show_presentation_badge("CARD_STAGE  yaw %d°" % int(yaw))
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)
