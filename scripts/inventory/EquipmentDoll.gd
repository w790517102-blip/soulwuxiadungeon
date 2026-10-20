extends Control
## 裝備頁中央人物（紙娃娃）。所有圖層用同一張畫布（508×972 像素＝邏輯 254×486），左上角對齊。
## 規則（老闆定案）：劉語塵的紙娃娃只認三個部位：
##   身體護具 → 依「稀有度」挑一整組衣裝（後層、身體、披風前片、前層四張一起換，不能只換一張），沒有那一階的圖就退回凡品；
##   武器 → 每把武器自己有專屬圖（後／前兩層），沒有就退回預設武器圖；
##   機關 → 每個機關自己有專屬圖（後層、本體、背帶），沒裝備就不顯示。
## 其他部位（頭、手、足、飾品）暫時不影響人物。
## 兩種衣裝模式：
##   整張母圖（凡品，目前只有一張未分層的圖）：機關後層墊在母圖下面，其餘（含整把劍）蓋在母圖上面；
##   整張衣裝（第二、三階：doll_<角色>_r<稀有度>.png，沒有分層，劍與機關疊在上面）
##   分層衣裝（第四階：有 doll_r<稀有度>_* 四張）：由後到前 back → body → cloak_front → front → weapon_back → weapon_front（劍不被衣服蓋住）；背帶、連弩是另外兩張全畫布圖，疊在衣裝之上、劍之下（背帶 → 連弩 → 劍）。
## 檔案放在 assets/UI/equipment/doll/：
##   doll_<角色>_master.png                         凡品用的整張母圖
##   doll_r<稀有度>_back／body／cloak_front／front.png   分層衣裝（稀有度＝ItemRarity 的 1~4）
##   doll_weapon_<道具id或default>_back／_front.png
##   doll_mech_<道具id>.png、doll_mech_<道具id>_back.png、doll_strap_<道具id>.png

const DIR := "res://assets/UI/equipment/doll/"
const ItemRarityScript = preload("res://scripts/inventory/ItemRarity.gd")
const ItemDBScript = preload("res://scripts/db/ItemDB.gd")

const LAYER_NAMES := ["back", "weapon_back", "master", "body", "cloak_front", "weapon_front", "mech", "strap", "front"]
## 眼睛對齊（老闆定案：第二、三階是獨立畫的整張圖，臉不同也沒關係，但眼睛要在同一個位置，切換衣裝時視線不跳）。
## 以母圖與第四階（同一張臉）的兩眼中點為基準（畫布 508×972 像素 (300,170)）；下面是第二、三階整張圖需要平移的量（畫布像素，連同疊在上面的劍、連弩一起移，身體與武器的相對位置不變）。
## 量測方式：看兩眼瞳孔中心，取中點，與基準相減（母圖 (299.8,169.5)、二階 (329.5,155.5)、三階 (331,155.8)）。
const EYE_SHIFT := {2: Vector2(-29.7, 14.0), 3: Vector2(-31.2, 13.7)}

const ORDER_MASTER := ["master", "weapon_back", "weapon_front"]
## 劍大方露出來（老闆定案）：衣服不蓋劍，所以劍的兩層都放在所有衣裝層的上面
const ORDER_TIERED := ["back", "body", "cloak_front", "front", "weapon_back", "weapon_front"]

## 連弩（老闆手把手給的位置）：連弩與背帶各是一張全畫布圖，與母圖同一個縮放，直接疊上去；背帶永遠在最上面（斜跨過肩）。
## 疊放（由後到前）：衣裝 → 背帶 → 連弩 → 劍。
## 連弩的微調旋轉：負值＝逆時針（Godot 正值是順時針）。轉軸是弩托靠肩的位置（全畫布 508×972 的座標），背帶不跟著轉。
const MECH_ROTATION_DEG := 0.0
const MECH_PIVOT := Vector2(84, 170)
## 各角色的機關（連弩、背帶）微調：母圖是對著劉語塵的背擺的，別的角色身形不同，要各自位移、縮放、旋轉（以 MECH_PIVOT 為轉軸；shift 是畫布像素）。
const CHAR_MECH := {
	"shumian": {"shift": Vector2(40, 30), "scale": 1.1, "rot": -8.0},
}

var actor_id := ""
var _layers: Dictionary = {}         # 名稱 → TextureRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for layer_name in LAYER_NAMES:
		var r := TextureRect.new()
		r.name = layer_name
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(r)
		_layers[layer_name] = r

func _tex(file: String) -> Texture2D:
	var p := DIR + file + ".png"
	return load(p) as Texture2D if ResourceLoader.exists(p) else null

## 有沒有人物可畫（有母圖或分層衣裝）
func has_figure() -> bool:
	return (_layers["master"] as TextureRect).texture != null or (_layers["body"] as TextureRect).texture != null

func _set_layer(layer_name: String, tex: Texture2D) -> void:
	(_layers[layer_name] as TextureRect).texture = tex

## 整個人物（含劍、連弩）平移 v（畫布像素；節點尺寸是邏輯 px，所以除以 2）
func _apply_shift(v: Vector2) -> void:
	var d := v * 0.5
	for layer_name in LAYER_NAMES:
		var r := _layers[layer_name] as TextureRect
		r.offset_left = d.x
		r.offset_right = d.x
		r.offset_top = d.y
		r.offset_bottom = d.y

func _apply_order(order: Array) -> void:
	for i in order.size():
		move_child(_layers[order[i]], i)

## 角色卡用的頭像：從目前穿的那一階立繪裁出頭部（畫質比戰鬥小頭像好，也會跟著衣裝換）；這個角色沒有立繪就回傳 null，呼叫端退回戰鬥頭像。
const HEAD_REGION := Rect2(150, 20, 250, 270)       # 以母圖與第四階的眼睛為基準（畫布 508×972 像素）

static func head_portrait(id: String) -> Texture2D:
	var equipped: Dictionary = InventorySync.get_equipped(id)
	var rarity := 1
	var body_id := String(equipped.get("armor_body", ""))
	if body_id != "":
		rarity = ItemRarityScript.rarity_of(ItemDBScript.get_def(body_id))
	var path := ""
	var origin := HEAD_REGION.position
	if rarity > 1 and ResourceLoader.exists(DIR + "doll_r%d_front.png" % rarity):
		# 分層衣裝：頭部那層（front）只有頭髮與領子，單獨裁會缺一塊，所以把 back、body、cloak_front、front 四層疊起來再裁
		return _tiered_head(rarity)
	elif rarity > 1 and ResourceLoader.exists(DIR + "doll_%s_r%d.png" % [id, rarity]):
		path = DIR + "doll_%s_r%d.png" % [id, rarity]
		origin -= Vector2(EYE_SHIFT.get(rarity, Vector2.ZERO))        # 整張圖有平移過，頭也跟著在那邊
	elif ResourceLoader.exists(DIR + "doll_%s_master.png" % id):
		path = DIR + "doll_%s_master.png" % id
	if path == "":
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = load(path) as Texture2D
	atlas.region = Rect2(origin, HEAD_REGION.size)
	return atlas

static var _tiered_head_cache: Dictionary = {}

static func _tiered_head(rarity: int) -> Texture2D:
	if _tiered_head_cache.has(rarity):
		return _tiered_head_cache[rarity]
	var canvas: Image = null
	for part in ["back", "body", "cloak_front", "front"]:
		var tex := load(DIR + "doll_r%d_%s.png" % [rarity, part]) as Texture2D
		if tex == null:
			continue
		var img := tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		if canvas == null:
			canvas = Image.create_empty(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		canvas.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	if canvas == null:
		return null
	var out := AtlasTexture.new()
	out.atlas = ImageTexture.create_from_image(canvas)
	out.region = HEAD_REGION
	_tiered_head_cache[rarity] = out
	return out

## 依這位角色目前的裝備重畫所有圖層。回傳 {mode, body_rarity, body_art, weapon_art, mech_art}，給測試與除錯用
func show_actor(id: String, master_name: String = "") -> Dictionary:
	actor_id = id
	var info := {"mode": "none", "body_rarity": 0, "body_art": "", "weapon_art": "", "mech_art": ""}
	for layer_name in LAYER_NAMES:
		_set_layer(layer_name, null)
	var master := _tex("doll_%s_master" % (master_name if master_name != "" else id))
	if master == null:
		return info
	var equipped: Dictionary = InventorySync.get_equipped(id)
	# 身體護具：依稀有度挑整組衣裝；沒有那一階就退回凡品（整張母圖）
	var rarity := 1
	var body_id := String(equipped.get("armor_body", ""))
	if body_id != "":
		rarity = ItemRarityScript.rarity_of(ItemDBScript.get_def(body_id))
		info["body_rarity"] = rarity
	var order: Array = ORDER_MASTER.duplicate()
	var shift := Vector2.ZERO
	var mech_shift := Vector2.ZERO
	var tier_body := _tex("doll_r%d_body" % rarity) if rarity > 1 else null
	var whole := _tex("doll_%s_r%d" % [master_name if master_name != "" else id, rarity]) if rarity > 1 else null
	if tier_body != null:
		info["mode"] = "tiered"
		info["body_art"] = "doll_r%d" % rarity
		for part in ["back", "body", "cloak_front", "front"]:
			_set_layer(part, _tex("doll_r%d_%s" % [rarity, part]))
		order = ORDER_TIERED.duplicate()
	elif whole != null:
		# 整張衣裝（第二、三階：沒有分層，劍與機關疊在它上面）
		info["mode"] = "whole"
		info["body_art"] = "r%d_whole" % rarity
		shift = Vector2(EYE_SHIFT.get(rarity, Vector2.ZERO))
		_set_layer("master", whole)
		order = ORDER_MASTER.duplicate()
	else:
		info["mode"] = "master"
		info["body_art"] = "master"
		_set_layer("master", master)
		order = ORDER_MASTER.duplicate()
	# 武器：每把自己的圖，沒有就預設
	var weapon_id := String(equipped.get("weapon_1", ""))
	if weapon_id != "":
		var used := weapon_id
		var back := _tex("doll_weapon_%s_back" % weapon_id)
		var front := _tex("doll_weapon_%s_front" % weapon_id)
		# 預設武器圖是長劍：只有劍類武器才退回它（筆、琴、刀不會憑空背一把劍；它們要有自己的圖才會畫）
		var is_sword := String(ItemDBScript.get_def(weapon_id).get("weapon_type", "")) == "劍"
		if back == null and front == null and is_sword:
			used = "default"
			back = _tex("doll_weapon_default_back")
			front = _tex("doll_weapon_default_front")
		_set_layer("weapon_back", back)
		_set_layer("weapon_front", front)
		if back != null or front != null:
			info["weapon_art"] = used
	# 機關：每個自己的圖，沒裝備就不顯示
	var mech_id := String(equipped.get("mechanism", ""))
	if mech_id != "":
		var mech := _tex("doll_mech_%s" % mech_id)
		if mech != null:
			_set_layer("mech", mech)
			var fit: Dictionary = CHAR_MECH.get(id, {"shift": Vector2.ZERO, "scale": 1.0, "rot": 0.0})
			for mech_layer in ["mech", "strap"]:
				var mr := _layers[mech_layer] as TextureRect
				mr.pivot_offset = MECH_PIVOT
				mr.rotation_degrees = MECH_ROTATION_DEG + float(fit["rot"])
				mr.scale = Vector2.ONE * float(fit["scale"])
				mech_shift = Vector2(fit["shift"]) * 0.5
			_set_layer("strap", _tex("doll_strap_%s" % mech_id))
			info["mech_art"] = mech_id
			# 老闆定案的順序：背帶在最下（衣服之上），連弩壓在背帶上面，但不超過劍
			var at := order.find("weapon_back")
			order.insert(at, "strap")
			order.insert(at + 1, "mech")
	_apply_shift(shift)
	if mech_shift != Vector2.ZERO:
		for mech_layer in ["mech", "strap"]:
			var mr2 := _layers[mech_layer] as TextureRect
			mr2.offset_left += mech_shift.x
			mr2.offset_right += mech_shift.x
			mr2.offset_top += mech_shift.y
			mr2.offset_bottom += mech_shift.y
	_apply_order(order)
	return info
