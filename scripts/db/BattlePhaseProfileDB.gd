extends RefCounted

const EnemyDBScript = preload("res://scripts/db/EnemyDB.gd")

const MOLIN_PHASE2_ID := "molin_yanjiang_phase2"
const MOLIN_PHASE2_MECHANIC_ID := "molin_yanjiang_phase2_shield_cycle"
const ZUOYIN_STALACTITE_GUEST_ID := "zuoyin_stalactite_guest"
const StatusDisplay = preload("res://scripts/db/StatusDisplayDB.gd")
const YUMEI_ENTANGLEMENT_STATUS_ID := "yumei_entanglement"
const YUHENG_SHUMIAN_STORY_PROFILE_ID := "yuheng_shumian_lv6"

const ZUOYIN_STALACTITE_GUEST_PROFILE := {
	"id": ZUOYIN_STALACTITE_GUEST_ID,
	"display_name": "左飲",
	"portrait_path": "res://assets/sprites/NPC/Yuheng/Zuo_Yin_battle.png",
	"speed": 14,
	"controllable": false,
	"normal_target": false,
	"uses_playable_actor": false,
	"actions": [
		{
			"id": "drink_to_qi",
			"display_name": "飲酒化氣",
			"hp_damage": 0,
			"variants": [[
				"左飲一手持刀，另一手熟稔地將肩後的葫蘆送至唇邊。",
				"他仰首豪飲一口，目光卻始終未曾離開墨鱗魘將。",
			]],
		},
		{
			"id": "wine_edge_charge",
			"display_name": "酒意催鋒",
			"hp_damage": 0,
			"variants": [
				[
					"左飲面上漸泛紅光，卻不見半分醉態。",
					"酒意沉入丹田，化作真氣奔行周身，連握刀的手都隱隱透出一股迫人的勁勢。",
				],
				[
					"酒意漸湧，左飲面上泛起一層紅光。",
					"那並非醉後的酡紅，而是氣沉丹田、真氣催行周身所泛起的血色。",
				],
			],
		},
		{
			"id": "yanxing_wind_breaking_slash",
			"display_name": "燕行破風斬",
			"hp_damage": 0,
			"removes_status": YUMEI_ENTANGLEMENT_STATUS_ID,
			"variants": [
				[
					"方才還穩立原地的左飲，霎時間已如燕般掠入半空。",
					"眾人甚至未及看清他何時出刀，一道銀白刀氣裹著淡淡紫芒，已結結實實斬在墨鱗魘將身上。",
					"直到刀氣掠過，原地才緩緩散去一道方才揮刀的殘影。",
				],
				[
					"左飲身形一晃，銀白刀光已先一步劃破濁氣。",
					"待殘影消散，墨鱗魘將周身的魘鱗護體也隨之一裂。",
				],
			],
			"shield_break_lines": [
				"紫黑語魅驟然撕裂，原本密不透風的護體濁氣被這一刀硬生生斬出缺口！",
			],
			"shield_break_system_log": "墨鱗魘將的「%s」被破除了！" % StatusDisplay.GUARD_BARRIER_NAME,
		},
	],
}

const MOLIN_PHASE2_MECHANIC := {
	"id": MOLIN_PHASE2_MECHANIC_ID,
	"cycle_length": 3,
	"shield_round": 3,
	"shield_status_id": YUMEI_ENTANGLEMENT_STATUS_ID,
	"shield_round_lines": [
		"四周紫黑色濁氣再度向墨鱗魘將身上聚攏。",
	],
	"shield_applied_system_log": "墨鱗魘將獲得了「%s」！" % StatusDisplay.GUARD_BARRIER_NAME,
}


static func make_molin_phase2_context(player_party: Array, overrides: Dictionary = {}) -> Dictionary:
	var enemy := EnemyDBScript.make_enemy(MOLIN_PHASE2_ID)
	if not enemy.is_empty():
		enemy["ui_index"] = 0
	var context := {
		"battle_id": "boss_yuheng_molin_yanjiang_phase2",
		"battle_tag": "boss_yuheng_molin_yanjiang_phase2",
		"battle_bgm_override_path": "res://assets/BGM/battle_boss_1.ogg",
		"player_party": player_party.duplicate(),
		"enemy_party": [enemy] if not enemy.is_empty() else [],
		"party_actor_ids_override": ["liuyu", "shumian"],
		"use_story_battle_profile": true,
		"story_battle_profile_id": YUHENG_SHUMIAN_STORY_PROFILE_ID,
		"scripted_guest": ZUOYIN_STALACTITE_GUEST_PROFILE.duplicate(true),
		"encounter_mechanic": MOLIN_PHASE2_MECHANIC.duplicate(true),
		"inherit_player_resources": ["hp", "mp"],
		"use_exact_enemy_rewards": true,
		"reward_messages": [
			"獲得 500 文",
			"獲得「魘將魚骨槍」",
			"取得武學秘笈《破浪槍譜》",
			"取得內功秘笈《沉潮訣》",
		],
		"fade_to_black_after_victory": true,
		"ruleset": {"id": "default"},
		"regen_policy": {"id": "round_end_mp_regen_default"},
	}
	for key in overrides.keys():
		context[key] = overrides[key]
	return context
