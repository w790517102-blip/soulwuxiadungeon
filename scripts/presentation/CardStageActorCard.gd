extends "res://scripts/presentation/StageActorCard.gd"
## Card Stage character card: an upright portrait card that IS the actor on the
## stage. Same data fields and public nodes as the STAGE_25D card (so the UI can
## keep refreshing status/HP/MP the same way); only the face is re-laid out as a
## tall card and the motion is spatial. Combat values are never written here.

const PORTRAIT_CANVAS := Vector2i(400, 600)
const PORTRAIT_VIEWPORT := Vector2i(800, 1200)
## World size (2:3). Kept as data; CardStage3D reads card_size for picking.
const PORTRAIT_SIZE := Vector2(2.3, 3.45)

const WINDUP_DISTANCE := 0.45
const LUNGE_FRACTION := 0.46
const LUNGE_LIFT := 0.9 # Z toward the camera at contact, so the swing reads in depth.
const KNOCKBACK := Vector3(0.55, -0.12, -0.9)
const KNOCKBACK_HEAVY := Vector3(1.0, -0.2, -1.6)
const DODGE_SLIP := Vector3(0.5, 0.35, -1.25)
const GUARD_BRACE := Vector3(0.12, -0.05, -0.35)

var card_size: Vector2 = PORTRAIT_SIZE
var slot_rank: int = 0


# --- Portrait face -------------------------------------------------------------

func _build_card() -> void:
	if card_viewport:
		return
	card_viewport = SubViewport.new()
	card_viewport.name = "CardViewport"
	card_viewport.size = PORTRAIT_VIEWPORT
	card_viewport.size_2d_override = PORTRAIT_CANVAS
	card_viewport.size_2d_override_stretch = true
	card_viewport.transparent_bg = true
	card_viewport.disable_3d = true
	card_viewport.handle_input_locally = false
	card_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(card_viewport)
	var root := Control.new()
	root.name = "CardCanvas"
	root.size = Vector2(PORTRAIT_CANVAS)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_viewport.add_child(root)
	_panel(root, Rect2(8, 8, 384, 584), Color("0b1118"), GOLD, 4)
	_panel(root, Rect2(18, 18, 364, 564), Color("101822"), Color("685432"), 1)
	_content = Control.new()
	_content.name = "ActorContent"
	_content.size = Vector2(PORTRAIT_CANVAS)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_content)
	# Portrait fills the upper card; information sits in a band below it.
	portrait = TextureRect.new()
	portrait.name = "Portrait"
	portrait.position = Vector2(26, 70)
	portrait.size = Vector2(348, 274)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(portrait)
	name_label = _label("Name", Rect2(28, 20, 344, 50), 42, PAPER)
	name_label.add_theme_font_override("font", TITLE_FONT)
	# Information band: LV + status, HP, MP / species, element + inner force.
	level_label = _label("Level", Rect2(28, 346, 124, 44), 34, GOLD)
	status_label = RichTextLabel.new()
	status_label.name = "StatusWords"
	status_label.bbcode_enabled = true
	status_label.scroll_active = false
	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_label.clip_contents = true
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.add_theme_font_override("normal_font", BODY_FONT)
	status_label.add_theme_font_size_override("normal_font_size", 32)
	status_label.add_theme_color_override("default_color", PAPER)
	status_label.position = Vector2(154, 348)
	status_label.size = Vector2(218, 38)
	_content.add_child(status_label)
	hp_label = _label("HP", Rect2(28, 390, 344, 44), 35, PAPER)
	hp_bar = _bar("HPBar", Rect2(28, 440, 344, 14), Color("bb413b"))
	mp_label = _label("MP", Rect2(28, 456, 344, 44), 35, PAPER)
	mp_bar = _bar("MPBar", Rect2(28, 503, 344, 14), Color("4dacca"))
	species_label = _label("Species", Rect2(28, 456, 344, 44), 35, PAPER)
	guest_label = _label("Guest", Rect2(28, 420, 344, 50), 34, GOLD)
	_element_badge = _panel(_content, Rect2(28, 522, 50, 54), Color("161921"), GOLD, 2)
	element_label = _label("Element", Rect2(32, 525, 42, 48), 36, GOLD)
	_force_strip = _panel(_content, Rect2(84, 522, 288, 54), Color("11151b"), Color("685432"), 1)
	force_label = _label("ActiveInnerForce", Rect2(90, 525, 276, 48), 32, GOLD)
	force_label.add_theme_font_override("font", TITLE_FONT)
	force_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hit_overlay = ColorRect.new()
	_hit_overlay.name = "LocalHitFlash"
	_hit_overlay.position = Vector2(18, 18)
	_hit_overlay.size = Vector2(364, 564)
	_hit_overlay.color = Color.TRANSPARENT
	_hit_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hit_overlay)
	_target_frame = _panel(root, Rect2(4, 4, 392, 592), Color.TRANSPARENT, Color("fff0a0"), 6)
	_target_frame.hide()
	_content.hide()
	var mesh := QuadMesh.new()
	mesh.size = card_size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.albedo_texture = card_viewport.get_texture()
	# No billboard: yaw/pitch/roll are the card's body.
	card_mesh = MeshInstance3D.new()
	card_mesh.name = "CardFace"
	card_mesh.mesh = mesh
	card_mesh.material_override = material
	card_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(card_mesh)
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(card_size.x * 0.973, card_size.y * 0.973, 0.06)
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
	# Enemies print "屬性：X" in the wide slot; party shows the element badge.
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
	force_label.text = force_name
	force_label.add_theme_font_size_override("font_size", 32 if force_name.length() <= 5 else 24)
	level_label.text = "LV %d" % int(actor.get("level", 1))
	level_label.visible = not is_enemy and not guest
	status_label.text = status_bbcode
	# Enemies have no LV, so their status words use the whole row.
	status_label.position = Vector2(28, 348) if (is_enemy or guest) else Vector2(154, 348)
	status_label.size = Vector2(344, 38) if (is_enemy or guest) else Vector2(218, 38)
	guest_label.visible = guest
	guest_label.text = "支援・客座" if guest else ""
	species_label.visible = is_enemy
	species_label.text = "種族：%s" % _species_name(actor) if is_enemy else ""
	if is_enemy:
		element_label.position = Vector2(28, 522)
		element_label.size = Vector2(344, 50)
		element_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		element_label.add_theme_font_size_override("font_size", 36)
	else:
		element_label.position = Vector2(32, 525)
		element_label.size = Vector2(42, 48)
		element_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		element_label.add_theme_font_size_override("font_size", 36)
	hp_label.visible = not guest
	hp_bar.visible = not guest
	mp_label.visible = not is_enemy and not guest
	mp_bar.visible = not is_enemy and not guest
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
