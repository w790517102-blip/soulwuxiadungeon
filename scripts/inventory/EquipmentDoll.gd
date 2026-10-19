extends Control
## 裝備頁中央人物（紙娃娃）。所有圖層用同一張畫布（508×972 像素＝邏輯 254×486），左上角對齊，由後到前疊：
##   base（母圖）→ 武器後層 → 機關後層 → 身體護具（依稀有度） → 機關 → 背帶 → 武器前層
## 規則（老闆定案）：劉語塵的紙娃娃只認三個部位：
##   身體護具 → 依「稀有度」（1 凡品～4 傳說）挑圖，沒有那一階的圖就退回凡品；
##   武器 → 每把武器自己有專屬圖，沒有就退回預設武器圖；
##   機關 → 每個機關自己有專屬圖，沒裝備就不顯示。
## 其他部位（頭、手、足、飾品）暫時不影響人物。
## 檔案放在 assets/UI/equipment/doll/：
##   doll_<角色>_master.png            母圖（共邊國 V1：側背身回望，不含劍與劍帶）
##   doll_body_<稀有度1~4>.png         身體護具層（畫布同母圖）
##   doll_weapon_<道具id>_back／_front.png、doll_weapon_default_back／_front.png   武器的後／前層
##   doll_mech_<道具id>.png、doll_strap_<道具id>.png   機關本體與背帶（掛點見 MECH_MOUNT）

const DIR := "res://assets/UI/equipment/doll/"
const ItemRarityScript = preload("res://scripts/inventory/ItemRarity.gd")
const ItemDBScript = preload("res://scripts/db/ItemDB.gd")

var _base: TextureRect
var _layers: Dictionary = {}         # 名稱 → TextureRect
var actor_id := ""

const LAYER_ORDER := ["weapon_back", "mech_back", "body", "mech", "strap", "weapon_front"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base = _new_layer("Base")
	for name in LAYER_ORDER:
		_layers[name] = _new_layer(name)

func _new_layer(layer_name: String) -> TextureRect:
	var r := TextureRect.new()
	r.name = layer_name
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(r)
	return r

func _tex(file: String) -> Texture2D:
	var p := DIR + file + ".png"
	return load(p) as Texture2D if ResourceLoader.exists(p) else null

## 依這位角色目前的裝備重畫所有圖層。回傳 {body_rarity, body_art（實際用的檔）, weapon_art, mech_art}，給測試與除錯用
func show_actor(id: String, master_name: String = "") -> Dictionary:
	actor_id = id
	var info := {"body_rarity": 0, "body_art": "", "weapon_art": "", "mech_art": ""}
	var master := _tex("doll_%s_master" % (master_name if master_name != "" else id))
	_base.texture = master
	for name in LAYER_ORDER:
		(_layers[name] as TextureRect).texture = null
	_base.modulate = Color.WHITE
	if master == null:
		return info
	var equipped: Dictionary = InventorySync.get_equipped(id)
	# 身體護具：依稀有度
	var body_id := String(equipped.get("armor_body", ""))
	if body_id != "":
		var rarity := ItemRarityScript.rarity_of(ItemDBScript.get_def(body_id))
		info["body_rarity"] = rarity
		var art_rarity := rarity
		var tex := _tex("doll_body_%d" % rarity)
		if tex == null and rarity != 1:
			art_rarity = 1
			tex = _tex("doll_body_1")          # 沒有那一階的圖：退回凡品
		if tex != null:
			(_layers["body"] as TextureRect).texture = tex
			info["body_art"] = "doll_body_%d" % art_rarity
		# 沒有任何身體護具圖（素材趕工中）：保持母圖原樣，不換色
	# 武器：每把自己的圖，沒有就預設
	var weapon_id := String(equipped.get("weapon_1", ""))
	if weapon_id != "":
		var back := _tex("doll_weapon_%s_back" % weapon_id)
		var front := _tex("doll_weapon_%s_front" % weapon_id)
		var used := weapon_id
		if back == null and front == null:
			back = _tex("doll_weapon_default_back")
			front = _tex("doll_weapon_default_front")
			used = "default"
		(_layers["weapon_back"] as TextureRect).texture = back
		(_layers["weapon_front"] as TextureRect).texture = front
		info["weapon_art"] = used if (back != null or front != null) else ""
	# 機關：每個自己的圖，沒裝備就不顯示
	var mech_id := String(equipped.get("mechanism", ""))
	if mech_id != "":
		var mech := _tex("doll_mech_%s" % mech_id)
		if mech != null:
			(_layers["mech"] as TextureRect).texture = mech
			(_layers["strap"] as TextureRect).texture = _tex("doll_strap_%s" % mech_id)
			(_layers["mech_back"] as TextureRect).texture = _tex("doll_mech_%s_back" % mech_id)
			info["mech_art"] = mech_id
	return info
