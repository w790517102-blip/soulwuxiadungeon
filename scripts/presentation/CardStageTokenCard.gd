extends Node3D
## A small upright "sub card" for a stage entity that stands in a card row (替身符 and any
## later charm / echo / tarot token). The art is the entity's own illustration; the frame
## is the plain gold-on-dark Godot frame (placeholder until a sub-card frame is supplied).
## Same contract as the other entity cards: home_position, home_rotation, card_size,
## interaction_priority, set_home(), refresh(entity). Presentation only.

const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const CANVAS := Vector2(300, 490)
const GOLD := Color("c9a565")
const PAPER := Color("eee4ca")

var entity: Object
var card_size: Vector2 = Vector2(1.5, 2.25)
var home_position: Vector3 = Vector3.ZERO
var home_rotation: Vector3 = Vector3.ZERO
var interaction_priority: int = 0
var is_enemy: bool = false
var slot_rank: int = -1
var card_viewport: SubViewport
var card_mesh: MeshInstance3D
var card_back: MeshInstance3D
var name_label: Label
var badge_label: Label
var _crack_layer: Control
var _flash: ColorRect
var _tween: Tween
var _relocate_tween: Tween


func configure(target_entity: Object) -> void:
	entity = target_entity
	var config: Dictionary = entity.get("card_config")
	card_size = config.get("card_size", card_size)
	interaction_priority = int(config.get("interaction_priority", entity.get("priority")))
	is_enemy = String(entity.get("faction")) == "enemy"
	if card_viewport == null:
		_build(config)
	refresh(entity)


func _build(config: Dictionary) -> void:
	card_viewport = SubViewport.new()
	card_viewport.name = "TokenViewport"
	card_viewport.size = Vector2i(CANVAS * 2.0)
	card_viewport.size_2d_override = Vector2i(CANVAS)
	card_viewport.size_2d_override_stretch = true
	card_viewport.transparent_bg = true
	card_viewport.disable_3d = true
	card_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(card_viewport)
	var root := Control.new()
	root.size = CANVAS
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_viewport.add_child(root)
	_panel(root, Rect2(4, 4, 292, 482), Color("0b1118"), GOLD, 4)
	_panel(root, Rect2(12, 12, 276, 466), Color("101822"), Color("685432"), 1)
	# Art window: the illustration is cover-cropped inside it.
	var window := Control.new()
	window.position = Vector2(22, 62)
	window.size = Vector2(256, 340)
	window.clip_contents = true
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(window)
	var backing := ColorRect.new()
	backing.color = Color(0.82, 0.78, 0.7)
	backing.size = window.size
	window.add_child(backing)
	var art_path: String = String(config.get("art", ""))
	if art_path != "" and ResourceLoader.exists(art_path):
		var art := TextureRect.new()
		art.texture = load(art_path) as Texture2D
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.size = window.size
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		window.add_child(art)
	_panel(root, Rect2(20, 60, 260, 344), Color.TRANSPARENT, GOLD, 2)
	name_label = Label.new()
	name_label.position = Vector2(14, 14)
	name_label.size = Vector2(272, 44)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(name_label, 34, PAPER)
	root.add_child(name_label)
	# One-use mark: a small seal with the remaining charges.
	var seal := _panel(root, Rect2(96, 412, 108, 58), Color("161921"), GOLD, 3)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_label = Label.new()
	badge_label.position = Vector2(96, 412)
	badge_label.size = Vector2(108, 58)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(badge_label, 44, GOLD)
	root.add_child(badge_label)
	# Faction mark: a coloured edge strip (player gold-blue, enemy red).
	var strip := ColorRect.new()
	strip.position = Vector2(28, 472)
	strip.size = Vector2(244, 5)
	strip.color = Color("c9a565") if not is_enemy else Color("b0413a")
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(strip)
	_crack_layer = Control.new()
	_crack_layer.size = CANVAS
	_crack_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crack_layer.hide()
	root.add_child(_crack_layer)
	_flash = ColorRect.new()
	_flash.position = Vector2(12, 12)
	_flash.size = Vector2(276, 466)
	_flash.color = Color.TRANSPARENT
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)
	var mesh := QuadMesh.new()
	mesh.size = card_size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = card_viewport.get_texture()
	card_mesh = MeshInstance3D.new()
	card_mesh.name = "TokenFace"
	card_mesh.mesh = mesh
	card_mesh.material_override = material
	card_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(card_mesh)
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(card_size.x * 0.97, card_size.y * 0.97, 0.04)
	var back_material := StandardMaterial3D.new()
	back_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	back_material.albedo_color = Color("2a1f14")
	back_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	card_back = MeshInstance3D.new()
	card_back.mesh = back_mesh
	card_back.position.z = -0.03
	card_back.material_override = back_material
	card_back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(card_back)


func refresh(target_entity: Object) -> void:
	entity = target_entity
	if name_label:
		name_label.text = String(entity.get("display_name"))
	if badge_label:
		var charges: Variant = entity.get("guard_charges")
		var prefix: String = String((entity.get("card_config") as Dictionary).get("badge_prefix", "×"))
		badge_label.text = "%s%d" % [prefix, int(charges)] if charges != null else ""


func set_home(position_value: Vector3, yaw_degrees: float = 0.0) -> void:
	home_position = position_value
	home_rotation = Vector3(0.0, deg_to_rad(yaw_degrees), 0.0)
	position = home_position
	rotation = home_rotation


func is_spawning() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running() and scale.x < 0.999


func is_relocating() -> bool:
	return _relocate_tween != null and _relocate_tween.is_valid() and _relocate_tween.is_running()


func relocate(new_home: Vector3, _wrap: bool = false, time_scale: float = 1.0) -> void:
	if _relocate_tween and _relocate_tween.is_valid():
		_relocate_tween.kill()
	home_position = new_home
	_relocate_tween = create_tween()
	_relocate_tween.tween_property(self, "position", new_home, 0.4 * time_scale).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func set_fade(amount: float) -> void:
	for mesh: GeometryInstance3D in [card_mesh, card_back]:
		if mesh:
			mesh.transparency = amount


## The card unfolds out of the burst: it grows from a point in space into its slot.
func play_spawn(origin: Vector3) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	var target: Vector3 = home_position
	position = origin
	scale = Vector3.ONE * 0.04
	set_fade(1.0)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "position", target, 0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector3.ONE, 0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_method(set_fade, 1.0, 0.0, 0.375)


func hit_shake() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_flash.color = Color(1.0, 0.95, 0.85, 0.55)
	_tween = create_tween()
	for i: int in range(6):
		var offset := Vector3((-1.0 if i % 2 == 0 else 1.0) * 0.12 * (1.0 - float(i) / 7.0), 0.0, 0.0)
		_tween.tween_property(self, "position", home_position + offset, 0.035)
	_tween.tween_property(self, "position", home_position, 0.04)
	_tween.parallel().tween_property(_flash, "color:a", 0.0, 0.25)
	await _tween.finished


## Cracks open across the paper, then the card tears apart into ink and scraps and fades.
func play_break() -> void:
	_draw_cracks()
	_crack_layer.show()
	_crack_layer.modulate.a = 0.0
	var crack_tween := create_tween()
	crack_tween.tween_property(_crack_layer, "modulate:a", 1.0, 0.14)
	await crack_tween.finished
	_spray_fragments()
	var fade_tween := create_tween().set_parallel(true)
	fade_tween.tween_method(set_fade, 0.0, 1.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade_tween.tween_property(self, "scale", Vector3(1.06, 1.06, 1.0), 0.4)
	fade_tween.tween_property(self, "position", home_position + Vector3(0.0, -0.15, 0.1), 0.4)
	await fade_tween.finished


func _draw_cracks() -> void:
	for child: Node in _crack_layer.get_children():
		child.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(entity.get("entity_id")))
	for branch: int in range(4):
		var line := Line2D.new()
		line.width = 3.0
		line.default_color = Color(0.03, 0.02, 0.02, 0.95)
		var point := Vector2(rng.randf_range(70.0, 230.0), rng.randf_range(80.0, 130.0))
		line.add_point(point)
		for step: int in range(7):
			point += Vector2(rng.randf_range(-34.0, 34.0), rng.randf_range(26.0, 52.0))
			line.add_point(point)
		_crack_layer.add_child(line)


func _spray_fragments() -> void:
	var holder := Node3D.new()
	get_parent().add_child(holder)
	holder.position = home_position
	holder.rotation = home_rotation
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for index: int in range(26):
		var piece := MeshInstance3D.new()
		var ink: bool = index % 3 != 0
		if ink:
			var sphere := SphereMesh.new()
			sphere.radius = rng.randf_range(0.03, 0.09)
			sphere.height = sphere.radius * 2.0
			piece.mesh = sphere
		else:
			var quad := QuadMesh.new()
			quad.size = Vector2(rng.randf_range(0.12, 0.26), rng.randf_range(0.10, 0.22))
			piece.mesh = quad
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color(0.02, 0.02, 0.03, 0.95) if ink else Color(0.86, 0.8, 0.68, 0.95)
		piece.material_override = material
		piece.position = Vector3(rng.randf_range(-card_size.x * 0.4, card_size.x * 0.4), rng.randf_range(-card_size.y * 0.35, card_size.y * 0.4), 0.05)
		holder.add_child(piece)
		var travel := Vector3(rng.randf_range(-1.1, 1.1), rng.randf_range(-1.6, 0.5), rng.randf_range(0.2, 1.1))
		var tween := create_tween().set_parallel(true)
		tween.tween_property(piece, "position", piece.position + travel, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(piece, "rotation", Vector3(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0), rng.randf_range(-4.0, 4.0)), 0.7)
		tween.tween_property(material, "albedo_color:a", 0.0, 0.7).set_delay(0.25)
	get_tree().create_timer(0.95).timeout.connect(holder.queue_free)


func _style_label(label: Label, size: int, color: Color) -> void:
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _panel(parent: Control, rect: Rect2, background: Color, border: Color, width: int) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel
