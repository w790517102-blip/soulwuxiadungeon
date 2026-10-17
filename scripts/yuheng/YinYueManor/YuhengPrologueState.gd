extends RefCounted
class_name YuhengPrologueState

# ------------------------------------------------------------
# 玉衡鎮序章收尾：夜談 → 留宿 → 翌日自由探索 → 書眠支線／烈風寨分岔
#
# 這裡只放「狀態」：旗標名稱、白書眠入隊、《渠燈補封》支線的接取／完成／錯過、啟程結算。
# 場景、NPC 與對話留在各自的場景腳本；各場景一律從這裡判斷狀態，避免同一件事在不同地方各存一份旗標。
#
# 三件事彼此獨立，各自有自己的持久化來源：
#   白書眠是否已入隊     → F_SHUMIAN_JOINED（旗標）+ TeamData 名冊
#   《渠燈補封》支線進度  → F_QD_ACCEPTED / F_QD_DONE / F_QD_MISSED（旗標）+ SideQuestManager 任務紀錄
#   是否已啟程烈風寨     → F_LIEFENG_CHAPTER_STARTED（旗標）
# ------------------------------------------------------------

const F_AFTER_FISH_READY := "main_yh_manor_after_fish_ready"
const F_NIGHT_MEETING_DONE := "event_yin_yue_night_meeting_done"
## 夜談後留宿一晚的黑幕只播一次；轉到白天場景之後才會設定。
const F_OVERNIGHT_DONE := "event_yin_yue_overnight_done"
## 留宿後第一次醒來（白天山莊）的「主線更新」旁白已經看過。
const F_DAY_ARRIVAL_DONE := "event_yin_yue_day_arrival_done"
const F_READY_FOR_QINGFENG := "main_yh_ready_for_qingfeng"

## 夜談之後，書眠的《渠燈補封》支線開放（可以找書眠接取）。
const F_SHUMIAN_SIDE_AVAILABLE := "shumian_pre_departure_available"
## 玩家在飲月山莊白天答應陪書眠回舊水道。
const F_QD_ACCEPTED := "shumian_qudeng_accepted"
const F_QD_DONE := "shumian_clean_sewer_done"
## 玩家啟程烈風寨時支線尚未完成：支線標記為錯過（終止狀態，不是任務失敗）。
const F_QD_MISSED := "shumian_qudeng_missed"

const F_SHUMIAN_JOIN_PENDING := "party_shumian_join_pending"
const F_SHUMIAN_JOINED := "party_shumian_joined"

const F_ZUOYIN_SUPPLIES_RECEIVED := "main_yh_zuoyin_supplies_received"
const F_LIEFENG_CHAPTER_STARTED := "main_chapter_liefeng_started"

const SHUMIAN_ACTOR_ID := "shumian"
const QUDENG_QUEST_ID := "shumian_qudeng"
const QUDENG_TITLE := "渠燈補封"
const QUDENG_DESCRIPTION := "書眠想回舊水道，把自己貼下的符補穩，也把該看的看完。"
const QUDENG_OBJECTIVE := "陪書眠回到舊水道，補穩藥師舊室裡的牆符、獅頭水口與渠燈。"

enum SideQuestState { UNAVAILABLE, AVAILABLE, IN_PROGRESS, DONE, MISSED }


# ------------------------------------------------------------
# Autoload 存取（用節點路徑取，不在編譯時綁定全域識別字，這樣 --script 的 headless 測試也能載入這個類別）
# ------------------------------------------------------------
static func _autoload(autoload_name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(autoload_name)


# ------------------------------------------------------------
# 旗標
# ------------------------------------------------------------
static func flag(flag_name: String) -> bool:
	var global_state := _autoload("GlobalState")
	return global_state != null and bool(global_state.get_flag(flag_name))


static func set_flag(flag_name: String, value := true) -> void:
	var global_state := _autoload("GlobalState")
	if global_state != null:
		global_state.set_flag(flag_name, value)


# ------------------------------------------------------------
# 階段判斷
# ------------------------------------------------------------
## 夜談結束、尚未啟程烈風寨：序章收尾階段（白箋居暫停營業、飲月山莊白天人物配置都只在這段成立）。
static func is_prologue_ending_phase() -> bool:
	return flag(F_NIGHT_MEETING_DONE) and not flag(F_LIEFENG_CHAPTER_STARTED)


# ------------------------------------------------------------
# 白書眠入隊
# ------------------------------------------------------------
static func is_shumian_joined() -> bool:
	if flag(F_SHUMIAN_JOINED):
		return true
	var team_data := _autoload("TeamData")
	return team_data != null and team_data.is_roster_unlocked(SHUMIAN_ACTOR_ID)


## 白書眠正式入隊（可重複呼叫）：解鎖名冊並放進空的同伴格（第 2、3 格）。第 4 格是客座，這裡不碰。
static func join_shumian() -> void:
	var team_data := _autoload("TeamData")
	if team_data != null:
		team_data.unlock_roster(SHUMIAN_ACTOR_ID)
		# 正式入隊的書眠一律是序章 Lv6（舊存檔的書眠卡片可能還停在 Lv2；已 >= Lv6 的不動，重複呼叫不會重複升級）
		team_data.ensure_shumian_story_join_level()
		var ids: Array = team_data.current_team_ids.duplicate()
		if not ids.has(SHUMIAN_ACTOR_ID):
			for slot in [1, 2]:
				while ids.size() <= slot:
					ids.append("")
				if String(ids[slot]) == "":
					ids[slot] = SHUMIAN_ACTOR_ID
					break
			team_data.current_team_ids = ids
	set_flag(F_SHUMIAN_JOINED, true)
	set_flag(F_SHUMIAN_JOIN_PENDING, false)


## 讀檔後的修復：書眠「已經正式入隊」卻低於序章該有的 Lv6，就補到 Lv6（只升不降，條件成立才做，補過之後不會再動）。
## 條件：旗標 party_shumian_joined 為真、名冊已解鎖書眠。這兩個條件只有正式入隊流程才會同時成立，
## 而正式入隊流程本來就保證 Lv6，所以低於 Lv6 一定是舊存檔留下的入隊初始化錯誤，不是正常進度。
static func repair_shumian_join_level() -> bool:
	if not flag(F_SHUMIAN_JOINED):
		return false
	var team_data := _autoload("TeamData")
	if team_data == null or not team_data.is_roster_unlocked(SHUMIAN_ACTOR_ID):
		return false
	return team_data.ensure_shumian_story_join_level()


# ------------------------------------------------------------
# 《渠燈補封》支線
# ------------------------------------------------------------
static func get_side_quest_state() -> SideQuestState:
	if flag(F_QD_DONE):
		return SideQuestState.DONE
	if flag(F_QD_MISSED):
		return SideQuestState.MISSED
	if flag(F_QD_ACCEPTED):
		return SideQuestState.IN_PROGRESS
	if flag(F_SHUMIAN_SIDE_AVAILABLE):
		return SideQuestState.AVAILABLE
	return SideQuestState.UNAVAILABLE


## 玩家答應陪書眠去舊水道：接取支線並讓書眠入隊（可重複呼叫，不會重複註冊或重複入隊）。
static func accept_qudeng() -> void:
	if get_side_quest_state() != SideQuestState.AVAILABLE:
		return
	set_flag(F_QD_ACCEPTED, true)
	var side_quests := _autoload("SideQuestManager")
	if side_quests != null:
		side_quests.register_quest(QUDENG_QUEST_ID, {
			"quest_id": QUDENG_QUEST_ID,
			"title": QUDENG_TITLE,
			"description": QUDENG_DESCRIPTION,
			"current_objective": QUDENG_OBJECTIVE,
			"notes": [],
		})
		side_quests.advance_quest(QUDENG_QUEST_ID, 1)
	join_shumian()


## 舊水道藥師舊室三處補封完成時呼叫（yuheng_sewer_true_room.gd）。不改變入隊狀態。
static func on_qudeng_completed() -> void:
	var side_quests := _autoload("SideQuestManager")
	if side_quests != null and side_quests.get_quest(QUDENG_QUEST_ID).has("quest_id"):
		side_quests.complete_quest(QUDENG_QUEST_ID)


## 啟程時結算支線：已完成的保留；其餘（沒接過或接了沒做完）標記為錯過。回傳是否真的標記了錯過。
static func settle_side_quest_for_departure() -> bool:
	var state := get_side_quest_state()
	if state == SideQuestState.DONE or state == SideQuestState.MISSED:
		return false
	set_flag(F_QD_MISSED, true)
	var side_quests := _autoload("SideQuestManager")
	if side_quests != null:
		side_quests.mark_quest_missed(QUDENG_QUEST_ID, {
			"quest_id": QUDENG_QUEST_ID,
			"title": QUDENG_TITLE,
			"description": QUDENG_DESCRIPTION,
			"current_objective": "已離開玉衡鎮，這條支線沒能完成。",
			"notes": [],
		})
	return true


# ------------------------------------------------------------
# 前後遮擋：以腳底的 y 排序（NPC 節點原點與腳底的距離各不相同）
# ------------------------------------------------------------
static var _feet_cache: Dictionary = {}


## 目前這一格圖的「腳底中心」，相對於 sprite 節點的原點（以不透明像素算出）。
static func feet_offset_in_sprite(sprite: AnimatedSprite2D) -> Vector2:
	var frames := sprite.sprite_frames
	if frames == null or not frames.has_animation(sprite.animation):
		return Vector2.ZERO
	var texture: Texture2D = frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null:
		return Vector2.ZERO
	var key := "%s|%s" % [texture.get_rid().get_id(), str(texture.get_size())]
	if texture is AtlasTexture:
		key = "%d|%s" % [(texture as AtlasTexture).atlas.get_rid().get_id(), str((texture as AtlasTexture).region)]
	if not _feet_cache.has(key):
		var image := texture.get_image()
		var bottom := -1
		var left := 1 << 30
		var right := -1
		if image != null:
			for y in range(image.get_height() - 1, -1, -1):
				for x in range(image.get_width()):
					if image.get_pixel(x, y).a > 0.3:
						bottom = maxi(bottom, y)
						left = mini(left, x)
						right = maxi(right, x)
				if bottom >= 0 and y < bottom - 6:
					break
		var size := texture.get_size()
		_feet_cache[key] = Vector2(
			((left + right) * 0.5 + 0.5 - size.x * 0.5) if right >= 0 else 0.0,
			(bottom + 1.0 - size.y * 0.5) if bottom >= 0 else size.y * 0.5
		)
	var local: Vector2 = _feet_cache[key]
	return sprite.position + local * sprite.scale


static func find_animated_sprite(node: Node) -> AnimatedSprite2D:
	if node == null:
		return null
	if node is AnimatedSprite2D:
		return node
	var direct := node.get_node_or_null("AnimatedSprite2D")
	if direct is AnimatedSprite2D:
		return direct
	for child in node.get_children():
		var found := find_animated_sprite(child)
		if found:
			return found
	return null


## 角色在畫面上的腳底位置（世界座標）。
static func feet_global(node: Node2D) -> Vector2:
	var sprite := find_animated_sprite(node)
	if sprite == null:
		return node.global_position
	return node.to_global(feet_offset_in_sprite(sprite))


# ------------------------------------------------------------
# 舊水道（清澈）入口：夜談之後，只有接了《渠燈補封》（或已完成）才進得去。夜談之前的既有行為不變。
# ------------------------------------------------------------
static func can_enter_clean_sewer() -> bool:
	if not flag(F_NIGHT_MEETING_DONE):
		return true
	var state := get_side_quest_state()
	return state == SideQuestState.IN_PROGRESS or state == SideQuestState.DONE


# ------------------------------------------------------------
# 《渠燈補封》完成的武學獎勵：書眠個人習得武術《澄心落筆》與內功《清渠共印》
# ------------------------------------------------------------
const QUDENG_REWARD_SKILL_ID := "skill_chengxin_luobi"
const QUDENG_REWARD_INNER_FORCE_ID := "qingqu_gongyin"
## 舊版劇情旗標（相容保留，真正的習得狀態一律以書眠的永久角色資料為準）。
const F_LEGACY_SKILL_CHENGXIN := "shumian_skill_chengxin_luobi_unlocked"
const F_LEGACY_SKILL_QINGQU := "shumian_skill_qingqu_gongyin_unlocked"
## 獎勵發放失敗（任務已完成，但武學沒有真的學會）時設定，方便辨識不一致的狀態。
const F_QUDENG_REWARD_ERROR := "shumian_qudeng_reward_error"
## 劉語塵已在「最後一道符」的劇情裡共鳴了澄心落筆（只由完成事件設定；舊存檔不會自動帶這個旗標）。
const F_QUDENG_LIUYU_RESONANCE_DONE := "shumian_qudeng_liuyu_resonance_done"


## 《渠燈補封》完成時的雙人領悟：書眠親身悟得武術與內功；劉語塵在同一場劇情裡「理解」而共鳴同一門武術（普通的《澄心落筆》，
## 不含清渠共印）。全部走角色個人的學習 API（TeamData.learn_skill / learn_inner_force），不是全域秘笈；已經學會的不重複學、
## 不動其他武學、不碰等級與經驗。
##
## include_liuyu 只有在「完成劇情的當下」才傳 true：劉語塵的共鳴屬於那場領悟劇情，不能提早，也不由讀檔補發自動給（見 repair_qudeng_rewards）。
## 回傳 {"skill_learned_now", "inner_force_learned_now", "skill_known", "inner_force_known", "liuyu_learned_now", "liuyu_known"}。
static func grant_qudeng_rewards(include_liuyu := false) -> Dictionary:
	var result := {"skill_learned_now": false, "inner_force_learned_now": false, "skill_known": false, "inner_force_known": false, "liuyu_learned_now": false, "liuyu_known": false}
	var team_data := _autoload("TeamData")
	if team_data == null:
		push_error("找不到 TeamData，書眠的補符獎勵無法發放。")
		set_flag(F_QUDENG_REWARD_ERROR, true)
		return result
	if not team_data.knows_skill(SHUMIAN_ACTOR_ID, QUDENG_REWARD_SKILL_ID):
		result["skill_learned_now"] = bool(team_data.learn_skill(SHUMIAN_ACTOR_ID, QUDENG_REWARD_SKILL_ID))
	result["skill_known"] = bool(team_data.knows_skill(SHUMIAN_ACTOR_ID, QUDENG_REWARD_SKILL_ID))
	var known_forces: Array = []
	for force in team_data.get_known_inner_forces(SHUMIAN_ACTOR_ID):
		known_forces.append(String((force as Dictionary).get("id", "")))
	if not known_forces.has(QUDENG_REWARD_INNER_FORCE_ID):
		result["inner_force_learned_now"] = bool(team_data.learn_inner_force(SHUMIAN_ACTOR_ID, QUDENG_REWARD_INNER_FORCE_ID))
		known_forces.clear()
		for force in team_data.get_known_inner_forces(SHUMIAN_ACTOR_ID):
			known_forces.append(String((force as Dictionary).get("id", "")))
	result["inner_force_known"] = known_forces.has(QUDENG_REWARD_INNER_FORCE_ID)
	if include_liuyu:
		if not team_data.knows_skill("liuyu", QUDENG_REWARD_SKILL_ID):
			result["liuyu_learned_now"] = bool(team_data.learn_skill("liuyu", QUDENG_REWARD_SKILL_ID))
		result["liuyu_known"] = bool(team_data.knows_skill("liuyu", QUDENG_REWARD_SKILL_ID))

	if result["skill_known"]:
		set_flag(F_LEGACY_SKILL_CHENGXIN, true)
	if result["inner_force_known"]:
		set_flag(F_LEGACY_SKILL_QINGQU, true)
	if include_liuyu and result["liuyu_known"]:
		set_flag(F_QUDENG_LIUYU_RESONANCE_DONE, true)
	var complete: bool = bool(result["skill_known"]) and bool(result["inner_force_known"]) and (bool(result["liuyu_known"]) or not include_liuyu)
	if complete:
		set_flag(F_QUDENG_REWARD_ERROR, false)
	else:
		push_error("補符獎勵沒有完整發放：書眠 skill=%s inner_force=%s、劉語塵 skill=%s" % [str(result["skill_known"]), str(result["inner_force_known"]), str(result["liuyu_known"])])
		set_flag(F_QUDENG_REWARD_ERROR, true)
	return result


## 讀檔後的補發：支線「確實完成」（F_QD_DONE 只會在三處補封都完成時設定）但書眠的永久資料裡缺少獎勵（舊版只寫旗標、沒有真的學會）。
## 條件不成立（支線沒完成、錯過、尚未入隊都不算）不會動任何東西；已經學會的不重複；不碰等級、經驗與其他武學。回傳是否補發了什麼。
## 只補書眠自己的兩項。劉語塵的共鳴屬於「最後一道符」那場劇情，舊存檔沒看過這場，這裡不自動補（見回報的相容方案）。
static func repair_qudeng_rewards() -> bool:
	if not flag(F_QD_DONE):
		return false
	var team_data := _autoload("TeamData")
	if team_data == null or not team_data.character_exists(SHUMIAN_ACTOR_ID):
		return false
	var result := grant_qudeng_rewards()
	return bool(result["skill_learned_now"]) or bool(result["inner_force_learned_now"])


# ------------------------------------------------------------
# 舊水道搜刮道具：真正進背包（InventorySync.add_item_stack）
# ------------------------------------------------------------
## 兩個舊水道場景的搜刮表（和 yuheng_sewer_true.gd / yuheng_sewer_true_room.gd 的 LOOT_TABLE 一致；test_qingqu_gongyin 會檢查兩邊沒有走樣）。
## 這裡只用在舊存檔補發：領取旗標 = shumian_qd_loot_<loot_id>_taken。
const SEWER_LOOT := {
	"loot_herb_basket": {"item_id": "herb", "amount": 2},
	"loot_qi_box": {"item_id": "elixir_qi", "amount": 1},
	"loot_haste_scroll": {"item_id": "haste_talisman", "amount": 1},
	"loot_old_herb_pouch": {"item_id": "mat_herb_pouch", "amount": 1},
	"loot_calm_pill": {"item_id": "med_calm_pill", "amount": 1},
}
## 舊版 _add_item 找不到背包 API 時留下的「假領取」記號（只有那兩支腳本會寫，新流程不再寫）。
const LEGACY_FAKE_RECEIVED_PREFIX := "received_item_"


## 把道具真正放進持久化背包。回傳是否真的放進去了（背包數量實際增加 amount）；失敗時不改任何狀態。
## InventorySync.add_item_stack 沒有回傳值，所以用「前後數量」確認，而不是假設成功。
static func grant_item(item_id: String, amount: int) -> bool:
	if item_id == "" or amount <= 0:
		return false
	var item_db: GDScript = load("res://scripts/db/ItemDB.gd")
	if item_db == null or (item_db.ITEM_DEFS as Dictionary).is_empty() or not (item_db.ITEM_DEFS as Dictionary).has(item_id):
		push_error("搜刮道具的 Item ID 不在 ItemDB：%s" % item_id)
		return false
	var inventory := _autoload("InventorySync")
	if inventory == null or not inventory.has_method("add_item_stack"):
		push_error("找不到 InventorySync.add_item_stack，道具無法放進背包：%s" % item_id)
		return false
	var before: int = int(inventory.get_item_count(item_id))
	inventory.add_item_stack(item_id, amount, false)
	return int(inventory.get_item_count(item_id)) == before + amount


## 舊存檔補發：舊版搜刮把「已領取」旗標與假領取記號都寫了，背包卻沒有東西。
## 條件很窄：該搜刮點的領取旗標為真，而且那個道具的假領取記號也為真（只有舊的假發放會留下這個記號）。
## 補發成功才清掉「那一個」道具的假記號，所以重複呼叫不會重複補；背包目前數量是零還是被用掉都不影響判斷。回傳補發的件數。
static func repair_sewer_loot_items() -> int:
	var repaired := 0
	for loot_id in SEWER_LOOT.keys():
		var entry: Dictionary = SEWER_LOOT[loot_id]
		var item_id := String(entry["item_id"])
		var fake_marker := LEGACY_FAKE_RECEIVED_PREFIX + item_id
		if not (flag("shumian_qd_loot_%s_taken" % String(loot_id)) and flag(fake_marker)):
			continue
		if grant_item(item_id, int(entry["amount"])):
			set_flag(fake_marker, false)
			repaired += 1
	return repaired
