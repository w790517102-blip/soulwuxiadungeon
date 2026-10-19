extends RefCounted
class_name ItemRarity
# 道具稀有度（四級）。道具資料用 "rarity": 1~4，沒寫就是 1（凡品）。
# 稀有度只由介面顯示（名稱旁的章、列光暈），不畫在物品圖裡。名稱要改，只改下面 LEVELS 的 label。
# 章的美術：assets/UI/inventory/rarity_1~4.png（共邊國還沒交）；沒有圖時用程式畫的色塊章。

const MIN := 1
const MAX := 4

const LEVELS := {
	1: {"label": "凡品", "color": Color("#7B7468")},
	2: {"label": "良品", "color": Color("#3F7A58")},
	3: {"label": "稀有", "color": Color("#4A5E9A")},
	4: {"label": "傳說", "color": Color("#9A5A1E")},
}

## 只給預覽截圖用：{"道具名稱": 稀有度}。正式資料請直接在道具裡寫 "rarity"。
static var preview_override: Dictionary = {}

static func rarity_of(item: Dictionary) -> int:
	if preview_override.has(String(item.get("name", ""))):
		return clampi(int(preview_override[String(item.get("name", ""))]), MIN, MAX)
	return clampi(int(item.get("rarity", MIN)), MIN, MAX)

static func label_of(level: int) -> String:
	return String(LEVELS[clampi(level, MIN, MAX)]["label"])

static func color_of(level: int) -> Color:
	return LEVELS[clampi(level, MIN, MAX)]["color"]

static func badge_path(level: int) -> String:
	return "res://assets/UI/inventory/rarity_%d.png" % clampi(level, MIN, MAX)
