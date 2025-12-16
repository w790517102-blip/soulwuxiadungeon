# 檔案一：ChatterStageRule.gd（修正 _to_string 不再用 ?:）
@tool
class_name ChatterStageRule
extends Resource

@export var min: int = 0
@export var max: int = 999
@export var enabled: bool = true
@export var lines: Array[String] = []

func _to_string() -> String:
	# 原本："%s" % [enabled ? "on" : "off"]  → Godot 不支援 ?: ，改用 if-else 表達式
	var flag := "on" if enabled else "off"
	return "Rule %d..%d (%s)" % [min, max, flag]
