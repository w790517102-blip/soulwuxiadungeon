extends Node
## SpaceWarpFX: a short mirage-like ripple of the space around a hit. A transparent rectangle drawn
## in a canvas layer between the 3D stage and the interface; its shader re-samples the finished
## picture behind it (cards included) through a wavering offset shaped as a ring spreading from the
## contact point. `strength` is how far the picture is pushed (a small share of the screen):
## about 0.010 for an ordinary hit, about 0.022 for a critical one. Presentation only.

const WarpShader = preload("res://scripts/presentation/shaders/space_warp.gdshader")

const NORMAL_STRENGTH := 0.010
const CRITICAL_STRENGTH := 0.022


## Plays one ripple centred on `centre` (a world position in front of the camera) and frees itself.
## `size` is the ripple's width in world units.
static func play_at(host: Node, centre: Vector3, size: float, strength: float, life: float = 0.45, ring_only: bool = false) -> void:
	var camera: Camera3D = host.get_viewport().get_camera_3d()
	if camera == null or not (host is Node3D):
		return
	var world_centre: Vector3 = (host as Node3D).to_global(centre)
	if camera.is_position_behind(world_centre):
		return
	var screen_centre: Vector2 = camera.unproject_position(world_centre)
	var edge: Vector2 = camera.unproject_position(world_centre + camera.global_transform.basis.x * size * 0.5)
	var pixels: float = maxf(absf(edge.x - screen_centre.x) * 2.0, 8.0)
	var warp := new()
	host.add_child(warp)
	warp._run(screen_centre, pixels, strength, life, host.get_viewport().get_visible_rect().size, ring_only)


func _run(screen_centre: Vector2, pixels: float, strength: float, life: float, view: Vector2, ring_only: bool = false) -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1       # above the 3D world, below the interface
	add_child(layer)
	var rect := ColorRect.new()
	rect.size = Vector2.ONE * pixels
	rect.position = screen_centre - rect.size * 0.5
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = WarpShader
	material.set_shader_parameter("strength", strength)
	material.set_shader_parameter("ring_only", 1.0 if ring_only else 0.0)
	material.set_shader_parameter("seed", randf() * 10.0)
	material.set_shader_parameter("aspect", Vector2(1.0, view.x / maxf(view.y, 1.0)))
	rect.material = material
	layer.add_child(rect)
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("t", value), 0.0, 1.0, life)
	tween.tween_callback(queue_free)
