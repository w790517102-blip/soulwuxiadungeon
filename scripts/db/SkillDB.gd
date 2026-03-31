extends Node

const SKILLS := {
	"skill_lianjuejian": {
		"id": "skill_lianjuejian",
		"name": "連訣劍",
		"category": "單體攻擊",
		"description": "迅速揮劍三次，連擊破敵。",
		"weapon_type": "劍",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"strike_count": 3,
		"effects": [{"type": "damage", "power": 1.1}],
		"stat_scaling": {"str": 0.6, "agi": 0.3, "int": 0.1},
		"available": {"mode": "all"},
	},
	"skill_badaozhan": {
		"id": "skill_badaozhan",
		"name": "霸刀斬",
		"category": "單體攻擊",
		"description": "霸氣一斬，重擊敵人。",
		"weapon_type": "刀",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"crit_rate_bonus": 0.10,
		"effects": [{"type": "damage", "power": 1.0}],
		"stat_scaling": {"str": 0.8, "agi": 0.2},
		"available": {"mode": "all"},
	},
	"skill_duanshuizhan": {
		"id": "skill_duanshuizhan",
		"name": "斷水斬",
		"category": "單體攻擊",
		"description": "刀勢沉落如截流斷水，一斬而下，直取敵方中門。",
		"weapon_type": "刀",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 1.2}],
		"stat_scaling": {"str": 0.85, "agi": 0.15},
		"available": {"mode": "all"},
	},
	"skill_diquejian": {
		"id": "skill_diquejian",
		"name": "地缺劍",
		"category": "全體攻擊",
		"description": "以沉勁直劈敵方要害，作為絕技分支的基礎劍式。",
		"weapon_type": "劍",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "enemy_all",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 1.2}],
		"stat_scaling": {"str": 0.6, "agi": 0.3, "con": 0.1},
		"risk_upgrade": {
			"inner_force_id": "tiancan_jue",
			"name": "天殘．地缺劍",
			"target_scope": "enemy_all",
			"target_side": "enemy",
			"effects": [{"type": "damage", "power": 3.0}],
			"stat_scaling": {"str": 0.9, "con": 0.8},
			"self_hp_cost_current_pct": 0.5,
			"post_cast_self_effects": [
				{"type": "break_def", "amount": 15, "turns": 2},
				{"type": "blind", "amount": 10, "turns": 2}
			],
			"self_debuff_state_name": "殘脈",
			"on_kill_heal_max_hp_pct": 0.15,
			"on_multi_kill_threshold": 2,
			"on_multi_kill_self_effects": [
				{"type": "atk_up", "amount": 15, "turns": 2}
			]
		},
		"available": {"mode": "include", "actor_ids": ["liuyu"]},
	},
	"skill_mujian_saoye": {
		"id": "skill_mujian_saoye",
		"name": "木劍掃葉",
		"category": "單體攻擊",
		"description": "以木劍練武時，悟得之招式。",
		"weapon_type": "劍",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 0.8}],
		"stat_scaling": {"str": 0.6, "agi": 0.3, "int": 0.1},
		"available": {"mode": "all"},
	},
	"skill_qiliaozhang": {
		"id": "skill_qiliaozhang",
		"name": "氣療掌",
		"category": "單體恢復",
		"description": "掌勁回流經脈，穩住傷勢。",
		"weapon_type": "掌",
		"menu_usable": true,
		"mp_cost": 5,
		"target_scope": "single",
		"target_side": "ally",
		"effects": [{"type": "heal_hp", "amount": 40}],
		"available": {"mode": "all"},
	},
	"skill_xianglong18": {
		"id": "skill_xianglong18",
		"name": "翔龍十八掌",
		"category": "全體攻擊",
		"description": "真氣自丹田騰起如龍，一掌落下，氣浪層層外推。",
		"weapon_type": "掌",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "enemy_all",
		"target_side": "enemy",
		"require_free_hand": true,
		"effects": [{"type": "damage", "power": 1.0}],
		"stat_scaling": {"int": 0.4, "con": 0.2, "str": 0.1},
		"available": {"mode": "include", "actor_ids": ["liuyu"]},
	},
	"skill_bisaoyanxia": {
		"id": "skill_bisaoyanxia",
		"name": "筆掃煙霞",
		"category": "全體攻擊",
		"description": "以筆破風，掃出詩意煙霞，傷敵於無形。",
		"weapon_type": "筆",
		"menu_usable": false,
		"mp_cost": 10,
		"target_scope": "enemy_all",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 1.1}],
		"stat_scaling": {"int": 0.6, "luck": 0.1},
		"available": {"mode": "all"},
	},
	"skill_luobichengshi": {
		"id": "skill_luobichengshi",
		"name": "落筆成詩",
		"category": "單體攻擊",
		"description": "一筆揮就，一詩成陣，敵人心神動搖。",
		"weapon_type": "筆",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 1.3}],
		"stat_scaling": {"int": 0.8, "luck": 0.2},
		"available": {"mode": "all"},
	},
	"skill_zhengxinquan": {
		"id": "skill_zhengxinquan",
		"name": "正心拳",
		"category": "單體攻擊",
		"description": "扎穩馬步，屏除雜念，用堅定的信念揮出一拳。",
		"weapon_type": "拳",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 1.3}],
		"stat_scaling": {"str": 0.6, "con": 0.2, "agi": 0.2},
		"available": {"mode": "all"},
	},
	"skill_tianjingquan": {
		"id": "skill_tianjingquan",
		"name": "天驚拳",
		"category": "單體攻擊",
		"description": "拳勢驟起如雷，連續轟擊單一目標。",
		"weapon_type": "拳",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"require_free_hand": true,
		"strike_count_min": 2,
		"strike_count_max": 4,
		"effects": [{"type": "damage", "power": 0.5}],
		"stat_scaling": {"str": 0.6, "con": 0.2, "agi": 0.2},
		"legendary_chain": {
			"inner_force_id": "shipo_xinfa",
			"exclusive_name": "石破天驚拳",
			"ultimate_name": "真．石破天驚拳"
		},
		"available": {"mode": "include", "actor_ids": ["liuyu"]},
	},
	"skill_buff_speed_test": {
		"id": "skill_buff_speed_test",
		"name": "提氣輕身",
		"category": "單體增益",
		"description": "運氣提身，腳下如風。",
		"weapon_type": "掌",
		"menu_usable": false,
		"mp_cost": 5,
		"target_scope": "single",
		"target_side": "ally",
		"positive_buff": true,
		"buff_theme": "mobility",
		"effects": [{"type": "buff_speed", "amount": 3, "turns": 3}],
		"available": {"mode": "all"},
	},
	"skill_qihui_talisman": {
		"id": "skill_qihui_talisman",
		"name": "啟慧符",
		"category": "單體增益",
		"description": "書意化符，提振靈光，令指定隊友智慧暫時提升。",
		"weapon_type": "筆",
		"menu_usable": false,
		"mp_cost": 7,
		"target_scope": "single",
		"target_side": "ally",
		"positive_buff": true,
		"buff_theme": "focus",
		"effects": [{"type": "stat_buff", "stat": "int", "amount": 10, "turns": 3}],
		"available": {"mode": "include", "actor_ids": ["shumian"]},
	},
	"skill_jufu_talisman": {
		"id": "skill_jufu_talisman",
		"name": "聚福符",
		"category": "單體增益",
		"description": "符意輕落，福勢凝聚，令指定隊友幸運暫時提升。",
		"weapon_type": "筆",
		"menu_usable": false,
		"mp_cost": 7,
		"target_scope": "single",
		"target_side": "ally",
		"positive_buff": true,
		"buff_theme": "fortune",
		"effects": [{"type": "stat_buff", "stat": "luck", "amount": 10, "turns": 3}],
		"available": {"mode": "include", "actor_ids": ["shumian"]},
	},
	"skill_debuff_speed_test": {
		"id": "skill_debuff_speed_test",
		"name": "凝滯封脈",
		"category": "單體減益",
		"description": "封住敵人經脈，使其身形遲鈍。",
		"weapon_type": "掌",
		"menu_usable": false,
		"mp_cost": 5,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "slow", "amount": 3, "turns": 3}],
		"available": {"mode": "all"},
	},
	"skill_force_element_test": {
		"id": "skill_force_element_test",
		"name": "轉性訣",
		"category": "屬性變化",
		"description": "以真氣扭轉敵人體內屬性流向。",
		"weapon_type": "掌",
		"menu_usable": false,
		"mp_cost": 8,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "force_element", "element": "柔", "turns": 2}],
		"available": {"mode": "all"},
	},
	"skill_smoky_ink_blind": {
		"id": "skill_smoky_ink_blind",
		"name": "潑墨迷眼",
		"category": "單體減益",
		"description": "墨氣散開如霧，擾亂敵人視線，使命中暫時下降。",
		"weapon_type": "筆",
		"menu_usable": false,
		"mp_cost": 6,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "blind", "amount": 15, "turns": 3}],
		"available": {"mode": "include", "actor_ids": ["shumian"]},
	},
	"skill_binding_shadow": {
		"id": "skill_binding_shadow",
		"name": "牽絲縛影",
		"category": "單體減益",
		"description": "勁氣如絲纏住下盤，使對手閃避暫時下降。",
		"weapon_type": "琴",
		"menu_usable": false,
		"mp_cost": 6,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "root", "amount": 20, "turns": 2}],
		"available": {"mode": "include", "actor_ids": ["lieshao"]},
	},
	"skill_hawkeye_focus": {
		"id": "skill_hawkeye_focus",
		"name": "鷹眼訣",
		"category": "自身增益",
		"description": "提氣凝神，將目力與心念收束於一點，使自身洞察更銳。",
		"weapon_type": "通用",
		"menu_usable": false,
		"mp_cost": 6,
		"target_scope": "self",
		"target_side": "self",
		"positive_buff": true,
		"buff_theme": "focus",
		"buff_narration": {
			"self": "提氣凝神之後，目力與心念像被收束成一線，眼前事物也跟著清明起來。"
		},
		"effects": [{"type": "focus", "amount": 15, "turns": 3}],
		"available": {"mode": "all"},
	},
	"skill_inkveil_swiftroute": {
		"id": "skill_inkveil_swiftroute",
		"name": "墨影輕身",
		"category": "全體增益",
		"description": "墨意輕揚，帶得全隊身法更靈，閃避暫時上升。",
		"weapon_type": "筆",
		"menu_usable": false,
		"mp_cost": 8,
		"target_scope": "ally_all",
		"target_side": "ally",
		"positive_buff": true,
		"buff_theme": "mobility",
		"buff_narration": {
			"ally_all": "墨意一轉，如風般輕輕拂過眾人身側，原本沉重的步伐也隨之輕了起來。"
		},
		"effects": [{"type": "evasion_boost", "amount": 10, "turns": 3}],
		"available": {"mode": "include", "actor_ids": ["shumian"]},
	},
	"skill_qin_resonant_focus": {
		"id": "skill_qin_resonant_focus",
		"name": "定弦凝神",
		"category": "單體增益",
		"description": "弦音穩心，替隊友收束雜念，使命中暫時上升。",
		"weapon_type": "琴",
		"menu_usable": false,
		"mp_cost": 6,
		"target_scope": "single",
		"target_side": "ally",
		"positive_buff": true,
		"buff_theme": "focus",
		"buff_narration": {
			"ally_single": "弦音一落，清勁便順勢覆上 {target} 周身，令其心神與目力都收束得更穩。"
		},
		"effects": [{"type": "focus", "amount": 15, "turns": 3}],
		"available": {"mode": "include", "actor_ids": ["lieshao"]},
	},
	"skill_luanxian_banying": {
		"id": "skill_luanxian_banying",
		"name": "亂弦絆影",
		"category": "單體減益",
		"description": "弦音亂拍牽制身法，令敵方步調失序、敏捷暫時下降。",
		"weapon_type": "琴",
		"menu_usable": false,
		"mp_cost": 8,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "stat_debuff", "stat": "agi", "amount": 10, "turns": 3}],
		"available": {"mode": "include", "actor_ids": ["lieshao"]},
	},
	"skill_mobishuxin": {
		"id": "skill_mobishuxin",
		"name": "墨筆舒心",
		"category": "全體恢復",
		"description": "筆墨舒心，氣息回流，眾人心神微定。",
		"weapon_type": "筆",
		"menu_usable": true,
		"mp_cost": 0,
		"target_scope": "ally_all",
		"target_side": "ally",
		"effects": [{"type": "heal_hp", "amount": 18}],
		"available": {"mode": "all"},
	},
	"skill_liedaoposhi": {
		"id": "skill_liedaoposhi",
		"name": "烈刀破勢",
		"category": "單體攻擊",
		"description": "猛然橫刀劈斷氣勢，強行突破敵陣。",
		"weapon_type": "刀",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 1.2}],
		"stat_scaling": {"str": 0.8, "agi": 0.2},
		"available": {"mode": "all"},
	},
	"skill_luanyinsuiqin": {
		"id": "skill_luanyinsuiqin",
		"name": "亂音碎琴",
		"category": "單體攻擊",
		"description": "激昂琴音化為利刃，震懾敵人心魄。",
		"weapon_type": "琴",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 1.1}],
		"stat_scaling": {"agi": 0.6, "int": 0.3, "luck": 0.1},
		"available": {"mode": "all"},
	},
	"skill_huagu_mianzhang": {
		"id": "skill_huagu_mianzhang",
		"name": "化骨綿掌",
		"category": "單體攻擊",
		"description": "掌勁入骨，綿裡藏勁，並強行將敵之屬性轉為柔。",
		"weapon_type": "掌",
		"menu_usable": false,
		"mp_cost": 12,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [
			{"type": "damage", "power": 0.95},
			{"type": "force_element", "element": "柔", "turns": 3}
		],
		"stat_scaling": {"int": 0.5, "con": 0.3, "str": 0.2},
		"available": {"mode": "include", "actor_ids": ["lieshao", "honghuiyin"]},
	},
	"skill_huanbu_zhang": {
		"id": "skill_huanbu_zhang",
		"name": "緩步掌",
		"category": "單體攻擊",
		"description": "掌風黏滯如泥，令敵身法遲緩。",
		"weapon_type": "掌",
		"menu_usable": false,
		"mp_cost": 10,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [
			{"type": "damage", "power": 0.90},
			{"type": "slow", "amount": 5, "turns": 2}
		],
		"stat_scaling": {"int": 0.5, "con": 0.3, "str": 0.2},
		"available": {"mode": "all"},
	},
	"skill_liumai_shenjian": {
		"id": "skill_liumai_shenjian",
		"name": "六脈神劍",
		"category": "單體攻擊",
		"description": "劍氣化脈，疾如驟雨，出手更快。",
		"weapon_type": "劍",
		"menu_usable": false,
		"mp_cost": 18,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [
			{"type": "damage", "power": 1.15},
			{"type": "buff_speed", "amount": 6, "turns": 2, "target": "self"}
		],
		"stat_scaling": {"str": 0.6, "agi": 0.3, "int": 0.1},
		"available": {"mode": "all"},
	},
	"skill_bagua_gunfa": {
		"id": "skill_bagua_gunfa",
		"name": "八卦棍法",
		"category": "單體攻擊",
		"description": "棍走八卦，纏步鎖身，令敵動作遲滯。",
		"weapon_type": "棍",
		"menu_usable": false,
		"mp_cost": 12,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [
			{"type": "damage", "power": 1.00},
			{"type": "slow", "amount": 4, "turns": 2}
		],
		"stat_scaling": {"str": 0.7, "agi": 0.3},
		"available": {"mode": "all"},
	},
	"skill_enemy_zhishui_yinzhang": {
		"id": "skill_enemy_zhishui_yinzhang",
		"name": "滯水陰掌",
		"category": "單體攻擊",
		"description": "語魅以濕掌勾魂，令敵意識遲滯。",
		"weapon_type": "掌",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 1.1}],
		"available": {"mode": "include", "actor_ids": ["enemy1"]},
	},
	"skill_enemy_panshi_gangquan": {
		"id": "skill_enemy_panshi_gangquan",
		"name": "磐石剛拳",
		"category": "單體攻擊",
		"description": "語魅以磐石般的硬拳痛擊對手。",
		"weapon_type": "拳",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 1.1}],
		"stat_scaling": {"str": 0.6, "con": 0.2, "agi": 0.2},
		"available": {"mode": "include", "actor_ids": ["enemy2"]},
	},
	"skill_enemy_sparring_palm": {
		"id": "skill_enemy_sparring_palm",
		"name": "掌試",
		"category": "單體攻擊",
		"description": "點到為止的試招，不取性命。",
		"weapon_type": "掌",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 0.9}],
		"available": {"mode": "all"},
	},
	"skill_enemy_stun_palm": {
		"id": "skill_enemy_stun_palm",
		"name": "點穴·驚雷",
		"category": "單體控制",
		"description": "一指落穴，使對手氣脈一滯，下一回合無法行動。",
		"weapon_type": "掌",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 0.75}, {"type": "stun", "turns": 1}],
		"available": {"mode": "all"},
	},
	"skill_enemy_poison_fang": {
		"id": "skill_enemy_poison_fang",
		"name": "青絲毒引",
		"category": "單體減益",
		"description": "暗勁入體，毒性潛行；回合末中毒發作，持續扣血。",
		"weapon_type": "掌",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 0.78}, {"type": "poison", "turns": 3}],
		"available": {"mode": "all"},
	},
	"skill_enemy_confuse_shout": {
		"id": "skill_enemy_confuse_shout",
		"name": "醉語亂心",
		"category": "單體控制",
		"description": "以言亂心，使對手神智搖晃；單體行動時可能誤傷敵我。",
		"weapon_type": "拳",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 0.72}, {"type": "confuse", "turns": 2}],
		"available": {"mode": "all"},
	},
	"skill_enemy_weaken_strike": {
		"id": "skill_enemy_weaken_strike",
		"name": "卸勁·斷力",
		"category": "單體減益",
		"description": "卸去發力根基，使對手攻勢軟弱，攻擊力暫時下降。",
		"weapon_type": "拳",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 0.82}, {"type": "weaken", "amount": 10, "turns": 3}],
		"available": {"mode": "all"},
	},
	"skill_enemy_break_def_strike": {
		"id": "skill_enemy_break_def_strike",
		"name": "破綻·裂甲",
		"category": "單體減益",
		"description": "逼出破綻，護身氣勢散亂，防禦力暫時下降。",
		"weapon_type": "拳",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 0.82}, {"type": "break_def", "amount": 10, "turns": 3}],
		"available": {"mode": "all"},
	},
	"skill_enemy_weak_curse": {
		"id": "skill_enemy_weak_curse",
		"name": "耗元·虛損",
		"category": "單體減益",
		"description": "內息受擾，元氣浮動，最大生命暫時降低。",
		"weapon_type": "掌",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 0.70}, {"type": "weak", "amount": 30, "turns": 3}],
		"available": {"mode": "all"},
	},
	"skill_enemy_seal_acupoint": {
		"id": "skill_enemy_seal_acupoint",
		"name": "封穴·鎖脈",
		"category": "單體減益",
		"description": "封住氣脈，使最大內力暫時降低。",
		"weapon_type": "指",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 0.70}, {"type": "seal_mp", "amount": 15, "turns": 3}],
		"available": {"mode": "all"},
	},
	"skill_enemy_blind_sand": {
		"id": "skill_enemy_blind_sand",
		"name": "飛砂·迷目",
		"category": "單體減益",
		"description": "砂影撩眼，使視線紊亂，命中暫時下降。",
		"weapon_type": "掌",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 0.76}, {"type": "blind", "amount": 15, "turns": 3}],
		"available": {"mode": "all"},
	},
	"skill_enemy_root_bind": {
		"id": "skill_enemy_root_bind",
		"name": "鎖步·困影",
		"category": "單體減益",
		"description": "步法受制，身形難轉，閃避暫時下降。",
		"weapon_type": "掌",
		"menu_usable": false,
		"mp_cost": 0,
		"target_scope": "single",
		"target_side": "enemy",
		"effects": [{"type": "damage", "power": 0.76}, {"type": "root", "amount": 20, "turns": 2}],
		"available": {"mode": "all"},
	},
}

const LEGACY_NAME_TO_ID := {
	"連訣劍": "skill_lianjuejian",
	"霸刀斬": "skill_badaozhan",
	"斷水斬": "skill_duanshuizhan",
	"地缺劍": "skill_diquejian",
	"木劍掃葉": "skill_mujian_saoye",
	"氣療掌": "skill_qiliaozhang",
	"翔龍十八掌": "skill_xianglong18",
	"筆掃煙霞": "skill_bisaoyanxia",
	"落筆成詩": "skill_luobichengshi",
	"正心拳": "skill_zhengxinquan",
	"天驚拳": "skill_tianjingquan",
	"提氣輕身": "skill_buff_speed_test",
	"啟慧符": "skill_qihui_talisman",
	"聚福符": "skill_jufu_talisman",
	"凝滯封脈": "skill_debuff_speed_test",
	"轉性訣": "skill_force_element_test",
	"潑墨迷眼": "skill_smoky_ink_blind",
	"牽絲縛影": "skill_binding_shadow",
	"鷹眼訣": "skill_hawkeye_focus",
	"墨影輕身": "skill_inkveil_swiftroute",
	"定弦凝神": "skill_qin_resonant_focus",
	"亂弦絆影": "skill_luanxian_banying",
	"墨筆舒心": "skill_mobishuxin",
	"烈刀破勢": "skill_liedaoposhi",
	"亂音碎琴": "skill_luanyinsuiqin",
	"化骨綿掌": "skill_huagu_mianzhang",
	"緩步掌": "skill_huanbu_zhang",
	"六脈神劍": "skill_liumai_shenjian",
	"八卦棍法": "skill_bagua_gunfa",
	"滯水陰掌": "skill_enemy_zhishui_yinzhang",
	"磐石剛拳": "skill_enemy_panshi_gangquan",
	"震脈封手": "skill_enemy_stun_palm",
	"毒牙勁": "skill_enemy_poison_fang",
	"亂神喝": "skill_enemy_confuse_shout",
	"卸力擊": "skill_enemy_weaken_strike",
	"破守拳": "skill_enemy_break_def_strike",
	"虛耗咒": "skill_enemy_weak_curse",
	"封穴指": "skill_enemy_seal_acupoint",
	"迷砂掩目": "skill_enemy_blind_sand",
	"纏地勁": "skill_enemy_root_bind",
	"掌試": "skill_enemy_sparring_palm",
}

const DEFAULT_SKILL_IDS_BY_ACTOR := {
	"liuyu": ["skill_lianjuejian", "skill_badaozhan", "skill_duanshuizhan", "skill_diquejian", "skill_mujian_saoye", "skill_qiliaozhang", "skill_xianglong18", "skill_tianjingquan", "skill_hawkeye_focus"],
	"shumian": ["skill_bisaoyanxia", "skill_luobichengshi", "skill_zhengxinquan", "skill_buff_speed_test", "skill_qihui_talisman", "skill_jufu_talisman", "skill_debuff_speed_test", "skill_force_element_test", "skill_smoky_ink_blind", "skill_hawkeye_focus", "skill_mobishuxin", "skill_inkveil_swiftroute"],
	"lieshao": ["skill_liedaoposhi", "skill_luanyinsuiqin", "skill_huagu_mianzhang", "skill_huanbu_zhang", "skill_liumai_shenjian", "skill_bagua_gunfa", "skill_binding_shadow", "skill_hawkeye_focus", "skill_qin_resonant_focus", "skill_luanxian_banying"],
	"enemy1": ["skill_enemy_zhishui_yinzhang"],
	"enemy2": ["skill_enemy_panshi_gangquan"],
}

func get_skill(skill_id: String) -> Dictionary:
	if not SKILLS.has(skill_id):
		return {}
	return normalize_skill_def((SKILLS[skill_id] as Dictionary).duplicate(true))

func get_all_skills() -> Array:
	var out: Array = []
	for skill_id in SKILLS.keys():
		out.append(get_skill(String(skill_id)))
	return out

func get_default_skill_ids(actor_id: String) -> Array:
	if not DEFAULT_SKILL_IDS_BY_ACTOR.has(actor_id):
		return []
	return (DEFAULT_SKILL_IDS_BY_ACTOR[actor_id] as Array).duplicate()

func get_skills_for_actor(actor_id: String, actor = null, known_skill_ids: Array = []) -> Array:
	var ids: Array = known_skill_ids if not known_skill_ids.is_empty() else get_default_skill_ids(actor_id)
	var out: Array = []
	for raw_id in ids:
		var skill_id := coerce_skill_id(raw_id)
		if skill_id == "":
			continue
		if not is_available_for_actor(skill_id, actor_id):
			continue
		var skill := get_skill(skill_id)
		if skill.is_empty():
			continue
		if actor != null and not is_weapon_compatible(skill, actor):
			continue
		out.append(skill)
	return out

func is_available_for_actor(skill_id: String, actor_id: String) -> bool:
	var skill := get_skill(skill_id)
	if skill.is_empty():
		return false
	var available = skill.get("available", {"mode": "all"})
	if typeof(available) != TYPE_DICTIONARY:
		return true
	var mode := String((available as Dictionary).get("mode", "all"))
	if mode == "all":
		return true
	if mode == "include":
		var actor_ids = (available as Dictionary).get("actor_ids", [])
		return typeof(actor_ids) == TYPE_ARRAY and (actor_ids as Array).has(actor_id)
	return true

func is_weapon_compatible(skill: Dictionary, actor) -> bool:
	if skill.is_empty():
		return false
	var weapon_type := String(skill.get("weapon_type", ""))
	if weapon_type == "" or weapon_type == "通用":
		# 通用技能不做武器限制，也不吃 require_free_hand
		return true

	var w1 := String(_actor_get(actor, "weapon_1", ""))
	var w2 := String(_actor_get(actor, "weapon_2", ""))
	var real_weapon_count := 0
	if w1 != "" and w1 != "拳" and w1 != "掌":
		real_weapon_count += 1
	if w2 != "" and w2 != "拳" and w2 != "掌":
		real_weapon_count += 1
	var has_free_hand := real_weapon_count < 2

	var require_free_hand := bool(skill.get("require_free_hand", false))
	if require_free_hand and not has_free_hand:
		return false

	if weapon_type == "拳" or weapon_type == "掌":
		# 拳/掌技能預設不做「必須裝拳掌武器」檢查
		return true
	if weapon_type == "空手":
		return real_weapon_count == 0

	# 其他武器技能必須裝備對應武器
	return w1 == weapon_type or w2 == weapon_type

func coerce_skill_id(value) -> String:
	if typeof(value) == TYPE_STRING:
		var as_id := String(value)
		if SKILLS.has(as_id):
			return as_id
		if LEGACY_NAME_TO_ID.has(as_id):
			return String(LEGACY_NAME_TO_ID[as_id])
		push_warning("[SkillDB] Unknown skill string: %s" % as_id)
		return ""

	if typeof(value) == TYPE_DICTIONARY:
		var dict := value as Dictionary
		var id := String(dict.get("id", ""))
		if id != "" and SKILLS.has(id):
			return id
		var name := String(dict.get("name", ""))
		if name != "" and LEGACY_NAME_TO_ID.has(name):
			return String(LEGACY_NAME_TO_ID[name])
		push_warning("[SkillDB] Cannot coerce skill dictionary: %s" % [dict])
		return ""

	push_warning("[SkillDB] Unsupported skill id value type: %s" % typeof(value))
	return ""

func normalize_skill_def(skill: Dictionary) -> Dictionary:
	if skill.is_empty():
		return {}
	if not skill.has("kind"):
		skill["kind"] = "武學"
	if not skill.has("ui_category"):
		skill["ui_category"] = String(skill.get("category", ""))
	if not skill.has("category"):
		skill["category"] = String(skill.get("ui_category", ""))
	if not skill.has("description"):
		skill["description"] = String(skill.get("desc", ""))
	if not skill.has("desc"):
		skill["desc"] = String(skill.get("description", ""))
	if not skill.has("menu_usable"):
		skill["menu_usable"] = false
	if not skill.has("mp_cost"):
		skill["mp_cost"] = 0
	if not skill.has("target_scope"):
		skill["target_scope"] = "single"
	if not skill.has("target_side"):
		skill["target_side"] = "enemy"
	if not skill.has("effects"):
		skill["effects"] = _legacy_effect_to_effects(skill)
	if not skill.has("power"):
		var effects = skill.get("effects", [])
		if typeof(effects) == TYPE_ARRAY:
			for effect in effects:
				if typeof(effect) != TYPE_DICTIONARY:
					continue
				if String((effect as Dictionary).get("type", "")) == "damage":
					skill["power"] = float((effect as Dictionary).get("power", 1.0))
					break
	if not skill.has("available"):
		skill["available"] = {"mode": "all"}

	if skill.has("effect") and skill.has("heal_amount"):
		var effect := String(skill.get("effect", ""))
		if effect == "heal_hp":
			skill["effects"] = [{"type": "heal_hp", "amount": int(skill.get("heal_amount", 0))}]

	return skill

func get_inner_force_linkage_entries(skill: Dictionary, actor: Dictionary = {}, inner_force: Dictionary = {}) -> Array:
	var skill_id := String(skill.get("id", ""))
	var current_force_id := String(inner_force.get("id", ""))
	var out: Array = []
	match skill_id:
		"skill_lianjuejian":
			out.append({
				"kind": "武器加成",
				"text_long": "流塵訣下，劍系招式命中 +10、傷害 +10%。",
				"text_short": "流塵訣：劍招命中+10、傷害+10%。",
				"met": current_force_id == "liuchen_jue",
			})
			out.append({
				"kind": "專屬搭配",
				"text_long": "流塵訣下可進化為「流塵連訣劍」。",
				"text_short": "專屬：可進化為流塵連訣劍。",
				"met": current_force_id == "liuchen_jue",
			})
		"skill_duanshuizhan":
			out.append({
				"kind": "武器加成",
				"text_long": "伏潮訣下，刀系招式傷害 +12%；對已破防敵人出刀時，有機率追加暈眩。",
				"text_short": "伏潮訣：刀傷+12%，打破防目標可追暈。",
				"met": current_force_id == "fuchao_jue",
			})
			out.append({
				"kind": "專屬搭配",
				"text_long": "伏潮訣下可進化為「伏潮斷水斬」，命中附加破防 2 回合。",
				"text_short": "專屬：伏潮斷水斬，命中附加破防2回合。",
				"met": current_force_id == "fuchao_jue",
			})
		"skill_tianjingquan":
			out.append({
				"kind": "專屬搭配",
				"text_long": "石破心法下可進化為「石破天驚拳」，全場共享 2~4 次攻擊。",
				"text_short": "石破心法：進化為石破天驚拳。",
				"met": current_force_id == "shipo_xinfa",
			})
			var ultimate_met := current_force_id == "shipo_xinfa" and _is_actor_fully_unequipped(actor)
			out.append({
				"kind": "奧義條件",
				"text_long": "石破心法下，且全身無裝備時，可進化為「真．石破天驚拳」，每名敵人各承受 2~4 次攻擊。",
				"text_short": "奧義：全身無裝備時進化為真．石破天驚拳。",
				"met": ultimate_met,
			})
		"skill_diquejian":
			out.append({
				"kind": "武器加成",
				"text_long": "天殘訣下，劍系招式傷害 +10%；當自身 HP 低於 50% 時，劍系招式暴擊率 +10%。",
				"text_short": "天殘訣：劍傷+10%，低血(HP<50%)時劍招暴擊+10%。",
				"met": current_force_id == "tiancan_jue",
			})
			out.append({
				"kind": "絕技分支",
				"text_long": "天殘訣下可施展「天殘．地缺劍」，消耗目前 HP 的 50%，對全體造成 3.0x ATK 傷害，並受 STR / CON 加權。",
				"text_short": "絕技：可施展天殘．地缺劍（耗50%HP，全體3.0x ATK，STR/CON加權）。",
				"met": current_force_id == "tiancan_jue",
			})
		_:
			pass
	return out

func _is_actor_fully_unequipped(actor: Dictionary) -> bool:
	if actor.is_empty():
		return false
	var actor_id := String(actor.get("id", ""))
	if actor_id == "":
		return false
	if typeof(InventorySync) == TYPE_NIL or not InventorySync.has_method("get_equipped"):
		return false
	var equip_slots := ["weapon_1", "weapon_2", "armor_head", "armor_body", "armor_hands", "armor_feet", "accessory_1", "accessory_2"]
	var equipped: Dictionary = InventorySync.get_equipped(actor_id)
	for slot in equip_slots:
		if String(equipped.get(slot, "")) != "":
			return false
	return true

func _normalize_skill(skill: Dictionary) -> Dictionary:
	return normalize_skill_def(skill)

func _legacy_effect_to_effects(skill: Dictionary) -> Array:
	if skill.has("power"):
		return [{"type": "damage", "power": float(skill.get("power", 1.0))}]
	var legacy_effect := String(skill.get("effect", ""))
	match legacy_effect:
		"heal_hp":
			return [{"type": "heal_hp", "amount": int(skill.get("heal_amount", 0))}]
		"buff_speed":
			return [{"type": "buff_speed", "amount": int(skill.get("amount", 0)), "turns": int(skill.get("turns", 0))}]
		"debuff_speed", "speed_debuff", "slow":
			return [{"type": "slow", "amount": int(skill.get("amount", 0)), "turns": int(skill.get("turns", 0))}]
		"force_element":
			return [{"type": "force_element", "element": String(skill.get("element", "")), "turns": int(skill.get("turns", 0))}]
		_:
			return []

func _actor_get(actor, key: String, default_value):
	if actor == null:
		return default_value
	if typeof(actor) == TYPE_DICTIONARY:
		return (actor as Dictionary).get(key, default_value)
	if actor is Object:
		var value = actor.get(key)
		if value == null:
			return default_value
		return value
	return default_value
