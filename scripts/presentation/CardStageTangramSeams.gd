extends Node3D
## The unseen cuts of a card, shown only by the light that comes out of them. Drawn the way the 真．石破天驚拳 meteors
## are: additive, unshaded quads in 3D (gradient textures, no depth test, high render priority) standing just in front
## of the card, not a 2D overlay. Each cut of the tangram is a beam made of three quads (a wide soft halo, a bright
## band, a thin white core) plus a hot bead at its tip while it is still opening. `progress` (0..1) opens the cuts one
## after another; `glow` is the light in them (above 1 is the flash as the card falls apart). Presentation only.

const Tangram = preload("res://scripts/presentation/CardStageTangram.gd")

## Layers of a beam: width as a fraction of the card's width, colour, how strongly `glow` drives it.
const LAYERS: Array = [
	{"width": 0.20, "color": Color(1.0, 0.70, 0.30, 0.16), "gain": 1.0, "z": 0.00},
	{"width": 0.075, "color": Color(1.0, 0.86, 0.52, 0.42), "gain": 1.0, "z": 0.005},
	{"width": 0.022, "color": Color(1.0, 0.97, 0.86, 1.0), "gain": 0.9, "z": 0.010},
]

static var _beam_texture: Texture2D = null
static var _bead_texture: Texture2D = null

var progress: float = 0.0:
	set(value):
		progress = value
		_apply()
var glow: float = 0.0:
	set(value):
		glow = value
		_apply()

var _cuts: Array = []          # [from, to] in the card plane
var _beams: Array = []         # per cut: {"root": Node3D, "layers": [MeshInstance3D], "bead": MeshInstance3D, "length": float}
var _card_size: Vector2 = Vector2.ONE
var _time: float = 0.0


func setup(card_size: Vector2) -> void:
	_card_size = card_size
	_make_textures()
	for cut: Array in Tangram.CUTS:
		var from: Vector2 = Tangram.to_card_plane(cut[0], card_size)
		var to: Vector2 = Tangram.to_card_plane(cut[1], card_size)
		_cuts.append([from, to])
		var root := Node3D.new()
		add_child(root)
		root.position = Vector3(from.x, from.y, 0.0)
		root.rotation.z = atan2(to.y - from.y, to.x - from.x)
		var length: float = from.distance_to(to)
		var layers: Array = []
		for layer: Dictionary in LAYERS:
			var quad := _sprite(_beam_texture, Vector2(length, card_size.x * float(layer.width)), layer.color)
			quad.position = Vector3(length * 0.5, 0.0, float(layer.z))
			root.add_child(quad)
			layers.append(quad)
		var bead := _sprite(_bead_texture, Vector2.ONE * card_size.x * 0.16, Color(1.0, 0.95, 0.8, 0.9))
		bead.position = Vector3(0.0, 0.0, 0.02)
		root.add_child(bead)
		_beams.append({"root": root, "layers": layers, "bead": bead, "length": length})
	_apply()


func _process(delta: float) -> void:
	_time += delta
	if glow > 0.0:
		_apply()


## How much of cut `index` is open (the cuts open one after another).
func cut_progress(index: int) -> float:
	return clampf(progress * 1.8 - float(index) * 0.14, 0.0, 1.0)


func _apply() -> void:
	var flicker: float = 0.88 + 0.12 * sin(_time * 38.0)
	var strength: float = maxf(glow, 0.0) * flicker
	for index: int in range(_beams.size()):
		var beam: Dictionary = _beams[index]
		var reach: float = cut_progress(index)
		var root: Node3D = beam.root
		root.visible = reach > 0.0 and glow > 0.0
		if not root.visible:
			continue
		# The beam grows from the cut's start along its length.
		for layer_index: int in range(LAYERS.size()):
			var quad: MeshInstance3D = beam.layers[layer_index]
			var layer: Dictionary = LAYERS[layer_index]
			quad.scale = Vector3(maxf(reach, 0.001), 1.0, 1.0)
			quad.position.x = float(beam.length) * 0.5 * reach
			var color: Color = layer.color
			(quad.material_override as StandardMaterial3D).albedo_color = Color(color.r, color.g, color.b, minf(1.0, color.a * strength * float(layer.gain)))
		var bead: MeshInstance3D = beam.bead
		bead.position.x = float(beam.length) * reach
		bead.visible = reach < 1.0
		(bead.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.95, 0.8, minf(0.9, 0.9 * strength))


static func _make_textures() -> void:
	if _beam_texture != null:
		return
	# across the beam: clear at both edges, brightest in the middle
	var across := Gradient.new()
	across.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	across.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var beam := GradientTexture2D.new()
	beam.gradient = across
	beam.fill = GradientTexture2D.FILL_LINEAR
	beam.fill_from = Vector2(0.5, 0.0)
	beam.fill_to = Vector2(0.5, 1.0)
	beam.width = 16
	beam.height = 64
	_beam_texture = beam
	var round := Gradient.new()
	round.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	round.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.95, 0.95, 1.0, 0.6), Color(1, 1, 1, 0)])
	var bead := GradientTexture2D.new()
	bead.gradient = round
	bead.fill = GradientTexture2D.FILL_RADIAL
	bead.fill_from = Vector2(0.5, 0.5)
	bead.fill_to = Vector2(1.0, 0.5)
	bead.width = 64
	bead.height = 64
	_bead_texture = bead


static func _sprite(texture: Texture2D, size: Vector2, color: Color) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_texture = texture
	material.albedo_color = color
	material.no_depth_test = true
	material.render_priority = 45
	mesh.material_override = material
	return mesh
