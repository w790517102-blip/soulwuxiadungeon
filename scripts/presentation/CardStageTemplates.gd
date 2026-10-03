extends RefCounted
## Card Stage card templates (supplied art). Each template is a face image whose
## character-art window has been cut out, plus the ink-wash window image that sits
## behind the character art. All rectangles are in the ORIGINAL template pixels
## (`canvas`); the face texture itself is stored at FACE_SCALE of that size.
##
##   face   : frame, name bar, information slots, corner ornaments (front layer)
##   ink    : the window as painted in the template (back layer)
##   frame  : the card body inside the ornaments; this is what "card size" means
##   window : where the art / portrait is visible
##
## Information stays the game's existing information; the templates only decide
## where each piece goes.

const FACE_SCALE: float = 0.75
## World width of a card BODY (the frame). Heights follow from each template.
const CARD_WORLD_WIDTH: float = 2.3
const DIR := "res://assets/UI/card_stage/"

const TEMPLATES: Dictionary = {
	# Party members and the scripted guest.
	"character": {
		"face": DIR + "card_char_face.webp",
		"ink": DIR + "card_char_ink.webp",
		"canvas": Vector2(1024, 1536),
		"frame": Rect2(86, 70, 854, 1394),
		"window": Rect2(118, 218, 788, 654),
		"name": Rect2(130, 98, 764, 88),
		"badge": Rect2(138, 912, 140, 138),
		"force": Rect2(300, 922, 588, 108),
		"hp": Rect2(140, 1114, 746, 92),
		"mp": Rect2(140, 1256, 746, 92),
		"status": Rect2(140, 1366, 746, 76),
		"name_font": 68, "slot_font": 52, "badge_font": 92, "force_font": 56, "status_font": 40,
	},
	# Ordinary enemies.
	"enemy": {
		"face": DIR + "card_enemy_face.webp",
		"ink": DIR + "card_enemy_ink.webp",
		"canvas": Vector2(1024, 1536),
		"frame": Rect2(36, 38, 958, 1458),
		"window": Rect2(76, 172, 872, 676),
		"name": Rect2(84, 62, 856, 88),
		"element": Rect2(100, 892, 824, 84),
		"species": Rect2(100, 976, 824, 84),
		"hp": Rect2(88, 1108, 848, 72),
		"status": Rect2(100, 1212, 824, 150),
		"name_font": 68, "slot_font": 44, "row_font": 54, "status_font": 40,
	},
	# Animals (bamboo grove beasts): same layout as the enemy card, bamboo-vine frame.
	"beast": {
		"face": DIR + "card_beast_face.webp",
		"ink": DIR + "card_beast_ink.webp",
		"canvas": Vector2(1024, 1536),
		"frame": Rect2(36, 38, 958, 1458),
		"window": Rect2(76, 172, 872, 676),
		"name": Rect2(84, 62, 856, 88),
		"element": Rect2(100, 892, 824, 84),
		"species": Rect2(100, 976, 824, 84),
		"hp": Rect2(88, 1108, 848, 72),
		"status": Rect2(100, 1212, 824, 150),
		"name_font": 68, "slot_font": 44, "row_font": 54, "status_font": 40,
	},
	# 江湖人士 (blue): the enemy layout with its own frame.
	"jianghu": {
		"face": DIR + "card_jianghu_face.webp",
		"ink": DIR + "card_jianghu_ink.webp",
		"canvas": Vector2(1024, 1536),
		"frame": Rect2(36, 38, 958, 1458),
		"window": Rect2(76, 172, 872, 676),
		"name": Rect2(84, 62, 856, 88),
		"element": Rect2(100, 892, 824, 84),
		"species": Rect2(100, 976, 824, 84),
		"hp": Rect2(88, 1108, 848, 72),
		"status": Rect2(100, 1212, 824, 150),
		"name_font": 68, "slot_font": 44, "row_font": 54, "status_font": 40,
	},
	# 痞子 / 盜賊 / 土匪 (earth yellow): the enemy layout with its own frame.
	"bandit": {
		"face": DIR + "card_bandit_face.webp",
		"ink": DIR + "card_bandit_ink.webp",
		"canvas": Vector2(1024, 1536),
		"frame": Rect2(36, 38, 958, 1458),
		"window": Rect2(76, 172, 872, 676),
		"name": Rect2(84, 62, 856, 88),
		"element": Rect2(100, 892, 824, 84),
		"species": Rect2(100, 976, 824, 84),
		"hp": Rect2(88, 1108, 848, 72),
		"status": Rect2(100, 1212, 824, 150),
		"name_font": 68, "slot_font": 44, "row_font": 54, "status_font": 40,
	},
	# 朝廷人士 (red and black): the enemy layout with its own frame.
	"court": {
		"face": DIR + "card_court_face.webp",
		"ink": DIR + "card_court_ink.webp",
		"canvas": Vector2(1024, 1536),
		"frame": Rect2(36, 38, 958, 1458),
		"window": Rect2(76, 172, 872, 676),
		"name": Rect2(84, 62, 856, 88),
		"element": Rect2(100, 892, 824, 84),
		"species": Rect2(100, 976, 824, 84),
		"hp": Rect2(88, 1108, 848, 72),
		"status": Rect2(100, 1212, 824, 150),
		"name_font": 68, "slot_font": 44, "row_font": 54, "status_font": 40,
	},
	# Bosses (the supplied Molin Yanjiang card, with its decorations outside the frame).
	"boss": {
		"face": DIR + "card_boss_face.webp",
		"ink": DIR + "card_boss_ink.webp",
		"canvas": Vector2(1507, 1044),
		"frame": Rect2(442, 88, 568, 872),
		"window": Rect2(468, 180, 520, 398),
		"name": Rect2(476, 108, 504, 64),
		"element": Rect2(480, 612, 496, 56),
		"species": Rect2(480, 668, 496, 56),
		"hp": Rect2(474, 733, 504, 40),
		"status": Rect2(480, 786, 496, 130),
		"name_font": 44, "slot_font": 26, "row_font": 36, "status_font": 28,
	},
}


## Which template an actor's card uses. An actor can force one with `card_template`.
static func key_for(actor: Dictionary, enemy: bool) -> String:
	var forced: String = String(actor.get("card_template", ""))
	if TEMPLATES.has(forced):
		return forced
	if not enemy:
		return "character"
	var id: String = String(actor.get("id", ""))
	if bool(actor.get("is_boss", false)) or id.begins_with("molin_yanjiang"):
		return "boss"
	if id.begins_with("bamboo_"):
		return "beast"
	# People of the martial world are told apart by their `family` (or `faction`): wanderers of the
	# jianghu on the blue card, bandits and ruffians on the earth-yellow card, the court's men on the
	# red and black one.
	var camp: String = String(actor.get("faction", actor.get("family", ""))).strip_edges()
	if camp in ["jianghu", "江湖", "江湖人士"]:
		return "jianghu"
	if camp in ["bandit", "痞子", "盜賊", "土匪"]:
		return "bandit"
	if camp in ["court", "朝廷", "朝廷人士"]:
		return "court"
	return "enemy"


static func get_template(key: String) -> Dictionary:
	return TEMPLATES.get(key, TEMPLATES["character"])


## World units per template pixel (the frame is CARD_WORLD_WIDTH wide).
static func world_per_pixel(key: String) -> float:
	var frame: Rect2 = get_template(key).frame
	return CARD_WORLD_WIDTH / frame.size.x


## World size of the card body.
static func card_world_size(key: String) -> Vector2:
	var frame: Rect2 = get_template(key).frame
	var scale: float = world_per_pixel(key)
	return frame.size * scale


## Template pixel rectangle -> card-local world rectangle (origin at the frame
## centre, +Y up).
static func to_local_rect(key: String, rect: Rect2) -> Rect2:
	var template: Dictionary = get_template(key)
	var frame: Rect2 = template.frame
	var scale: float = world_per_pixel(key)
	var centre: Vector2 = frame.get_center()
	var top_left := Vector2((rect.position.x - centre.x) * scale, (centre.y - rect.position.y) * scale)
	var size := rect.size * scale
	return Rect2(Vector2(top_left.x, top_left.y - size.y), size)
