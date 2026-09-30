extends "res://scripts/presentation/StageActorCard.gd"
## Card Stage body language. Same card face and data binding as STAGE_25D; only
## the spatial motion differs: lunges arc out toward the viewer, hits knock the
## card back into depth, dodges slip sideways and deeper. All motion returns to
## home_position / home_rotation, and nothing here touches combat values.

const WINDUP_DISTANCE := 0.45
const LUNGE_FRACTION := 0.46
const LUNGE_LIFT := 0.9 # Z toward the camera at contact, so the swing reads in depth.
const KNOCKBACK := Vector3(0.55, -0.12, -0.9)
const KNOCKBACK_HEAVY := Vector3(1.0, -0.2, -1.6)
const DODGE_SLIP := Vector3(0.5, 0.35, -1.25)
const GUARD_BRACE := Vector3(0.12, -0.05, -0.35)

var slot_rank: int = 0
var slot_role: String = ""


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
