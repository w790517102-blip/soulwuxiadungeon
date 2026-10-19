extends Control
## 裝備頁中央人物（紙娃娃）。所有圖層用同一張畫布（508×972 像素＝邏輯 254×486），左上角對齊。
## 規則（老闆定案）：劉語塵的紙娃娃只認三個部位：
##   身體護具 → 依「稀有度」挑一整組衣裝（後層、身體、披風前片、前層四張一起換，不能只換一張），沒有那一階的圖就退回凡品；
##   武器 → 每把武器自己有專屬圖（後／前兩層），沒有就退回預設武器圖；
##   機關 → 每個機關自己有專屬圖（後層、本體、背帶），沒裝備就不顯示。
## 其他部位（頭、手、足、飾品）暫時不影響人物。
## 兩種衣裝模式：
##   整張母圖（凡品，目前只有一張未分層的圖）：機關後層墊在母圖下面，其餘（含整把劍）蓋在母圖上面；
##   分層衣裝（有 doll_r<稀有度>_* 四張）：由後到前 back → mech_back → body → cloak_front → mech → strap → front → weapon_back → weapon_front（劍不被衣服蓋住）。
## 檔案放在 assets/UI/equipment/doll/：
##   doll_<角色>_master.png                         凡品用的整張母圖
##   doll_r<稀有度>_back／body／cloak_front／front.png   分層衣裝（稀有度＝ItemRarity 的 1~4）
##   doll_weapon_<道具id或default>_back／_front.png
##   doll_mech_<道具id>.png、doll_mech_<道具id>_back.png、doll_strap_<道具id>.png

const DIR := "res://assets/UI/equipment/doll/"
const ItemRarityScript = preload("res://scripts/inventory/ItemRarity.gd")
const ItemDBScript = preload("res://scripts/db/ItemDB.gd")

const LAYER_NAMES := ["back", "weapon_back", "mech_back", "master", "body", "cloak_front", "weapon_front", "mech", "strap", "front", "mech_local"]
const ORDER_MASTER := ["mech_back", "master", "mech", "strap", "weapon_back", "weapon_front"]
## 劍大方露出來（老闆定案）：衣服不蓋劍，所以劍的兩層都放在所有衣裝層的上面
const ORDER_TIERED := ["back", "mech_back", "body", "cloak_front", "mech", "strap", "front", "weapon_back", "weapon_front"]

## 試穿用：背在背上的連弩（單獨一張局部圖，自己擺位置、旋轉、縮放，不用美術那九層的連弩）。
## 照老闆的參考圖：弩身直立、弩托在上、弓臂在下，背在畫面左上背。mech_above_sword＝連弩在劍上面；false＝劍在連弩上面。
const MECH_LOCAL := {"center": Vector2(86, 188), "size": Vector2(190, 116), "rotation_deg": 100.0}
static var mech_above_sword := true

var actor_id := ""
var _layers: Dictionary = {}         # 名稱 → TextureRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for layer_name in LAYER_NAMES:
		var r := TextureRect.new()
		r.name = layer_name
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		if layer_name != "mech_local":
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

func _apply_order(order: Array) -> void:
	for i in order.size():
		move_child(_layers[order[i]], i)

func _place_local_mech(tex: Texture2D) -> void:
	var r := _layers["mech_local"] as TextureRect
	r.texture = tex
	r.size = MECH_LOCAL["size"]
	r.pivot_offset = r.size * 0.5
	r.position = Vector2(MECH_LOCAL["center"]) - r.size * 0.5
	r.rotation_degrees = float(MECH_LOCAL["rotation_deg"])

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
	var tier_body := _tex("doll_r%d_body" % rarity) if rarity > 1 else null
	if tier_body != null:
		info["mode"] = "tiered"
		info["body_art"] = "doll_r%d" % rarity
		for part in ["back", "body", "cloak_front", "front"]:
			_set_layer(part, _tex("doll_r%d_%s" % [rarity, part]))
		_apply_order(ORDER_TIERED)
	else:
		info["mode"] = "master"
		info["body_art"] = "master"
		_set_layer("master", master)
		_apply_order(ORDER_MASTER)
	# 武器：每把自己的圖，沒有就預設
	var weapon_id := String(equipped.get("weapon_1", ""))
	if weapon_id != "":
		var used := weapon_id
		var back := _tex("doll_weapon_%s_back" % weapon_id)
		var front := _tex("doll_weapon_%s_front" % weapon_id)
		if back == null and front == null:
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
		var local := _tex("doll_mechlocal_%s" % mech_id)
		if local != null:
			_place_local_mech(local)
			info["mech_art"] = mech_id
			var order: Array = (ORDER_MASTER if info["mode"] == "master" else ORDER_TIERED).duplicate()
			if mech_above_sword:
				order.append("mech_local")
			else:
				order.insert(order.find("weapon_back"), "mech_local")
			_apply_order(order)
			return info
		var mech := _tex("doll_mech_%s" % mech_id)
		if mech != null:
			_set_layer("mech", mech)
			_set_layer("strap", _tex("doll_strap_%s" % mech_id))
			_set_layer("mech_back", _tex("doll_mech_%s_back" % mech_id))
			info["mech_art"] = mech_id
	return info
