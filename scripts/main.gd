extends Node2D

func _ready():
	$CanvasLayer/WhiteFlash.visible = false
	$CanvasLayer/BlackOverlay.visible = false

func _on_start_button_pressed() -> void:
	var flash := $CanvasLayer/WhiteFlash
	flash.visible = true
	flash.modulate.a = 1.0
	flash.create_tween().tween_property(flash, "modulate:a", 0.0, 0.5)

	$SwordSound.play()
	await get_tree().create_timer(1.2).timeout

	var overlay := $CanvasLayer/BlackOverlay
	overlay.visible = true
	overlay.modulate.a = 0.0
	var tween := overlay.create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 1.0)

	# 🎵 BGM 淡出
	if $BGM:  # 如果有這個節點才執行
		tween.tween_property($BGM, "volume_db", -80, 1.0)  # 1 秒內音量淡出到無聲

	await get_tree().create_timer(2.0).timeout

	get_tree().change_scene_to_file("res://scenes/Game.tscn")
