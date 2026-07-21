extends Node2D

@export var overlay_path: NodePath = "BlackOverlay"
@export var fade_duration := 0.6
@export var release_player_after_fade := true
@export var handoff_node_path: NodePath
@export var handoff_method := "start_after_entry_fade"

func _ready() -> void:
	var overlay := get_node_or_null(overlay_path) as ColorRect
	var player := get_node_or_null("/root/GameRoot/LiuYu") as CharacterBody2D
	GlobalState.set_meta("menu_locked", true)
	GlobalState.set_meta("story_scene_entry_fade_active", true)
	if player:
		player.set("can_move", false)
		player.velocity = Vector2.ZERO
		player.set("direction", Vector2.ZERO)

	if overlay == null:
		push_warning("[劇情場景進場] 找不到 BlackOverlay；略過淡出並執行控制交接。")
	else:
		overlay.visible = true
		overlay.modulate.a = 1.0

	await get_tree().process_frame
	await get_tree().physics_frame

	if overlay:
		var tween := overlay.create_tween()
		tween.tween_property(overlay, "modulate:a", 0.0, fade_duration)
		await tween.finished
		overlay.visible = false

	if player:
		player.velocity = Vector2.ZERO
		player.set("direction", Vector2.ZERO)
	GlobalState.set_meta("story_scene_entry_fade_active", false)

	var handoff := get_node_or_null(handoff_node_path) if not handoff_node_path.is_empty() else null
	if handoff and handoff.has_method(handoff_method):
		handoff.call(handoff_method)
		return

	if release_player_after_fade:
		var dialog_manager := get_node_or_null("/root/GameRoot/DialogManager")
		if dialog_manager and bool(dialog_manager.get("dialog_active")):
			push_warning("[劇情場景進場] 發現上一場殘留 dialog_active，於淡出完成後清除。")
			if dialog_manager.has_method("hide_dialog"):
				dialog_manager.call("hide_dialog")
		if player:
			player.set("can_move", true)
		GlobalState.set_meta("yinpingyu_cutscene_busy", false)
		# 白箋居是上一場過場鎖的明確交接點；淡出完成後不保留殘留 ESC 鎖。
		GlobalState.set_meta("menu_locked", false)
