extends "res://scripts/presentation/StageActorCard.gd"
## Card Stage character card: an upright card that IS the actor on the stage, built
## from the supplied card templates (see CardStageTemplates). Same data fields and
## public nodes as the STAGE_25D card, so the UI keeps refreshing status/HP/MP the
## same way. Layers, back to front: card edge, ink-wash window, character art, face
## (frame + information slots + ornaments). Combat values are never written here.

const Templates = preload("res://scripts/presentation/CardStageTemplates.gd")
const CardStageArt = preload("res://scripts/presentation/CardStageArt.gd")

## Edge thickness behind the face (was 0.06; reduced by one third).
const CARD_THICKNESS := 0.04
## Distance between the face (z = 0), the art layer and the ink-wash layer behind it.
const LAYER_GAP := 0.05

const WINDUP_DISTANCE := 0.45
const LUNGE_FRACTION := 0.46
const LUNGE_LIFT := 0.6 # Z toward the camera at contact, so the swing reads in depth.
const KNOCKBACK := Vector3(0.55, -0.12, -0.9)
const KNOCKBACK_HEAVY := Vector3(1.0, -0.2, -1.6)
const DODGE_SLIP := Vector3(0.5, 0.35, -1.25)
const GUARD_BRACE := Vector3(0.12, -0.05, -0.35)

const TURN_PULSE_PEAK := 0.42
const TURN_PULSE_SECONDS := 1.5

## Set BEFORE the card enters the tree (configure() does it): character / enemy / boss.
var template_key: String = "character"
var template: Dictionary = {}
## World size of the card BODY (the frame); used for picking and screen rectangles.
var card_size: Vector2 = Templates.card_world_size("character")
## World size of the whole face image (frame plus ornaments).
var face_size: Vector2 = Vector2.ZERO
var slot_rank: int = 0
var turn_active: bool = false
var ink_back: MeshInstance3D
var art_layer: MeshInstance3D
var art_material: ShaderMaterial
var art_key: String = ""
var window_local: Rect2 = Rect2()
var _turn_overlay: ColorRect
var _turn_tween: Tween


## Picks the template from the actor, then builds the card.
func prepare_for(actor: Dictionary, enemy: bool) -> void:
	if card_viewport == null:
		template_key = Templates.key_for(actor, enemy)
		is_enemy = enemy
		card_size = Templates.card_world_size(template_key)


## Slow white pulse while it is this card's turn. Presentation only.
func set_turn_active(active: bool) -> void:
	_build_card()
	turn_active = active
	if _turn_tween and _turn_tween.is_valid():
		_turn_tween.kill()
	_turn_tween = null
	_turn_overlay.color = Color(1.0, 1.0, 1.0, 0.0)
	if not active:
		return
	_turn_tween = create_tween().set_loops()
	_turn_tween.tween_property(_turn_overlay, "color:a", TURN_PULSE_PEAK, TURN_PULSE_SECONDS / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_turn_tween.tween_property(_turn_overlay, "color:a", 0.0, TURN_PULSE_SECONDS / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# --- Card construction -------------------------------------------------------------

func _build_card() -> void:
	if card_viewport:
		return
	template = Templates.get_template(template_key)
	var canvas: Vector2 = template.canvas
	var world: float = Templates.world_per_pixel(template_key)
	card_size = Templates.card_world_size(template_key)
	face_size = canvas * world
	card_viewport = SubViewport.new()
	card_viewport.name = "CardViewport"
	card_viewport.size = Vector2i((canvas * Templates.FACE_SCALE).round())
	card_viewport.size_2d_override = Vector2i(canvas)
	card_viewport.size_2d_override_stretch = true
	card_viewport.transparent_bg = true
	card_viewport.disable_3d = true
	card_viewport.handle_input_locally = false
	card_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(card_viewport)
	var root := Control.new()
	root.name = "CardCanvas"
	root.size = canvas
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_viewport.add_child(root)
	# The template face (window already cut out) is the bottom of the 2D stack.
	var face := TextureRect.new()
	face.name = "TemplateFace"
	face.texture = load(String(template.face)) as Texture2D
	face.size = canvas
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(face)
	_content = Control.new()
	_content.name = "ActorContent"
	_content.size = canvas
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_content)
	var window: Rect2 = template.window
	# Portrait for actors that have no layered art; sits in the (transparent) window.
	portrait = TextureRect.new()
	portrait.name = "Portrait"
	portrait.position = window.position
	portrait.size = window.size
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(portrait)
	name_label = _label("Name", template.name, int(template.name_font), PAPER)
	name_label.add_theme_font_override("font", TITLE_FONT)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outline(name_label, 8)
	# Bars first so their text can sit on top of them.
	hp_bar = _slot_bar("HPBar", template.hp, Color(0.75, 0.2, 0.18, 0.92))
	mp_bar = _slot_bar("MPBar", template.get("mp", Rect2()), Color(0.2, 0.62, 0.8, 0.92))
	hp_label = _slot_label("HP", template.hp)
	mp_label = _slot_label("MP", template.get("mp", Rect2()))
	element_label = _label("Element", template.get("badge", template.get("element", Rect2())), int(template.get("badge_font", template.get("row_font", 40))), GOLD)
	element_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outline(element_label, 6)
	species_label = _label("Species", template.get("species", Rect2()), int(template.get("row_font", 40)), PAPER)
	species_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outline(species_label, 6)
	force_label = _label("ActiveInnerForce", _inset(template.get("force", Rect2()), 20, 0), int(template.get("force_font", 40)), GOLD)
	force_label.add_theme_font_override("font", TITLE_FONT)
	force_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	guest_label = _label("Guest", _inset(template.get("force", Rect2()), 20, 0), int(template.get("force_font", 40)), GOLD)
	guest_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label = _label("Level", Rect2(0, 0, 1, 1), 10, GOLD)
	level_label.hide() # LV is intentionally not shown on Card Stage cards.
	# Dummies keep the inherited visibility API; the real frames are in the face image.
	_element_badge = _panel(_content, template.get("badge", Rect2()), Color.TRANSPARENT, Color.TRANSPARENT, 0)
	_force_strip = _panel(_content, template.get("force", Rect2()), Color.TRANSPARENT, Color.TRANSPARENT, 0)
	status_label = RichTextLabel.new()
	status_label.name = "StatusWords"
	status_label.bbcode_enabled = true
	status_label.scroll_active = false
	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_label.clip_contents = true
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.add_theme_font_override("normal_font", BODY_FONT)
	status_label.add_theme_font_size_override("normal_font_size", int(template.status_font))
	status_label.add_theme_color_override("default_color", PAPER)
	var status_rect: Rect2 = template.status
	status_label.position = status_rect.position
	status_label.size = status_rect.size
	_content.add_child(status_label)
	var frame: Rect2 = (template.frame as Rect2).grow(-8)
	# Slow white pulse that marks whose turn it is (see set_turn_active).
	_turn_overlay = ColorRect.new()
	_turn_overlay.name = "TurnPulse"
	_turn_overlay.position = frame.position
	_turn_overlay.size = frame.size
	_turn_overlay.color = Color(1.0, 1.0, 1.0, 0.0)
	_turn_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_turn_overlay)
	_hit_overlay = ColorRect.new()
	_hit_overlay.name = "LocalHitFlash"
	_hit_overlay.position = frame.position
	_hit_overlay.size = frame.size
	_hit_overlay.color = Color.TRANSPARENT
	_hit_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hit_overlay)
	_target_frame = _panel(root, (template.frame as Rect2).grow(10), Color.TRANSPARENT, Color("fff0a0"), 10)
	_target_frame.hide()
	_content.hide()
	_build_layers(world)


func _build_layers(world: float) -> void:
	var canvas: Vector2 = template.canvas
	var frame: Rect2 = template.frame
	# Face quad: the whole template image, offset so the FRAME is centred on the node.
	var face_mesh := QuadMesh.new()
	face_mesh.size = face_size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.albedo_texture = card_viewport.get_texture()
	# No billboard: yaw/pitch/roll are the card's body.
	card_mesh = MeshInstance3D.new()
	card_mesh.name = "CardFace"
	card_mesh.mesh = face_mesh
	card_mesh.material_override = material
	card_mesh.position = Vector3((canvas.x / 2.0 - frame.get_center().x) * world, -(canvas.y / 2.0 - frame.get_center().y) * world, 0.0)
	card_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(card_mesh)
	# Ink-wash window painted in the template, behind the art.
	window_local = Templates.to_local_rect(template_key, template.window)
	ink_back = MeshInstance3D.new()
	ink_back.name = "InkWash"
	var ink_mesh := QuadMesh.new()
	ink_mesh.size = window_local.size
	ink_back.mesh = ink_mesh
	var ink_material := StandardMaterial3D.new()
	ink_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ink_material.albedo_texture = load(String(template.ink)) as Texture2D
	ink_back.material_override = ink_material
	ink_back.position = Vector3(window_local.get_center().x, window_local.get_center().y, -2.0 * LAYER_GAP)
	ink_back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ink_back)
	# Character art between the ink and the face, cropped to the window.
	art_layer = MeshInstance3D.new()
	art_layer.name = "CharacterArt"
	art_layer.mesh = QuadMesh.new()
	art_material = ShaderMaterial.new()
	art_material.shader = load("res://scripts/presentation/shaders/card_art.gdshader")
	art_material.set_shader_parameter("clip_rect", Vector4(window_local.position.x, window_local.position.y, window_local.end.x, window_local.end.y))
	art_layer.material_override = art_material
	art_layer.position.z = -LAYER_GAP
	# Transparent layers of ONE card must draw back to front: art behind the face.
	art_layer.sorting_offset = -0.3
	art_layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	art_layer.visible = false
	add_child(art_layer)
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(card_size.x * 0.973, card_size.y * 0.973, CARD_THICKNESS)
	var back_material := StandardMaterial3D.new()
	back_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	back_material.albedo_color = Color("2a1f14")
	card_back = MeshInstance3D.new()
	card_back.name = "CardThickness"
	card_back.mesh = back_mesh
	card_back.position.z = -(2.0 * LAYER_GAP + 0.01 + CARD_THICKNESS / 2.0)
	card_back.material_override = back_material
	card_back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(card_back)


func _inset(rect: Rect2, horizontal: float, vertical: float) -> Rect2:
	return rect.grow_individual(-horizontal, -vertical, -horizontal, -vertical)


func _outline(label: Control, size: int) -> void:
	label.add_theme_constant_override("outline_size", size)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))


## Text that sits inside one of the template's information slots.
func _slot_label(node_name: String, slot: Rect2) -> Label:
	var label: Label = _label(node_name, _inset(slot, 26, 0), int(template.slot_font), PAPER)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outline(label, 8)
	return label


## A bar whose track is the template slot itself; only the fill is drawn here.
func _slot_bar(node_name: String, slot: Rect2, colour: Color) -> ProgressBar:
	var bar: ProgressBar = _bar(node_name, _inset(slot, 14, slot.size.y * 0.2), colour)
	bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


# --- Data binding --------------------------------------------------------------------

func refresh(actor: Dictionary, status_bbcode: String = "") -> void:
	_build_card()
	actor_id = String(actor.get("id", actor.get("name", "")))
	if actor.is_empty():
		presentation_state = PresentationState.EMPTY
		_content.hide()
		portrait.texture = null
		art_layer.visible = false
		art_key = ""
		_portrait_path = ""
		for label: Label in [name_label, level_label, hp_label, mp_label, element_label, force_label, species_label, guest_label]:
			label.text = ""
		status_label.text = ""
		hp_bar.value = 0
		mp_bar.value = 0
		reset_pose()
		return
	_content.show()
	var guest := bool(actor.get("is_guest", false)) or String(actor.get("presentation_state", "")).to_lower() == "guest" or String(actor.get("role", "")) == "guest"
	presentation_state = PresentationState.ENEMY if is_enemy else (PresentationState.GUEST if guest else PresentationState.PARTY)
	var is_character: bool = template_key == "character"
	name_label.text = String(actor.get("display_name", actor.get("name", "未知")))
	_update_portrait(String(actor.get("portrait_path", "")))
	_apply_art(actor)
	var force := _active_force(actor)
	var element := String(actor.get("element", "")) if is_enemy else String(force.get("element", actor.get("element", "")))
	if element.is_empty():
		element = "無"
	# Party shows the element glyph in the badge; enemies print "屬性：X".
	element_label.text = ("屬性：%s" % element) if not is_character else element
	element_label.add_theme_color_override("font_color", _element_color(element))
	# An element of "無" (none) is not shown at all.
	var has_element: bool = element != "無"
	element_label.visible = not guest and has_element
	_element_badge.visible = is_character and not guest and has_element
	_force_strip.visible = is_character and not guest
	force_label.visible = is_character and not guest
	var force_name := String(force.get("name", ""))
	if force_name.is_empty():
		force_name = String(force.get("prefix", "")) + String(force.get("type", ""))
	if force_name.is_empty():
		force_name = "未運行"
	force_label.text = force_name
	force_label.add_theme_font_size_override("font_size", int(template.get("force_font", 40)) if force_name.length() <= 5 else int(template.get("force_font", 40)) - 18)
	level_label.text = "LV %d" % int(actor.get("level", 1))
	level_label.visible = false
	status_label.text = status_bbcode
	guest_label.visible = guest
	guest_label.text = "支援・客座" if guest else ""
	species_label.visible = not is_character
	species_label.text = "種族：%s" % _species_name(actor) if not is_character else ""
	hp_label.visible = not guest
	hp_bar.visible = not guest
	mp_label.visible = is_character and not guest
	mp_bar.visible = is_character and not guest
	var hp := int(actor.get("hp", 0))
	var max_hp := maxi(1, int(actor.get("max_hp", hp)))
	var mp := int(actor.get("mp", 0))
	var max_mp := maxi(0, int(actor.get("max_mp", mp)))
	hp_label.text = "氣血：%d/%d" % [hp, max_hp]
	hp_bar.max_value = max_hp
	hp_bar.value = clampi(hp, 0, max_hp)
	mp_label.text = "內力：%d/%d" % [mp, max_mp]
	mp_bar.max_value = maxi(1, max_mp)
	mp_bar.value = clampi(mp, 0, max_mp)
	name_label.add_theme_color_override("font_color", Color("9b9690") if hp <= 0 and not guest else PAPER)
	# Overlapping cards hide the side facing the neighbour that stands in front:
	# the party's RIGHT edge, the enemy's LEFT edge. Keep the text on the other side.
	var text_side: int = HORIZONTAL_ALIGNMENT_RIGHT if is_enemy else HORIZONTAL_ALIGNMENT_LEFT
	for label: Label in [name_label, hp_label, mp_label, species_label]:
		label.horizontal_alignment = text_side
	element_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if is_character else text_side


# --- Spatial motion --------------------------------------------------------------

func _toward() -> float:
	# +1 means the opponent stands on the +X side.
	return -1.0 if is_enemy else 1.0


func attack_motion(target_position: Vector3) -> void:
	_kill_motion()
	var toward: float = _toward()
	var line: Vector3 = target_position - home_position
	var windup_position: Vector3 = home_position - line.normalized() * WINDUP_DISTANCE + Vector3(0.0, -0.06, -0.25)
	# Travel sideways/up toward the target, but always swing OUT toward the viewer
	# in Z: the opponent is deeper, so following line.z would pull the card back.
	var strike_position: Vector3 = Vector3(home_position.x + line.x * LUNGE_FRACTION, home_position.y + line.y * LUNGE_FRACTION + 0.12, home_position.z + LUNGE_LIFT)
	# Open the card toward the viewer at contact: half of the resting yaw.
	var strike_rotation: Vector3 = Vector3(home_rotation.x + 0.10, home_rotation.y * 0.45, home_rotation.z - toward * 0.12)
	_motion_tween = create_tween()
	_motion_tween.tween_property(self, "position", windup_position, 0.12)
	_motion_tween.parallel().tween_property(self, "rotation", home_rotation + Vector3(-0.07, -toward * 0.10, toward * 0.05), 0.12)
	_motion_tween.tween_property(self, "position", strike_position, 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion_tween.parallel().tween_property(self, "rotation", strike_rotation, 0.17)
	_motion_tween.tween_interval(0.06)
	_motion_tween.tween_property(self, "position", home_position, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.parallel().tween_property(self, "rotation", home_rotation, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _wait_for_motion(_motion_tween)


func hit_reaction(heavy: bool = false) -> void:
	_kill_motion()
	_flash(Color(0.8, 0.08, 0.035, 0.52))
	var away: float = -_toward()
	var push: Vector3 = KNOCKBACK_HEAVY if heavy else KNOCKBACK
	var stagger: Vector3 = home_position + Vector3(away * push.x, push.y, push.z)
	var strength: float = 1.4 if heavy else 1.0
	var tilt: Vector3 = home_rotation + Vector3(-0.20, away * 0.12, -away * 0.16) * strength
	_motion_tween = create_tween()
	_motion_tween.tween_property(self, "position", stagger, 0.06)
	_motion_tween.parallel().tween_property(self, "rotation", tilt, 0.06)
	_motion_tween.tween_interval(0.08 if heavy else 0.05)
	_motion_tween.tween_property(self, "position", stagger + Vector3(away * 0.05, 0.02, -0.05), 0.035)
	_motion_tween.tween_property(self, "position", stagger - Vector3(away * 0.04, 0.01, 0.0), 0.04)
	_motion_tween.tween_property(self, "position", home_position, 0.5 if heavy else 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.parallel().tween_property(self, "rotation", home_rotation, 0.44).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _wait_for_motion(_motion_tween)


func dodge_motion() -> void:
	_kill_motion()
	var away: float = -_toward()
	_motion_tween = create_tween()
	_motion_tween.tween_property(self, "position", home_position + Vector3(away * DODGE_SLIP.x, DODGE_SLIP.y, DODGE_SLIP.z), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion_tween.parallel().tween_property(self, "rotation", home_rotation + Vector3(-0.14, away * 0.22, away * 0.13), 0.14)
	_motion_tween.tween_interval(0.16)
	_motion_tween.tween_property(self, "position", home_position, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion_tween.parallel().tween_property(self, "rotation", home_rotation, 0.34)
	await _wait_for_motion(_motion_tween)


func guard_motion() -> void:
	_kill_motion()
	_flash(Color(0.6, 0.76, 1.0, 0.36))
	var away: float = -_toward()
	_motion_tween = create_tween()
	_motion_tween.tween_property(self, "position", home_position + Vector3(away * GUARD_BRACE.x, GUARD_BRACE.y, GUARD_BRACE.z), 0.08)
	_motion_tween.parallel().tween_property(self, "rotation", home_rotation + Vector3(-0.06, 0.0, 0.0), 0.08)
	_motion_tween.tween_interval(0.12)
	_motion_tween.tween_property(self, "position", home_position, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.parallel().tween_property(self, "rotation", home_rotation, 0.24)
	await _wait_for_motion(_motion_tween)



# --- Character art -------------------------------------------------------------------

func _apply_art(actor: Dictionary) -> void:
	var entry: Dictionary = CardStageArt.entry_for(actor)
	if entry.is_empty() or not ResourceLoader.exists(String(entry.path)):
		art_layer.visible = false
		art_key = ""
		portrait.visible = true
		return
	var key: String = String(entry.path)
	if key != art_key:
		art_key = key
		var texture: Texture2D = load(key) as Texture2D
		art_material.set_shader_parameter("art", texture)
		var quad_size := Vector2(float(entry.get("size", 1.0)), float(entry.get("size", 1.0)))
		var offset := Vector2.ZERO
		if String(entry.get("mode", "fit")) == "cover":
			var layout: Dictionary = CardStageArt.cover_layout(entry, window_local.size, float(texture.get_width()) / float(texture.get_height()))
			quad_size = layout.size
			offset = layout.center
		else:
			offset = CardStageArt.quad_center(entry)
		(art_layer.mesh as QuadMesh).size = quad_size
		# Offsets are measured from the window centre.
		var centre: Vector2 = window_local.get_center() + offset
		art_layer.position = Vector3(centre.x, centre.y, -LAYER_GAP)
		art_material.set_shader_parameter("size", quad_size)
		art_material.set_shader_parameter("center", centre)
	portrait.visible = false
	art_layer.visible = true


# --- Target-selection hover: lift forward / step aside ------------------------------

var fan_offset: Vector3 = Vector3.ZERO
var _fan_tween: Tween


## Slides the card to home + offset (used while a target is being chosen). Ignored
## while an attack / hit / dodge motion owns the card.
func fan_to(offset: Vector3, duration: float = 0.2, lifted: bool = false) -> void:
	if _motion_tween and _motion_tween.is_valid() and _motion_tween.is_running():
		return
	if _fan_tween and _fan_tween.is_valid():
		_fan_tween.kill()
	fan_offset = offset
	if position.is_equal_approx(home_position + offset):
		_fan_tween = null
		return
	_fan_tween = create_tween()
	_fan_tween.tween_property(self, "position", home_position + offset, duration).set_trans(Tween.TRANS_BACK if lifted else Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _kill_motion() -> void:
	# Any motion (and reset_pose) takes over from wherever the fan left the card.
	super._kill_motion()
	if _fan_tween and _fan_tween.is_valid():
		_fan_tween.kill()
	_fan_tween = null


func reset_pose() -> void:
	super.reset_pose()
	fan_offset = Vector3.ZERO


# --- Line-up changes (turn order) -----------------------------------------------------

var _relocate_tween: Tween


func is_relocating() -> bool:
	return _relocate_tween != null and _relocate_tween.is_valid() and _relocate_tween.is_running()


## Fades the whole card (0 = solid, 1 = gone). Presentation only.
func set_fade(amount: float) -> void:
	for mesh: GeometryInstance3D in [card_mesh, ink_back, art_layer, card_back]:
		if mesh:
			mesh.transparency = amount


## Moves the card to a new line-up slot. `wrap` is the card that just acted: it leaves
## toward the exchange zone, vanishes, and reappears at the far end of its row.
## Otherwise the card simply slides. `home_position` changes at once, so picking and
## later motions already use the new slot.
func relocate(new_home: Vector3, wrap: bool) -> void:
	if _relocate_tween and _relocate_tween.is_valid():
		_relocate_tween.kill()
	var start: Vector3 = position
	home_position = new_home
	_relocate_tween = create_tween()
	if wrap:
		var exit_point: Vector3 = start + Vector3(_toward() * 1.3, 0.0, 0.0)
		_relocate_tween.tween_property(self, "position", exit_point, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_relocate_tween.parallel().tween_method(set_fade, 0.0, 1.0, 0.2)
		_relocate_tween.tween_callback(func() -> void:
			position = new_home + Vector3(-_toward() * 1.3, 0.0, 0.0)
		)
		_relocate_tween.tween_property(self, "position", new_home, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_relocate_tween.parallel().tween_method(set_fade, 1.0, 0.0, 0.24)
	else:
		_relocate_tween.tween_property(self, "position", new_home, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func settle_relocation() -> void:
	if _relocate_tween and _relocate_tween.is_valid():
		_relocate_tween.kill()
	_relocate_tween = null
	position = home_position
	set_fade(0.0)


# --- Casting a stage skill (replaces nothing: attacks keep their own motions) ----------------

## One step forward toward the centre and the viewer, then hold while the glyph is drawn.
func cast_step_forward() -> void:
	_kill_motion()
	var step := Vector3(_toward() * 0.9, 0.06, 0.8)
	_motion_tween = create_tween()
	_motion_tween.tween_property(self, "position", home_position + step, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion_tween.parallel().tween_property(self, "rotation", home_rotation + Vector3(-0.03, -_toward() * 0.12, 0.0), 0.28)
	await _wait_for_motion(_motion_tween)


## Back to the slot after the cast.
func cast_return() -> void:
	_kill_motion()
	_motion_tween = create_tween()
	_motion_tween.tween_property(self, "position", home_position, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.parallel().tween_property(self, "rotation", home_rotation, 0.32)
	await _wait_for_motion(_motion_tween)
