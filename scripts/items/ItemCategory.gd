extends RefCounted
class_name ItemCategory
# 道具頁的分類標籤：消耗品／書籍／裝備／其他。
# 規則只看道具資料（ItemDB）：
#   item["category"]  若有填，優先使用（"consumable" | "book" | "equipment" | "other"）——之後書籍道具在資料裡加這個欄位即可。
#   否則看 item["type"]：book → 書籍；consumable、food → 消耗品；equipment → 裝備；其餘（material、quest、tool、misc…）→ 其他。
# 書籍目前還沒有任何道具標成 book（現有的書暫時算消耗品），所以「書籍」分頁會是空的，等資料標好就會出現。

const CONSUMABLE := "consumable"
const BOOK := "book"
const EQUIPMENT := "equipment"
const OTHER := "other"

## 標籤順序與顯示文字
const TABS := [
	{"id": CONSUMABLE, "label": "消耗品"},
	{"id": BOOK, "label": "書籍"},
	{"id": EQUIPMENT, "label": "裝備"},
	{"id": OTHER, "label": "其他"},
]

static func category_of(item: Dictionary) -> String:
	var explicit := String(item.get("category", ""))
	if explicit in [CONSUMABLE, BOOK, EQUIPMENT, OTHER]:
		return explicit
	match String(item.get("type", "")):
		"book": return BOOK
		"consumable", "food": return CONSUMABLE
		"equipment": return EQUIPMENT
	return OTHER

static func label_of(category_id: String) -> String:
	for t in TABS:
		if t["id"] == category_id:
			return t["label"]
	return category_id

static func empty_text(category_id: String) -> String:
	match category_id:
		BOOK: return "還沒有書籍。"
		EQUIPMENT: return "沒有裝備類道具。"
		OTHER: return "沒有其他道具。"
	return "沒有消耗品。"
