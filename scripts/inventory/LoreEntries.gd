extends RefCounted
## 見聞的資料整理（只讀，不改遊戲規則）：三個分類各自的條目清單，每筆含「是否已收錄」。
## 條目格式：{id, name, unlocked, art, summary, detail: Array[String]}。未收錄的名稱一律是「？？？」。
## 收錄條件沿用舊見聞頁：奇物＝曾經擁有過、豪傑＝LoreDB.is_hero_unlocked、神怪＝旗標 lore_enemy_<id>。

const LoreDBScript = preload("res://scripts/db/LoreDB.gd")
const ItemDBScript = preload("res://scripts/db/ItemDB.gd")
const EnemyDBScript = preload("res://scripts/db/EnemyDB.gd")
const ItemIconMapScript = preload("res://scripts/inventory/ItemIconMap.gd")

const CATEGORIES := ["奇物", "豪傑", "神怪"]
const UNKNOWN := "？？？"

static func entries(category: String) -> Array:
	match category:
		"奇物":
			return _items()
		"豪傑":
			return _heroes()
		"神怪":
			return _monsters()
	return []

static func progress(list: Array) -> Vector2i:
	var n := 0
	for e in list:
		if bool((e as Dictionary).get("unlocked", false)):
			n += 1
	return Vector2i(n, list.size())

## 第一筆已收錄的位置（沒有就回 0）
static func first_unlocked(list: Array) -> int:
	for i in list.size():
		if bool((list[i] as Dictionary).get("unlocked", false)):
			return i
	return 0

static func _short(text: String, n: int) -> String:
	var t := text.strip_edges().replace("\n", "")
	return t if t.length() <= n else t.substr(0, n) + "…"

static func _locked(id: String) -> Dictionary:
	return {"id": id, "name": UNKNOWN, "unlocked": false, "art": "", "summary": "尚未收錄。", "detail": ["尚未收錄這一筆見聞。", "（繼續行走江湖，會有所發現。）"]}

static func _items() -> Array:
	var out: Array = []
	var ids: Array = []
	for k in ItemDBScript.ITEM_DEFS.keys():
		if String(k) != "":
			ids.append(String(k))
	ids.sort()
	for id in ids:
		var owned: bool = InventorySync != null and InventorySync.has_method("has_ever_owned") and InventorySync.has_ever_owned(id)
		if not owned:
			out.append(_locked(id))
			continue
		var info: Dictionary = LoreDBScript.get_item_lore_detail(id)
		if info.is_empty():
			continue
		var art: String = ItemIconMapScript.art_path(id, info)
		var detail: Array = ["類型：%s" % LoreDBScript.item_type_display_name(String(info.get("type", "—")))]
		var eff: String = ItemDBScript.get_effect_display_text(info)
		if eff != "" and eff != "—":
			detail.append("效果：%s" % eff)
		detail.append(String(info.get("description", "")))
		out.append({"id": id, "name": String(info.get("name", id)), "unlocked": true, "art": art, "summary": _short(String(info.get("description", "")), 48), "detail": detail})
	return out

static func _heroes() -> Array:
	var out: Array = []
	for id_any in LoreDBScript.get_hero_ids():
		var id := String(id_any)
		if not LoreDBScript.is_hero_unlocked(id):
			out.append(_locked(id))
			continue
		var h: Dictionary = LoreDBScript.get_hero_def(id)
		var bio := String(h.get("bio", "尚無人物誌內容。"))
		out.append({"id": id, "name": String(h.get("name", id)), "unlocked": true, "art": String(h.get("portrait_path", "")), "summary": _short(bio, 48), "detail": [bio]})
	return out

static func _monsters() -> Array:
	var out: Array = []
	var ids: Array = []
	for k in EnemyDBScript.ENEMY_DEFS.keys():
		if String(k) != "":
			ids.append(String(k))
	ids.sort()
	for id in ids:
		var seen: bool = GlobalState != null and GlobalState.has_method("get_flag") and bool(GlobalState.get_flag("lore_enemy_%s" % id))
		if not seen:
			out.append(_locked(id))
			continue
		var e: Dictionary = LoreDBScript.get_enemy_lore_detail(id)
		if e.is_empty():
			continue
		var species := String(e.get("species", e.get("archetype", "江湖人士")))
		var drops: Array = []
		var drops_any = e.get("drops", [])
		if typeof(drops_any) == TYPE_ARRAY:
			for d in drops_any:
				if typeof(d) == TYPE_DICTIONARY:
					var did := String((d as Dictionary).get("id", ""))
					if did != "":
						drops.append(String(ItemDBScript.get_def(did).get("name", did)))
		var detail: Array = [
			"種族：%s　　經驗：%d" % [species, int(e.get("exp", 0))],
			"氣血 %d　攻擊 %d　防禦 %d　速度 %d" % [int(e.get("max_hp", e.get("hp", 0))), int(e.get("atk", 0)), int(e.get("def", 0)), int(e.get("speed", 0))],
			"屬性：%s" % String(e.get("element", "—")),
			"掉落：%s" % ("無" if drops.is_empty() else "、".join(drops)),
		]
		out.append({"id": id, "name": String(e.get("name", id)), "unlocked": true, "art": String(e.get("portrait_path", "")), "summary": "%s。血量 %d，攻擊 %d。" % [species, int(e.get("max_hp", e.get("hp", 0))), int(e.get("atk", 0))], "detail": detail})
	return out
