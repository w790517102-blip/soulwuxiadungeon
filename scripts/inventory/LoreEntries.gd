extends RefCounted
## 見聞的資料整理（只讀，不改遊戲規則）：三個分類各自的條目清單，每筆含「是否已收錄」。
## 條目格式：{id, name, unlocked, art, summary, rows: [[標籤, 內容]…], prose: 一整段文字（豪傑）}。未收錄的名稱一律是「？？？」。
## 收錄條件沿用舊見聞頁：奇物＝曾經擁有過、豪傑＝LoreDB.is_hero_unlocked、神怪＝旗標 lore_enemy_<id>。

const LoreDBScript = preload("res://scripts/db/LoreDB.gd")
const ItemDBScript = preload("res://scripts/db/ItemDB.gd")
const EnemyDBScript = preload("res://scripts/db/EnemyDB.gd")
const ItemIconMapScript = preload("res://scripts/inventory/ItemIconMap.gd")
const SkillDBScript = preload("res://scripts/db/SkillDB.gd")
const CardStageArtScript = preload("res://scripts/presentation/CardStageArt.gd")

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
	return {"id": id, "name": UNKNOWN, "unlocked": false, "art": "", "summary": "", "rows": [], "prose": ""}

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
		var rows: Array = [["類型", LoreDBScript.item_type_display_name(String(info.get("type", "—")))]]
		var eff: String = ItemDBScript.get_effect_display_text(info)
		if eff != "" and eff != "—":
			rows.append(["效果", eff])
		out.append({"id": id, "name": String(info.get("name", id)), "unlocked": true, "art": art, "summary": _short(String(info.get("description", "")), 60), "rows": rows, "prose": ""})
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
		# 有「身分／地點」等簡介的人物，右頁圖下面的框顯示簡介；沒有就顯示人物誌的開頭
		var meta: Array = h.get("meta", [])
		var summary := "
".join(meta) if not meta.is_empty() else _short(bio, 60)
		out.append({"id": id, "name": String(h.get("name", id)), "unlocked": true, "art": String(h.get("portrait_path", "")), "summary": summary, "rows": [], "prose": bio, "paragraphs": h.get("paragraphs", [])})
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
		var skill_names: Array = []
		var sk_any = e.get("skills", [])
		if typeof(sk_any) == TYPE_ARRAY:
			for sk in sk_any:
				if typeof(sk) == TYPE_DICTIONARY:
					var sid := String((sk as Dictionary).get("skill_id", ""))
					if sid != "":
						skill_names.append(String(_skills().get_skill(sid).get("name", sid)))
		var rows: Array = [
			["種族", species], ["經驗", str(int(e.get("exp", 0)))],
			["氣血", str(int(e.get("max_hp", e.get("hp", 0))))], ["攻擊", str(int(e.get("atk", 0)))],
			["防禦", str(int(e.get("def", 0)))], ["速度", str(int(e.get("speed", 0)))],
			["屬性", String(e.get("element", "—"))],
			["掉落物", "無" if drops.is_empty() else "、".join(drops)],
			["技能", "無" if skill_names.is_empty() else "、".join(skill_names)],
		]
		# 神怪的圖統一用戰鬥卡面的插畫（沒有卡面的才退回舊立繪）
		var card_art: Dictionary = CardStageArtScript.entry_for({"id": id, "portrait_path": String(e.get("portrait_path", ""))})
		var monster_art := String(card_art.get("path", e.get("portrait_path", "")))
		var monster_focus: Vector2 = card_art.get("focus", Vector2(0.5, 0.5))
		out.append({"id": id, "name": String(e.get("name", id)), "unlocked": true, "art": monster_art, "art_focus": monster_focus, "summary": "%s。氣血 %d，攻擊 %d。" % [species, int(e.get("max_hp", e.get("hp", 0))), int(e.get("atk", 0))], "rows": rows, "prose": ""})
	return out

static var _skill_db_inst = null
static func _skills():
	if _skill_db_inst == null:
		_skill_db_inst = SkillDBScript.new()
	return _skill_db_inst
