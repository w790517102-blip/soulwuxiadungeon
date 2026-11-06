extends Node3D
## A small upright "sub card" for a stage entity that stands in a card row (替身符 and any
## later charm / echo / tarot token). The art is the entity's own illustration; the frame
## is the plain gold-on-dark Godot frame (placeholder until a sub-card frame is supplied).
## Same contract as the other entity cards: home_position, home_rotation, card_size,
## interaction_priority, set_home(), refresh(entity). Presentation only.

const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const ShardBurst = preload("res://scripts/presentation/CardStageShardBurst.gd")
const SpatialSeams = preload("res://scripts/presentation/CardStageSpatialSeams.gd")
const SpatialBurst = preload("res://scripts/presentation/CardStageSpatialBurst.gd")
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
var _art_rect: TextureRect = null
var _standby: bool = false
var _standby_label: Label = null
var badge_label: Label
var _crack_layer: Control
var _flash: ColorRect
var _tween: Tween
var _relocate_tween: Tween
var _intercept_return_position: Vector3 = Vector3.ZERO
var _intercept_return_rotation: Vector3 = Vector3.ZERO
var _intercept_return_scale: Vector3 = Vector3.ONE
var _crack_paths: Array = []
var _shard_burst: Node3D = null
var _intercept_rim: Node3D = null
var _substitute_intercepted: bool = false
var _break_playing: bool = false
var _break_complete: bool = false
signal break_finished
## User-authored timing in 新替身卡擋刀.mp4; preserve its untrimmed audio clock.
const SUBSTITUTE_FLIGHT_AUDIO_CUE: float = 0.18
const SUBSTITUTE_CUT_AUDIO_CUE: float = 0.27
const SUBSTITUTE_SHATTER_AUDIO_CUE: float = 1.0
var _intercept_audio_started_usec: int = 0
var _intercept_flying: bool = false
signal intercept_arrived


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
		_art_rect = art
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
	back_mesh.size = Vector3(card_size.x * 0.97, card_size.y * 0.97, 0.02)
	var back_material := StandardMaterial3D.new()
	back_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	back_material.albedo_color = Color("2a1f14")
	back_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	card_back = MeshInstance3D.new()
	card_back.mesh = back_mesh
	card_back.position.z = -0.02
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
		if charges == null and int(entity.get("duration_turns")) >= 0 and bool(entity.get("joins_turn_order")):
			charges = int(entity.get("duration_turns"))   # a 臨符 card shows the activations it has left
		badge_label.text = "%s%d" % [prefix, int(charges)] if charges != null else ""


func set_home(position_value: Vector3, yaw_degrees: float = 0.0) -> void:
	home_position = position_value
	home_rotation = Vector3(0.0, deg_to_rad(yaw_degrees), 0.0)
	position = home_position
	rotation = home_rotation


var _awaiting_insert: bool = false
var _staged_target: Vector3 = Vector3.ZERO


## True through the whole entrance: the white spin, the walk to the row's outer end, and the
## wait there for the row to make room.
func is_spawning() -> bool:
	return _awaiting_insert or (_tween != null and _tween.is_valid() and _tween.is_running() and scale.x < 0.999)


## True once the entrance has reached the outer end and waits to be inserted.
func is_staged() -> bool:
	return _awaiting_insert and not (_tween != null and _tween.is_valid() and _tween.is_running())


## The card appears at the burst glowing white and spinning; the white drains away and it
## returns to its own look, then it walks to `staging` (the outer end of its row) and waits.
func play_spawn(origin: Vector3, staging: Vector3 = Vector3.ZERO) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_staged_target = staging if staging != Vector3.ZERO else home_position
	position = origin
	scale = Vector3.ONE * 0.04
	set_fade(1.0)
	_flash.color = Color(1.0, 1.0, 1.0, 1.0)
	_awaiting_insert = true
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_method(set_fade, 1.0, 0.0, 0.2)
	_tween.parallel().tween_property(self, "rotation:y", home_rotation.y + TAU * 2.0, 1.3).from(home_rotation.y).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_flash, "color:a", 0.0, 1.2).set_delay(0.15)
	_tween.tween_property(self, "rotation:y", home_rotation.y + TAU * 2.0, 0.0)
	_tween.tween_interval(0.1)
	_tween.tween_property(self, "position", _staged_target, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func() -> void:
		rotation = home_rotation
	)


## Slides from the outer end into the card's slot (slowly: the row is making room).
func insert_into_slot(seconds: float) -> void:
	if not _awaiting_insert:
		return
	_awaiting_insert = false
	if _relocate_tween and _relocate_tween.is_valid():
		_relocate_tween.kill()
	_relocate_tween = create_tween()
	_relocate_tween.tween_property(self, "position", home_position, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_relocate_tween.parallel().tween_property(self, "rotation", home_rotation, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
func is_relocating() -> bool:
	return _relocate_tween != null and _relocate_tween.is_valid() and _relocate_tween.is_running()


func relocate(new_home: Vector3, wrap: bool = false, time_scale: float = 1.0) -> void:
	if _relocate_tween and _relocate_tween.is_valid():
		_relocate_tween.kill()
	home_position = new_home
	if _fan_tween and _fan_tween.is_valid():
		_fan_tween.kill()
	fan_offset = Vector3.ZERO
	# Exactly the way a character card moves: an ordinary slide, or - for the card that has just acted - the walk
	# back along the row passing behind the others.
	var start: Vector3 = position
	_relocate_tween = create_tween()
	if wrap:
		var path := func(t: float) -> void:
			var eased: float = t * t * (3.0 - 2.0 * t)
			var along: Vector3 = start.lerp(new_home, eased)
			along.z += -0.9 * sin(t * PI)
			position = along
		_relocate_tween.tween_method(path, 0.0, 1.0, 0.7 * time_scale)
	else:
		_relocate_tween.tween_property(self, "position", new_home, 0.5 * time_scale).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func set_fade(amount: float) -> void:
	for mesh: GeometryInstance3D in [card_mesh, card_back]:
		if mesh:
			mesh.transparency = amount


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


## A support card is briefly drawn out of its ADB slot. Only its visual transform moves;
## home_position, owner, adjacency and turn order remain untouched.
func fly_to_intercept(attacker_position: Vector3, protected_position: Vector3, motion_style: String = "sacrifice", visual_destination: Variant = null) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_intercept_return_position = position
	_intercept_return_rotation = rotation
	_intercept_return_scale = scale
	var interception: Vector3 = attacker_position.lerp(protected_position, 0.56 if motion_style == "sacrifice" else 0.72)
	interception.z = maxf(attacker_position.z, protected_position.z) + 0.65
	if visual_destination is Vector3:
		interception = visual_destination
	var start: Vector3 = position
	var tilt: float = -0.20 if motion_style == "parry" else 0.12
	var flight_seconds: float = 0.27 if motion_style == "sacrifice" else 0.30
	var substitute: bool = entity != null and String(entity.get("entity_type")) == "substitute_talisman"
	if substitute:
		_intercept_flying = true
		preload("res://scripts/presentation/CardStageSound.gd").play(self, "SE_substitute_intercept", 10.0)
		_intercept_audio_started_usec = Time.get_ticks_usec()
		await _wait_for_intercept_audio_cue(SUBSTITUTE_FLIGHT_AUDIO_CUE)
		flight_seconds = SUBSTITUTE_CUT_AUDIO_CUE - SUBSTITUTE_FLIGHT_AUDIO_CUE
	_tween = create_tween().set_parallel(true)
	if substitute:
		_tween.set_ignore_time_scale(true)
		_set_intercept_rim(0.0)
		_tween.tween_method(_set_intercept_rim, 0.0, 1.0, flight_seconds)
	# One accelerating flight avoids the old two-tween velocity reset. The short arc
	# draws the card out of its slot; the collision animation supplies the hard stop.
	_tween.tween_method(func(progress: float) -> void:
		position = start.lerp(interception, progress) + Vector3(0.0, 0.28, 0.52) * sin(progress * PI)
	, 0.0, 1.0, flight_seconds).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "scale", _intercept_return_scale * 1.14, flight_seconds).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "rotation:z", _intercept_return_rotation.z + tilt, flight_seconds).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	await _tween.finished
	_intercept_flying = false
	intercept_arrived.emit()


func wait_for_intercept_arrival() -> void:
	if _intercept_flying:
		await intercept_arrived


## The attack stops here, not on the character behind this card. Returns the actual
## animation tween so the stage can hold its presentation barrier through collision.
func intercept_impact(motion_style: String = "sacrifice") -> Tween:
	if _tween and _tween.is_valid():
		_tween.kill()
	if entity != null and String(entity.get("entity_type")) == "substitute_talisman":
		_substitute_intercepted = true
		if _intercept_audio_started_usec == 0:
			preload("res://scripts/presentation/CardStageSound.gd").play(self, "SE_substitute_intercept", 10.0)
			_intercept_audio_started_usec = Time.get_ticks_usec()
		_set_intercept_rim(1.5)
		# The reference braces against the blow before its diagonal cut opens.
		var brace: Vector3 = position
		_flash.color = Color(1.0, 0.91, 0.60, 0.65)
		_tween = create_tween().set_ignore_time_scale(true)
		_tween.tween_property(self, "position", brace + Vector3(0.10 if is_enemy else -0.10, 0.0, -0.05), 0.06)
		_tween.tween_property(self, "position", brace, 0.03).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(_flash, "color:a", 0.0, 0.09)
		play_break()
		return _tween
	var centre: Vector3 = position
	_flash.color = Color(0.85, 0.94, 1.0, 0.95) if motion_style == "parry" else Color(1.0, 0.95, 0.8, 0.85)
	_tween = create_tween()
	_tween.tween_property(self, "position", centre + Vector3(0.11, 0.0, 0.0), 0.045)
	_tween.tween_property(self, "position", centre + Vector3(-0.08, 0.0, 0.0), 0.045)
	_tween.tween_property(self, "position", centre, 0.06)
	_tween.parallel().tween_property(_flash, "color:a", 0.0, 0.16)
	if motion_style == "parry":
		_tween.parallel().tween_property(self, "rotation:z", _intercept_return_rotation.z - 0.28, 0.16)
	return _tween


## Gold frame belongs to the intercepting card and remains depth-tested against the row.
func _set_intercept_rim(strength: float) -> void:
	if _intercept_rim == null:
		_intercept_rim = Node3D.new()
		add_child(_intercept_rim)
		for layer: int in range(2):
			var width: float = card_size.x * (0.055 if layer == 0 else 0.012)
			for edge: int in range(4):
				var horizontal: bool = edge < 2
				var sign_value: float = -1.0 if edge % 2 == 0 else 1.0
				var quad := QuadMesh.new()
				quad.size = Vector2(card_size.x, width) if horizontal else Vector2(width, card_size.y)
				var material := StandardMaterial3D.new()
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				material.albedo_color = Color(1.0, 0.82, 0.32, 0.0)
				material.emission_enabled = true
				material.emission = Color(1.0, 0.65, 0.12)
				var mesh := MeshInstance3D.new()
				mesh.mesh = quad
				mesh.material_override = material
				mesh.position = Vector3(0.0, sign_value * card_size.y * 0.49, 0.045) if horizontal else Vector3(sign_value * card_size.x * 0.49, 0.0, 0.045)
				mesh.set_meta("rim_alpha", 0.22 if layer == 0 else 0.95)
				_intercept_rim.add_child(mesh)
	for mesh: MeshInstance3D in _intercept_rim.get_children():
		var material: StandardMaterial3D = mesh.material_override
		material.albedo_color.a = clampf(float(mesh.get_meta("rim_alpha")) * strength, 0.0, 1.0)
		material.emission_energy_multiplier = strength * 1.4


## A sheath card parries and returns; a substitute never calls this because it breaks instead.
func return_from_intercept() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "position", _intercept_return_position, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "rotation", _intercept_return_rotation, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", _intercept_return_scale, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _tween.finished


## A sequence of crossing spatial slashes opens on the substitute, then the sliced face shears apart.
## The intact face disappears at the cut; the action ends only after the fragments settle and fade.
func _wait_for_intercept_audio_cue(seconds: float) -> void:
	# Audio runs in real time even during the collision slow motion.
	while is_inside_tree() and _intercept_audio_started_usec > 0 \
			and float(Time.get_ticks_usec() - _intercept_audio_started_usec) / 1000000.0 < seconds:
		await get_tree().process_frame


func play_break() -> void:
	# Story cleanup later consumes the logical charge; it must not replay this sequence.
	if _break_complete:
		return
	if _break_playing:
		await break_finished
		return
	_break_playing = true
	if _substitute_intercepted:
		await _wait_for_intercept_audio_cue(SUBSTITUTE_CUT_AUDIO_CUE)
	var seams := SpatialSeams.new()
	add_child(seams)
	seams.position = Vector3(0.0, card_mesh.position.y, 0.08)
	seams.setup(card_size)
	var light := create_tween().set_parallel(true)
	var cut_seconds: float = 0.45
	if _substitute_intercepted:
		light.set_ignore_time_scale(true)
		cut_seconds = maxf(0.001, SUBSTITUTE_SHATTER_AUDIO_CUE - float(Time.get_ticks_usec() - _intercept_audio_started_usec) / 1000000.0)
	light.tween_property(seams, "progress", 1.0, cut_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	light.tween_property(seams, "glow", 1.0, cut_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await light.finished
	if _substitute_intercepted:
		await _wait_for_intercept_audio_cue(SUBSTITUTE_SHATTER_AUDIO_CUE)
	else:
		await get_tree().create_timer(0.35).timeout
		var flash := create_tween()
		flash.tween_property(seams, "glow", 1.5, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		await flash.finished
	_shatter_spatial()
	# Remove the intact mesh itself. Geometry transparency alone can still leave the
	# viewport texture visible in this card's 3D material during the shatter.
	card_mesh.hide()
	card_back.hide()
	if _intercept_rim != null:
		_intercept_rim.hide()
	var dim := create_tween()
	dim.tween_property(seams, "glow", 0.0, 0.28)
	dim.tween_callback(seams.queue_free)
	await _shard_burst.tree_exited
	_break_complete = true
	_break_playing = false
	break_finished.emit()


## The shell separates along the spatial slashes, rather than forming a seven-piece tangram.
func _shatter_spatial() -> void:
	_shard_burst = SpatialBurst.new()
	get_parent().add_child(_shard_burst)
	_shard_burst.set("rest_seconds", 0.4)
	_shard_burst.set("fade_seconds", 0.6)
	var paper_and_ink: Array[Color] = [
		Color(0.90, 0.80, 0.66, 0.94),
		Color(0.69, 0.57, 0.46, 0.92),
		Color(0.055, 0.045, 0.045, 0.96),
		Color(0.14, 0.11, 0.10, 0.94),
	]
	var floor_y: float = to_global(Vector3(0.0, -card_size.y * 0.5 + 0.02, 0.0)).y
	_shard_burst.setup_spatial(self, card_size, floor_y, paper_and_ink)


## The older radial star of triangles (kept for reference / other uses).
func _shatter_triangles() -> void:
	_shard_burst = ShardBurst.new()
	get_parent().add_child(_shard_burst)
	_shard_burst.set("rest_seconds", 0.4)
	_shard_burst.set("fade_seconds", 0.6)
	var paper_and_ink: Array[Color] = [
		Color(0.90, 0.80, 0.66, 0.94),
		Color(0.69, 0.57, 0.46, 0.92),
		Color(0.055, 0.045, 0.045, 0.96),
		Color(0.14, 0.11, 0.10, 0.94),
	]
	var floor_y: float = to_global(Vector3(0.0, -card_size.y * 0.5 + 0.02, 0.0)).y
	_shard_burst.setup(self, card_size, Vector2(0.0, card_size.y * 0.04), floor_y, paper_and_ink)


func _draw_cracks() -> void:
	for child: Node in _crack_layer.get_children():
		child.queue_free()
	_crack_paths.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(entity.get("entity_id")))
	for branch: int in range(4):
		var line := Line2D.new()
		line.width = 3.0
		line.default_color = Color(0.03, 0.02, 0.02, 0.95)
		var point := Vector2(rng.randf_range(70.0, 230.0), rng.randf_range(80.0, 130.0))
		var path: PackedVector2Array = PackedVector2Array([point])
		for step: int in range(7):
			point += Vector2(rng.randf_range(-34.0, 34.0), rng.randf_range(26.0, 52.0))
			path.append(point)
		_crack_paths.append(path)
		_crack_layer.add_child(line)
	_set_crack_progress(0.0)


func _set_crack_progress(progress: float) -> void:
	for branch: int in range(_crack_paths.size()):
		var line: Line2D = _crack_layer.get_child(branch)
		var path: PackedVector2Array = _crack_paths[branch]
		var phase: float = clampf(progress * 1.25 - float(branch) * 0.08, 0.0, 1.0)
		var distance: float = phase * float(path.size() - 1)
		var last_full: int = floori(distance)
		line.clear_points()
		for index: int in range(last_full + 1):
			line.add_point(path[index])
		if last_full < path.size() - 1:
			line.add_point(path[last_full].lerp(path[last_full + 1], distance - float(last_full)))


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


## The card's own turn in the order: a short warm-jade flash and a small swell.
func pulse(tint: Color = Color(0.7, 1.0, 0.85, 0.5)) -> void:
	if _flash == null:
		return
	_flash.color = tint
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_flash, "color:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector3.ONE * 1.08, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(self, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_SINE)


# --- 持鞘: drawn from behind the wielder, put back behind him, flying in to block -----------------

## 拔鞘: the card starts hidden behind the wielder's card and is drawn out along ONE straight line toward
## the upper left (off the screen is fine): first a quick pull that shows just the edge (the scabbard has
## just been drawn), a short beat, then the rest of the card comes out at an ordinary steady speed.
## It then waits at the end of the line to be put in its place (insert_into_slot), like play_spawn.
func play_draw(wielder: Node3D, _staging: Vector3 = Vector3.ZERO) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	var behind: Vector3 = wielder.position + Vector3(0.0, 0.0, -0.12)
	var direction: Vector3 = _draw_direction(wielder)
	var crack: Vector3 = behind + direction * 0.2
	var clear: Vector3 = behind + direction * 1.0 + Vector3(0.0, 0.0, 0.25)
	_staged_target = clear
	position = behind
	scale = Vector3.ONE
	rotation = Vector3(0.0, wielder.rotation.y, DRAW_TILT)
	set_fade(0.0)
	_awaiting_insert = true
	_tween = create_tween()
	_tween.tween_property(self, "position", crack, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(0.2)
	_tween.tween_property(self, "position", clear, 0.8).set_trans(Tween.TRANS_LINEAR)
	# Fully out: it spins once around in the plane of the card (a twirl of the scabbard), then waits to
	# be put into the row.
	_tween.tween_interval(0.08)
	_tween.tween_callback(func() -> void:
		preload("res://scripts/presentation/CardStageSound.gd").play(self, "SE_sheath_spin_insert"))
	_tween.tween_property(self, "rotation:z", TAU, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func() -> void:
		rotation.z = 0.0)


## 收鞘: the card goes out to the end of the same line beside the wielder, then is slid back in behind
## him along it at a slow steady pace, like a blade into its scabbard. Ends hidden behind him.
func play_stow(wielder: Node3D) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	if _relocate_tween and _relocate_tween.is_valid():
		_relocate_tween.kill()
	var behind: Vector3 = wielder.position + Vector3(0.0, 0.0, -0.12)
	var direction: Vector3 = _draw_direction(wielder)
	var clear: Vector3 = behind + direction * 1.0 + Vector3(0.0, 0.0, 0.25)
	_tween = create_tween()
	_tween.tween_property(self, "position", clear, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.parallel().tween_property(self, "rotation", Vector3(0.0, wielder.rotation.y, DRAW_TILT), 0.4)
	_tween.tween_interval(0.12)
	_tween.tween_property(self, "position", behind + direction * 0.2, 0.85).set_trans(Tween.TRANS_LINEAR)
	_tween.tween_property(self, "position", behind, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _tween.finished


## The card stays upright while it is drawn (it only travels along the slanted line).
const DRAW_TILT := 0.0


var _blocking: bool = false


## A blow is coming at the wielder: the card flies in front of him, takes it, and goes back to its place.
func fly_to_block(wielder: Node3D) -> void:
	# One blow already has the card in the air (an area attack on two neighbours): it only flashes again.
	if _blocking:
		pulse(Color(1.0, 0.96, 0.85, 0.45))
		return
	_blocking = true
	if _tween and _tween.is_valid():
		_tween.kill()
	var home: Vector3 = home_position
	var in_front: Vector3 = wielder.position + Vector3(_toward_opponent(wielder) * wielder.card_size.x * 0.42, wielder.card_size.y * 0.02, 0.85)
	_tween = create_tween()
	_tween.tween_property(self, "position", in_front, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_tween.tween_callback(pulse.bind(Color(1.0, 0.96, 0.85, 0.45)))
	_tween.tween_interval(0.3)
	_tween.tween_property(self, "position", home, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "rotation:z", 0.0, 0.35)
	_tween.tween_callback(func() -> void:
		_blocking = false)


## The way out of the wielder's card: up and toward the left of the screen.
func _draw_direction(wielder: Node3D) -> Vector3:
	return Vector3(-1.0, 1.0, 0.0).normalized() * wielder.card_size.y * 1.1


func _toward_opponent(wielder: Node3D) -> float:
	return -1.0 if wielder.is_enemy else 1.0


## This round's turn is over: the art is darker and a small red "行動結束" follows the name. Purely visual.
func set_standby(on: bool) -> void:
	if on == _standby:
		return
	_standby = on
	if _art_rect != null:
		_art_rect.modulate = Color(0.5, 0.5, 0.54) if on else Color.WHITE
	if on and _standby_label == null and name_label != null:
		_standby_label = Label.new()
		_style_label(_standby_label, 20, Color(0.95, 0.24, 0.2))
		_standby_label.text = "行動結束"
		name_label.get_parent().add_child(_standby_label)
	if _standby_label == null:
		return
	_standby_label.visible = on
	if on:
		var font: Font = name_label.get_theme_font("font")
		var name_width: float = font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_label.get_theme_font_size("font_size")).x
		var own_width: float = font.get_string_size("行動結束", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		_standby_label.size = Vector2(own_width + 4.0, name_label.size.y)
		var centre: float = name_label.position.x + name_label.size.x * 0.5
		_standby_label.position = Vector2(minf(centre + name_width * 0.5 + 8.0, CANVAS.x - own_width - 8.0), name_label.position.y + 4.0)


## The countdown of a card that counts its own turns: the number on the seal swells, ticks from `from_value` to
## `to_value` with a red "-1" rising from it, and settles. Waits until it has finished.
func play_countdown(from_value: int, to_value: int) -> void:
	pulse(Color(0.7, 1.0, 0.85, 0.45))
	if badge_label == null:
		await get_tree().create_timer(1.0).timeout
		return
	var prefix: String = String((entity.get("card_config") as Dictionary).get("badge_prefix", "×")) if entity != null else "×"
	badge_label.text = "%s%d" % [prefix, from_value]
	badge_label.pivot_offset = badge_label.size * 0.5
	var minus := Label.new()
	_style_label(minus, 56, Color(1.0, 0.25, 0.22))
	minus.text = "-1"
	minus.size = Vector2(108, 58)
	minus.position = badge_label.position + Vector2(0, -6)
	minus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.get_parent().add_child(minus)
	var tween := create_tween()
	tween.tween_property(badge_label, "scale", Vector2.ONE * 1.6, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.2)
	tween.tween_callback(func() -> void: badge_label.text = "%s%d" % [prefix, to_value])
	tween.tween_property(badge_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)
	var rise := create_tween().set_parallel(true)
	rise.tween_property(minus, "position:y", minus.position.y - 70.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rise.tween_property(minus, "modulate:a", 0.0, 0.9).set_delay(0.3)
	await tween.finished
	await get_tree().create_timer(0.35).timeout
	minus.queue_free()


# --- Hover: lift forward / step aside (same contract as the character cards) -------------------------

var fan_offset: Vector3 = Vector3.ZERO
var _fan_tween: Tween


func fan_to(offset: Vector3, duration: float = 0.2, lifted: bool = false) -> void:
	if _tween and _tween.is_valid() and _tween.is_running():
		return   # a flight / entrance owns the card
	if is_relocating() or is_spawning():
		return
	if _fan_tween and _fan_tween.is_valid():
		_fan_tween.kill()
	fan_offset = offset
	if position.is_equal_approx(home_position + offset):
		_fan_tween = null
		return
	_fan_tween = create_tween()
	_fan_tween.tween_property(self, "position", home_position + offset, duration).set_trans(Tween.TRANS_BACK if lifted else Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
