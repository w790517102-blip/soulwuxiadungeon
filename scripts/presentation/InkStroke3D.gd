extends Node3D
## The 替身符 glyph in 3D space, written in the supplied order (left to right and slightly
## up, pulled to the lower left, across to the right, pulled to the lower left again down
## to the bottom, drawn back up to the very top without ink, then finally pulled down).
## Two brushes are laid down together: a dry black one that never bleeds and a wet one that
## spreads and softens. The shape comes straight from the supplied glyph image
## (assets/presentation/talisman_glyph_*.png, built from the artist's image).
## Presentation only.

const MASK := "res://assets/presentation/talisman_glyph_mask.png"
const PROGRESS := "res://assets/presentation/talisman_glyph_progress.png"
const SHADER := "res://scripts/presentation/shaders/ink_glyph.gdshader"

## World height of the glyph.
var size: float = 3.0
var _crisp: MeshInstance3D
var _wet: MeshInstance3D
var _crisp_material: ShaderMaterial
var _wet_material: ShaderMaterial
var _reveal: float = 0.0
var _extra_age: float = 0.0
var _fade: float = 0.0
var _pull: float = 0.0
var _built: bool = false


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	var mask: Texture2D = load(MASK) as Texture2D
	var aspect: float = float(mask.get_width()) / float(mask.get_height())
	_wet = _make_layer(false, aspect, 20)
	_crisp = _make_layer(true, aspect, 22)
	_crisp.position.z = 0.01
	_wet_material = _wet.material_override as ShaderMaterial
	_crisp_material = _crisp.material_override as ShaderMaterial


func _make_layer(crisp: bool, aspect: float, priority: int) -> MeshInstance3D:
	var layer := MeshInstance3D.new()
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2(size * aspect, size)
	layer.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = load(SHADER)
	material.set_shader_parameter("mask_tex", load(MASK))
	material.set_shader_parameter("progress_tex", load(PROGRESS))
	material.set_shader_parameter("crisp", crisp)
	material.render_priority = priority
	layer.material_override = material
	add_child(layer)
	return layer


func _set_param(name: StringName, value: float) -> void:
	for material: ShaderMaterial in [_crisp_material, _wet_material]:
		if material:
			material.set_shader_parameter(name, value)


func _set_reveal(value: float) -> void:
	_reveal = value
	_set_param(&"reveal", value)


func _set_extra_age(value: float) -> void:
	_extra_age = value
	_set_param(&"extra_age", value)


func _set_fade(value: float) -> void:
	_fade = value
	_set_param(&"fade", value)


func _set_pull(value: float) -> void:
	_pull = value
	_set_param(&"pull", value)


## Writes the whole glyph over `seconds`; the ink keeps bleeding afterwards.
func draw_stroke(seconds: float) -> void:
	_build()
	var tween := create_tween().set_parallel(true)
	tween.tween_method(_set_reveal, 0.0, 1.02, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_set_extra_age, 0.0, 1.0, seconds + 1.0)
	await get_tree().create_timer(seconds).timeout


## Heartbeat before the burst: two beats. On each, the glyph gives a quick swell and a
## semi-transparent afterimage of it is thrown outward and fades. Then it holds, ready to burst.
func heartbeat(beats: int = 2, beat_seconds: float = 0.8) -> void:
	for beat: int in range(beats):
		_throw_afterimage(0.7)
		var pulse := create_tween()
		pulse.tween_property(self, "scale", Vector3(1.1, 1.1, 1.0), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pulse.tween_property(self, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_SINE)
		await get_tree().create_timer(beat_seconds).timeout


func _throw_afterimage(seconds: float) -> void:
	var ghost := Node3D.new()
	add_child(ghost)
	var aspect: float = float((load(MASK) as Texture2D).get_width()) / float((load(MASK) as Texture2D).get_height())
	var layer := _make_layer(true, aspect, 21)
	remove_child(layer)
	ghost.add_child(layer)
	var material := layer.material_override as ShaderMaterial
	material.set_shader_parameter("reveal", 1.1)
	material.set_shader_parameter("alpha_mul", 0.5)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ghost, "scale", Vector3(1.55, 1.55, 1.0), seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("alpha_mul", value), 0.5, 0.0, seconds)
	tween.chain().tween_callback(ghost.queue_free)


## The mark pulls in tight, then breaks away: used at the moment of the burst.
func contract_and_fade(seconds: float) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_method(_set_pull, 0.0, 1.0, seconds * 0.6)
	tween.tween_method(_set_fade, 0.0, 1.0, seconds).set_delay(seconds * 0.3)
	await tween.finished
