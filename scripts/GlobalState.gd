# 跨場景共享用的 AutoLoad 腳本 ( 設定成單例 )
# file: GlobalState.gd
extends Node

# 📌 角色移動狀態紀錄（例如讀取場景後自動朝向）
var last_facing_direction: Vector2 = Vector2(1, 1).normalized()

# 📌 江湖屬性：道義 / 恩怨 / 柔情
var ethics := 0
var grudge := 0
var affection := 0

var flags := {}

func get_flag(name: String) -> bool:
	return flags.has(name) and flags[name] == true

func set_flag(name: String, value := true):
	flags[name] = value

# 📌 NPC 好感度（可擴充）
var relationship := {
	"xiaoming": 0,
	"xiaohua": 0,
	"naia": 0
}

# 📌 跨場景旗標：事件觸發、特殊互動、分支觸點
var triggered_flags := {
	# 範例："found_cat_early": true
}

var is_loading: bool = false
var shop_runtime_stock := {}

func begin_load() -> void:
	is_loading = true

func end_load() -> void:
	is_loading = false

func reset_for_load() -> void:
	flags.clear()
	triggered_flags.clear()
	shop_runtime_stock.clear()



# 🔄 移除旗標（可用於重置或NG+）
func clear_flag(flag_name: String):
	triggered_flags.erase(flag_name)

# 💖 好感操作（加減關係值）
func get_relationship(npc_id: String) -> int:
	return relationship.get(npc_id, 0)

func add_relationship(npc_id: String, amount: int):
	relationship[npc_id] = get_relationship(npc_id) + amount

func set_relationship(npc_id: String, value: int):
	relationship[npc_id] = value
