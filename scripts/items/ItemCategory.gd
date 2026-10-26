extends RefCounted
class_name ItemCategory
# 道具頁分類：全部／藥物／書籍／裝備／材料／任務／其他（顯示順序即下面 TABS 的順序）。
# 規則只看道具資料（ItemDB）：
#   item["category"]  若有填，優先使用（"consumable" | "book" | "equipment" | "material" | "quest" | "other"）
#   否則看 item["type"]：book → 書籍；consumable、food → 藥物；equipment → 裝備；material → 材料；quest → 任務；
#   其餘（tool、misc…）→ 其他。
# "all" 只用在畫面上的篩選（不是道具自己的分類）。

const ALL := "all"
const CONSUMABLE := "consumable"   # 顯示成「藥物」
const BOOK := "book"
const EQUIPMENT := "equipment"
const MATERIAL := "material"
const QUEST := "quest"
const OTHER := "other"

const TABS := [
	{"id": ALL, "label": "全部"},
	{"id": CONSUMABLE, "label": "藥物"},
	{"id": BOOK, "label": "書籍"},
	{"id": EQUIPMENT, "label": "裝備"},
	{"id": MATERIAL, "label": "材料"},
	{"id": QUEST, "label": "任務"},
	{"id": OTHER, "label": "其他"},
]

const _ITEM_CATEGORIES := [CONSUMABLE, BOOK, EQUIPMENT, MATERIAL, QUEST, OTHER]

static func category_of(item: Dictionary) -> String:
	var explicit := String(item.get("category", ""))
	if explicit in _ITEM_CATEGORIES:
		return explicit
	match String(item.get("type", "")):
		"book": return BOOK
		"consumable", "food": return CONSUMABLE
		"equipment": return EQUIPMENT
		"material": return MATERIAL
		"quest": return QUEST
	return OTHER

## 整理用的排序名次：依左邊分頁的順序（藥物、書籍、裝備、材料、任務、其他）；「全部」不是道具自己的分類，不算
static func sort_rank(item: Dictionary) -> int:
	return maxi(0, _ITEM_CATEGORIES.find(category_of(item)))

## 這個道具在指定的篩選標籤下要不要顯示（"all" = 全部都顯示）
static func matches(item: Dictionary, tab_id: String) -> bool:
	return tab_id == ALL or category_of(item) == tab_id

static func label_of(category_id: String) -> String:
	for t in TABS:
		if t["id"] == category_id:
			return t["label"]
	return category_id

static func empty_text(category_id: String) -> String:
	match category_id:
		ALL: return "背包裡空空如也。"
		BOOK: return "還沒有書籍。"
		EQUIPMENT: return "沒有裝備類道具。"
		MATERIAL: return "沒有材料。"
		QUEST: return "沒有任務道具。"
		OTHER: return "沒有其他道具。"
	return "沒有藥物。"
