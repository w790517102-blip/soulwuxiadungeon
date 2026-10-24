class_name NpcInteractionAdapter
extends RefCounted

# 舊式 NPC（有 can_interact、Area2D 進出、_unhandled_input 裡等空白鍵）自動套用預設的三層互動：
#   碰撞區  NPC 自己的 CollisionShape2D（本類別不碰）
#   蛋黃區  NPC 在畫面上的外框（InteractionTarget 預設）
#   蛋白區  固定半徑（DEFAULT_RADIUS），腳底到 NPC 腳底的距離
# 這樣滑鼠點 NPC、走過去互動、空白鍵互動都走中央的 InteractionResolver，舊的 Area2D 不再當觸發範圍。
#
# 場景或腳本想用自己畫的對話範圍：在 NPC 底下自己放一個 InteractionTarget（這裡看到就不會再套），
# 或在 NPC 上 set_meta("custom_interaction_zone", true) 表示完全自己處理。
#
# 觸發方式：不改任何 NPC 腳本。打開 can_interact，替它按一次空白鍵（呼叫它原本的 _unhandled_input），再把 can_interact 還原。
# NPC 自己的條件（對話中不理、劇情旗標）都還在原本的流程裡。

const DEFAULT_RADIUS := 80.0
const DEFAULT_HOVER_MARGIN := 6.0
const OPT_OUT_META := "custom_interaction_zone"


## 掃一個場景底下所有符合的 NPC，回傳這次套用的數量。
static func adopt_scene(scene_root: Node) -> int:
	var count := 0
	for node in _collect(scene_root):
		if adopt(node):
			count += 1
	return count


static func is_legacy_npc(node: Node) -> bool:
	if not (node is CharacterBody2D) or node.name == "LiuYu":
		return false
	if node.has_meta(OPT_OUT_META):
		return false
	if not ("can_interact" in node) or not node.has_method("_unhandled_input"):
		return false
	for child in node.get_children():
		if child is InteractionTarget:
			return false
	return true


static func adopt(npc: Node) -> bool:
	if not is_legacy_npc(npc):
		return false
	var target := InteractionTarget.new()
	target.name = "InteractionTarget"
	target.mode = InteractionTarget.Mode.RADIUS
	target.display_name = String(npc.name)
	target.interaction_radius = DEFAULT_RADIUS
	target.hover_margin = DEFAULT_HOVER_MARGIN
	target.handler = func(_player: Node2D) -> void:
		_press_space_on(npc)
	npc.add_child(target)
	# 舊的 Area2D 不再決定誰能互動（否則空白鍵會被新舊兩套各處理一次）
	for child in npc.get_children():
		if child is Area2D:
			(child as Area2D).set_deferred("monitoring", false)
	npc.set("can_interact", false)
	return true


static func _press_space_on(npc: Node) -> void:
	if not is_instance_valid(npc):
		return
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	npc.set("can_interact", true)
	npc.call("_unhandled_input", event)
	if is_instance_valid(npc):
		npc.set("can_interact", false)


static func _collect(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if is_legacy_npc(child):
			out.append(child)
		out.append_array(_collect(child))
	return out
