extends "res://scripts/presentation/CardStageTangramSeams.gd"
## Short, crossing silver cuts with a dark core: the card face appears split in space.

const SpatialCuts = preload("res://scripts/presentation/CardStageSpatialCuts.gd")


func setup(card_size: Vector2) -> void:
	_card_size = card_size
	_make_textures()
	for line: Array in SpatialCuts.lines_on_card(card_size):
		var from: Vector2 = line[0]
		var to: Vector2 = line[1]
		var root := Node3D.new()
		add_child(root)
		root.position = Vector3(from.x, from.y, 0.0)
		root.rotation.z = atan2(to.y - from.y, to.x - from.x)
		var length: float = from.distance_to(to)
		var layers: Array = []
		var widths: Array[float] = [0.05, 0.016, 0.004]
		var colours: Array[Color] = [
			Color(0.45, 0.68, 0.78, 0.14),
			Color(0.89, 0.94, 0.91, 0.6),
			Color(0.025, 0.035, 0.045, 0.9),
		]
		for index: int in range(widths.size()):
			var quad: MeshInstance3D = _sprite(_beam_texture, Vector2(length, card_size.x * widths[index]), colours[index])
			# Spatial cuts stay on their own card instead of drawing over a nearer ally.
			(quad.material_override as StandardMaterial3D).no_depth_test = false
			(quad.material_override as StandardMaterial3D).render_priority = 0
			if index == 2:
				(quad.material_override as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_MIX
			quad.position = Vector3(length * 0.5, 0.0, float(index) * 0.007)
			root.add_child(quad)
			layers.append(quad)
		var tip: MeshInstance3D = _sprite(_bead_texture, Vector2.ONE * card_size.x * 0.18, Color(0.9, 1.0, 1.0, 0.9))
		(tip.material_override as StandardMaterial3D).no_depth_test = false
		(tip.material_override as StandardMaterial3D).render_priority = 0
		tip.position.z = 0.03
		root.add_child(tip)
		_beams.append({"root": root, "layers": layers, "bead": tip, "length": length})
	_apply()


func _apply() -> void:
	var flicker: float = 0.88 + 0.12 * sin(_time * 42.0)
	var strength: float = maxf(glow, 0.0) * flicker
	var colours: Array[Color] = [
		Color(0.45, 0.68, 0.78, 0.14),
		Color(0.89, 0.94, 0.91, 0.6),
		Color(0.025, 0.035, 0.045, 0.9),
	]
	for index: int in range(_beams.size()):
		var beam: Dictionary = _beams[index]
		var reach: float = clampf(progress * 3.0 - float(index) * 0.32, 0.0, 1.0)
		var root: Node3D = beam.root
		root.visible = reach > 0.0 and glow > 0.0
		if not root.visible:
			continue
		for layer_index: int in range(colours.size()):
			var quad: MeshInstance3D = beam.layers[layer_index]
			quad.scale = Vector3(maxf(reach, 0.001), 1.0, 1.0)
			quad.position.x = float(beam.length) * 0.5 * reach
			var color: Color = colours[layer_index]
			(quad.material_override as StandardMaterial3D).albedo_color = Color(color.r, color.g, color.b, minf(1.0, color.a * strength))
		var bead: MeshInstance3D = beam.bead
		bead.position.x = float(beam.length) * reach
		bead.visible = reach < 1.0
		(bead.material_override as StandardMaterial3D).albedo_color.a = minf(0.9, 0.9 * strength)
