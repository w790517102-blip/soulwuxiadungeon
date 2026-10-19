extends RefCounted
## 機關：裝備在身上的機關，戰鬥指令的「機關」按鈕就是啟動它的 TRIGGER。
## 機關不是道具（不受「禁止使用道具」規則影響，也不走道具清單）；沒有 trigger 的機關是被動的，不會有按鈕。
## 數值、限制、攻擊段數都沿用原有效果（ItemEffectDispatcher），這裡只負責「找到觸發器」與「發動」。

const SLOT := "mechanism"
const ItemDB = preload("res://scripts/db/ItemDB.gd")

## 這位角色身上機關的觸發器；沒有裝備機關、或機關沒有 trigger（被動）就回傳空字典。
## 回傳的字典可直接丟給 ItemEffectDispatcher / 目標選擇（含 target_scope、effect、power…）。
static func get_trigger(actor: Dictionary) -> Dictionary:
	var actor_id := String(actor.get("id", ""))
	if actor_id == "":
		return {}
	var equipped: Dictionary = InventorySync.get_equipped(actor_id)
	var item_id := String(equipped.get(SLOT, ""))
	if item_id == "":
		return {}
	var def: Dictionary = ItemDB.get_def(item_id)
	var trigger_raw = def.get("trigger", null)
	if typeof(trigger_raw) != TYPE_DICTIONARY:
		return {}
	var out: Dictionary = (trigger_raw as Dictionary).duplicate(true)
	out["id"] = item_id
	out["name"] = String(def.get("name", item_id))
	out["use_scope"] = "battle"
	out["no_consume"] = true          # 機關本體不會用掉；消耗的是它的彈藥
	out["is_mechanism"] = true
	return out

## 彈藥不足等「還沒開始就不能發動」的原因；空字串＝可以發動。
static func block_reason(trigger: Dictionary) -> String:
	var ammo_id := String(trigger.get("ammo_item_id", ""))
	if ammo_id != "" and int(InventorySync.get_item_by_id(ammo_id).get("count", 0)) <= 0:
		return "箭矢已耗盡！"
	return ""

## 發動（已選好目標）。成功才算用掉這次行動，回傳是否成功。
static func fire(controller, user: Dictionary, trigger: Dictionary, target: Dictionary) -> bool:
	controller._show_caption(String(trigger.get("name", "")))
	var ok: bool = controller.item_dispatcher.apply(controller, user, trigger, target)
	controller._update_ui_for_actor(target)
	controller._update_ui_for_actor(user)
	if not ok:
		return false
	controller.check_battle_status()
	if controller.battle_finished:
		return true
	user["acted_this_turn"] = true
	controller._maybe_end_turn()
	return true
