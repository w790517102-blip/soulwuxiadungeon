extends Node3D
## The card is the actor's body on the stage. It only reads battle dictionaries;
## resource values and combat outcomes remain owned by BattleController.

const InnerForceDBScript = preload("res://scripts/battlescripts/InnerForceDB.gd")
const BODY_FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const TITLE_FONT = BODY_FONT
const CANVAS_SIZE := Vector2i(640, 300)
const VIEWPORT_SIZE := Vector2i(1280, 600)
const CARD_SIZE := Vector2(5.4, 2.53125)
const GOLD := Color("c9a565")
const PAPER := Color("eee4ca")

enum PresentationState { EMPTY, PARTY, ENEMY, GUEST }

var actor_id := ""
var presentation_state := PresentationState.EMPTY
var is_enemy := false
var home_position := Vector3.ZERO
var home_rotation := Vector3.ZERO

# Public presentation nodes also make the prototype inspectable in the editor.
var card_viewport: SubViewport
var card_mesh: MeshInstance3D
var card_back: MeshInstance3D
var portrait: TextureRect
var name_label: Label
var level_label: Label
var hp_label: Label
var hp_bar: ProgressBar
var mp_label: Label
var mp_bar: ProgressBar
var element_label: Label
var force_label: Label
var species_label: Label
var status_label: RichTextLabel
var guest_label: Label

var _content: Control
var _element_badge: Panel
var _force_strip: Panel
var _hit_overlay: ColorRect
var _motion_tween: Tween
var _flash_tween: Tween
var _portrait_path := ""
var _target_frame: Panel


func _ready() -> void:
	_build_card()


func configure(actor: Dictionary, enemy: bool, status_bbcode: String = "") -> void:
	_build_card()
	is_enemy = enemy
	refresh(actor, status_bbcode)


func refresh(actor: Dictionary, status_bbcode: String = "") -> void:
	_build_card()
	actor_id = String(actor.get("id", actor.get("name", "")))
	if actor.is_empty():
		presentation_state = PresentationState.EMPTY
		_content.hide()
		portrait.texture = null
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
	name_label.text = String(actor.get("display_name", actor.get("name", "未知")))
	_update_portrait(String(actor.get("portrait_path", "")))
	var force := _active_force(actor)
	var element := String(actor.get("element", "")) if is_enemy else String(force.get("element", actor.get("element", "")))
	if element.is_empty():
		element = "無"
	element_label.text = ("屬性：%s" % element) if is_enemy else element
	element_label.add_theme_color_override("font_color", _element_color(element))
	_element_badge.visible = not is_enemy
	_force_strip.visible = not is_enemy and not guest
	force_label.visible = not is_enemy and not guest
	var force_name := String(force.get("name", ""))
	if force_name.is_empty():
		force_name = String(force.get("prefix", "")) + String(force.get("type", ""))
	if force_name.is_empty():
		force_name = "未運行"
	var vertical_name := ""
	for character in force_name:
		vertical_name += String(character) + "\n"
	force_label.text = vertical_name.strip_edges()
	force_label.add_theme_font_size_override("font_size", 26 if force_name.length() <= 7 else 22)
	level_label.text = "LV %d" % int(actor.get("level", 1))
	level_label.visible = not is_enemy and not guest
	status_label.text = status_bbcode
	status_label.position = Vector2(218, 248) if is_enemy else Vector2(332, 66)
	status_label.size = Vector2(380, 42) if is_enemy else Vector2(245, 42)
	guest_label.visible = guest
	guest_label.text = "支援・客座" if guest else ""
	species_label.visible = is_enemy
	species_label.text = "種族：%s" % _species_name(actor) if is_enemy else ""
	element_label.position = Vector2(218, 171) if is_enemy else Vector2(152, 238)
	element_label.size = Vector2(360, 42) if is_enemy else Vector2(40, 44)
	element_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if is_enemy else HORIZONTAL_ALIGNMENT_CENTER
	element_label.add_theme_font_size_override("font_size", 34)
	hp_label.visible = not guest
	hp_bar.visible = not guest
	mp_label.visible = not is_enemy and not guest
	mp_bar.visible = not is_enemy and not guest
	var hp := int(actor.get("hp", 0))
	var max_hp := maxi(1, int(actor.get("max_hp", hp)))
	var mp := int(actor.get("mp", 0))
	var max_mp := maxi(0, int(actor.get("max_mp", mp)))
	hp_label.text = "氣血：%d/%d" % [clampi(hp, 0, max_hp), max_hp]
	hp_bar.max_value = max_hp
	hp_bar.value = clampi(hp, 0, max_hp)
	mp_label.text = "內力：%d/%d" % [mp, max_mp]
	mp_bar.max_value = maxi(1, max_mp)
	mp_bar.value = clampi(mp, 0, max_mp)
	name_label.add_theme_color_override("font_color", Color("9b9690") if hp <= 0 and not guest else PAPER)


func set_home(pos: Vector3, yaw_degrees: float) -> void:
	home_position = pos
	home_rotation = Vector3(0, deg_to_rad(yaw_degrees), 0)
	reset_pose()


func attack_motion(target_position: Vector3) -> void:
	_kill_motion()
	var direction := (target_position - home_position).normalized()
	var side := -1.0 if is_enemy else 1.0
	var strike_position := home_position.lerp(target_position, 0.34) + Vector3(0, 0.08, -0.32)
	_motion_tween = create_tween()
	_motion_tween.tween_property(self, "position", home_position - direction * 0.18, 0.08)
	_motion_tween.parallel().tween_property(self, "rotation", home_rotation + Vector3(-0.04, 0, side * 0.025), 0.08)
	_motion_tween.tween_property(self, "position", strike_position, 0.19).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion_tween.parallel().tween_property(self, "rotation", home_rotation + Vector3(0.09, side * 0.08, -side * 0.065), 0.19)
	_motion_tween.tween_interval(0.06)
	_motion_tween.tween_property(self, "position", home_position, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.parallel().tween_property(self, "rotation", home_rotation, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _wait_for_motion(_motion_tween)


func hit_reaction(heavy: bool = false) -> void:
	_kill_motion()
	_flash(Color(0.8, 0.08, 0.035, 0.52))
	var away := 1.0 if is_enemy else -1.0
	var strength := 1.4 if heavy else 1.0
	var stagger := home_position + Vector3(away * 0.22, -0.05, -0.20) * strength
	var tilt := home_rotation + Vector3(-0.11, away * 0.035, -away * 0.085) * strength
	_motion_tween = create_tween()
	_motion_tween.tween_property(self, "position", stagger, 0.055)
	_motion_tween.parallel().tween_property(self, "rotation", tilt, 0.055)
	# A local impact hold, not Engine.time_scale: other targets keep animating.
	_motion_tween.tween_interval(0.075 if heavy else 0.045)
	_motion_tween.tween_property(self, "position", stagger + Vector3(away * 0.055, 0.022, 0), 0.035)
	_motion_tween.tween_property(self, "position", stagger - Vector3(away * 0.04, 0.01, 0), 0.04)
	_motion_tween.tween_property(self, "position", home_position, 0.42 if heavy else 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.parallel().tween_property(self, "rotation", home_rotation, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _wait_for_motion(_motion_tween)


func dodge_motion() -> void:
	_kill_motion()
	var side := 1.0 if is_enemy else -1.0
	_motion_tween = create_tween()
	_motion_tween.tween_property(self, "position", home_position + Vector3(side * 0.28, 0.30, -0.72), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion_tween.parallel().tween_property(self, "rotation", home_rotation + Vector3(-0.14, side * 0.08, side * 0.13), 0.14)
	_motion_tween.tween_interval(0.15)
	_motion_tween.tween_property(self, "position", home_position, 0.33).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion_tween.parallel().tween_property(self, "rotation", home_rotation, 0.33)
	await _wait_for_motion(_motion_tween)


func guard_motion() -> void:
	_kill_motion()
	_flash(Color(0.6, 0.76, 1.0, 0.36))
	_motion_tween = create_tween()
	_motion_tween.tween_property(self, "position", home_position + Vector3(0, 0, -0.12), 0.08)
	_motion_tween.parallel().tween_property(self, "rotation", home_rotation + Vector3(-0.075, 0, 0), 0.08)
	_motion_tween.tween_interval(0.10)
	_motion_tween.tween_property(self, "position", home_position, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.parallel().tween_property(self, "rotation", home_rotation, 0.22)
	await _wait_for_motion(_motion_tween)


func reset_pose() -> void:
	_kill_motion()
	position = home_position
	rotation = home_rotation
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = null
	if _hit_overlay:
		_hit_overlay.color = Color.TRANSPARENT


func _kill_motion() -> void:
	if _motion_tween and _motion_tween.is_valid():
		_motion_tween.kill()
	_motion_tween = null


func _wait_for_motion(tween: Tween) -> void:
	# Tween.finished is not emitted when a later hit cancels this card's tween.
	# Observe cancellation so an awaiting presentation callback cannot get stuck.
	while is_inside_tree() and tween and tween.is_valid() and tween.is_running():
		await get_tree().process_frame


func _flash(color: Color) -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_hit_overlay.color = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_hit_overlay, "color", Color.TRANSPARENT, 0.25)


func _active_force(actor: Dictionary) -> Dictionary:
	var force: Variant = actor.get("inner_force", {})
	if force is Dictionary and not force.is_empty():
		return force
	var force_id := String(actor.get("inner_force_id", ""))
	return InnerForceDBScript.INNER_FORCES.get(force_id, {})


func _species_name(actor: Dictionary) -> String:
	var archetype := String(actor.get("archetype", ""))
	if not archetype.is_empty():
		return archetype
	var species := String(actor.get("species", actor.get("family", "未知")))
	var names := {"reptile": "爬蟲", "animal": "野獸", "human": "人族", "spirit": "語魅", "monster": "妖物"}
	return String(names.get(species, species))


func _element_color(element: String) -> Color:
	match element:
		"快": return Color("76cdf2")
		"剛": return Color("ffc578")
		"柔": return Color("efa0c9")
		"遲": return Color("bfacf2")
		_: return PAPER


func _update_portrait(path: String) -> void:
	if path == _portrait_path:
		return
	_portrait_path = path
	portrait.texture = null
	if not path.is_empty() and ResourceLoader.exists(path):
		var texture: Resource = load(path)
		if texture is Texture2D:
			portrait.texture = texture


func _build_card() -> void:
	if card_viewport:
		return
	card_viewport = SubViewport.new()
	card_viewport.name = "CardViewport"
	card_viewport.size = VIEWPORT_SIZE
	card_viewport.size_2d_override = CANVAS_SIZE
	card_viewport.size_2d_override_stretch = true
	card_viewport.transparent_bg = true
	card_viewport.disable_3d = true
	card_viewport.handle_input_locally = false
	card_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(card_viewport)
	var root := Control.new()
	root.name = "CardCanvas"
	root.size = Vector2(CANVAS_SIZE)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_viewport.add_child(root)
	_panel(root, Rect2(10, 10, 620, 280), Color("0b1118"), GOLD, 3)
	_panel(root, Rect2(19, 19, 602, 262), Color("101822"), Color("685432"), 1)
	_content = Control.new()
	_content.name = "ActorContent"
	_content.size = Vector2(CANVAS_SIZE)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_content)
	portrait = TextureRect.new()
	portrait.name = "Portrait"
	portrait.position = Vector2(26, 76)
	portrait.size = Vector2(170, 190)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(portrait)
	name_label = _label("Name", Rect2(28, 14, 574, 50), 40, PAPER)
	name_label.add_theme_font_override("font", TITLE_FONT)
	level_label = _label("Level", Rect2(218, 66, 108, 42), 34, GOLD)
	status_label = RichTextLabel.new()
	status_label.name = "StatusWords"
	status_label.bbcode_enabled = true
	status_label.scroll_active = false
	# Party status words share the LV row; they must not wrap into HP/MP.
	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_label.clip_contents = true
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.add_theme_font_override("normal_font", BODY_FONT)
	status_label.add_theme_font_size_override("normal_font_size", 34)
	status_label.add_theme_color_override("default_color", PAPER)
	_content.add_child(status_label)
	hp_label = _label("HP", Rect2(218, 108, 360, 44), 34, PAPER)
	hp_bar = _bar("HPBar", Rect2(218, 153, 360, 14), Color("bb413b"))
	mp_label = _label("MP", Rect2(218, 182, 360, 44), 34, PAPER)
	mp_bar = _bar("MPBar", Rect2(218, 227, 360, 14), Color("4dacca"))
	_element_badge = _panel(_content, Rect2(146, 237, 50, 45), Color("161921"), GOLD, 2)
	element_label = _label("Element", Rect2(152, 238, 40, 44), 34, GOLD)
	species_label = _label("Species", Rect2(218, 211, 360, 42), 34, PAPER)
	_force_strip = _panel(_content, Rect2(586, 72, 34, 205), Color("11151b"), Color("685432"), 1)
	force_label = _label("ActiveInnerForce", Rect2(588, 76, 30, 196), 26, GOLD)
	force_label.add_theme_font_override("font", TITLE_FONT)
	force_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	force_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	guest_label = _label("Guest", Rect2(218, 148, 360, 60), 36, GOLD)
	_hit_overlay = ColorRect.new()
	_hit_overlay.name = "LocalHitFlash"
	_hit_overlay.position = Vector2(20, 20)
	_hit_overlay.size = Vector2(600, 260)
	_hit_overlay.color = Color.TRANSPARENT
	_hit_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hit_overlay)
	_target_frame = _panel(root, Rect2(6, 6, 628, 288), Color.TRANSPARENT, Color("fff0a0"), 6)
	_target_frame.hide()
	_content.hide()
	var mesh := QuadMesh.new()
	mesh.size = CARD_SIZE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.albedo_texture = card_viewport.get_texture()
	# Intentionally no billboard mode: actual yaw/pitch/roll define the body.
	card_mesh = MeshInstance3D.new()
	card_mesh.name = "CardFace"
	card_mesh.mesh = mesh
	card_mesh.material_override = material
	card_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(card_mesh)
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(CARD_SIZE.x * 0.973, CARD_SIZE.y * 0.949, 0.06)
	var back_material := StandardMaterial3D.new()
	back_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	back_material.albedo_color = Color("675131")
	card_back = MeshInstance3D.new()
	card_back.name = "CardThickness"
	card_back.mesh = back_mesh
	card_back.position.z = -0.04
	card_back.material_override = back_material
	card_back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(card_back)


func _label(node_name: String, rect: Rect2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = rect.position
	label.size = rect.size
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", BODY_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_content.add_child(label)
	return label


func set_target_focus(value: bool) -> void:
	_target_frame.visible = value


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


func _bar(node_name: String, rect: Rect2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = node_name
	bar.position = rect.position
	bar.size = rect.size
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var background := StyleBoxFlat.new()
	background.bg_color = Color("060a10")
	background.border_color = Color("705b3a")
	background.set_border_width_all(1)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", background)
	_content.add_child(bar)
	return bar
