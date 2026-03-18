extends Node
class_name ToneMap

# tone_map[category][key][user_id or "default"]
# category:
#   - "innerforce_applied" : 出招時，內功氣息描述（依 prefix + 角色）
#   - "innerforce_switch"  : 切換內功時的描述（依 prefix + 角色）
#   - "defend"             : 防禦姿態描述（依角色）
#   - "item_use"           : 使用道具時的描述（依效果類型 effect + 角色，施放者視角）
#   - "item_suffer"        : 遭受道具效果時的描述（依效果類型 effect + 角色，中招者視角）
#   - "aoe_suffer"         : AOE 技能多目標受擊敘事（依「技能＋狀態」＋ 角色）
#   - ⚠️ "hit" 另外獨立放在 hit_reactions 裡，由 get_tone_text 特別處理

var tone_map := {
	"battle_intro": {
		"default": {
			"default": "四周氣氛驟沉，殺機一觸即發。"
		},
		"yuheng_bamboo_outskirts_random": {
			"default": "霎時間風聲鶴唳，竹影間殺意驟起。"
		},
		"bamboo_grove_suburb": {
			"default": "霎時間風聲鶴唳，竹影間殺意驟起。"
		},
		"yuheng_sewer_random": {
			"default": "潺潺水聲裡，陰濕惡氣貼著牆根湧來。"
		},
		"sewer": {
			"default": "潺潺水聲裡，陰濕惡氣貼著牆根湧來。"
		}
	},
	"enemy_defeat": {
		"野獸": {
			"default": [
				"{name} 哀鳴一聲，踉蹌著倒地不起。",
				"{name} 吼聲驟止，四肢一軟，重重伏倒在地。",
				"{name} 掙扎著後退兩步，終究力竭倒下。"
			]
		},
		"爬蟲": {
			"default": [
				"{name} 身軀猛地蜷起，隨後癱軟在地。",
				"{name} 嘶鳴漸歇，長身一顫，慢慢伏貼在地面。",
				"{name} 滑行軌跡驟斷，盤起的軀體再也舒展不開。"
			]
		},
		"江湖人士": {
			"default": [
				"{name} 只見他不再運功，也無力維持架勢，如燈枯油盡般倒臥在地。",
				"{name} 他強撐著最後一口氣收住身勢，終究還是無力地倒了下去。",
				"{name} 手中招式散了，胸中那口真氣也再提不起，只得頹然倒地。",
				"{name} 不再逞強，也不再強運內息，只是靜靜地閉上雙眼，任身子倒下。",
				"{name} 架勢一鬆，勉力支撐的身形終於垮了下來，像是坦然認下了這一敗。"
			]
		},
		"地痞": {
			"default": [
				"{name} 猙獰著臉，啐出幾句髒話後腿一軟，當場撲倒在地。",
				"{name} 嘴裡還不乾不淨地罵著，卻早已撐不住那副凶相，踉蹌倒下。",
				"{name} 用盡最後力氣逞兇鬥狠，最終還是像灘爛泥般癱倒在地。",
				"{name} 面色扭曲地咒罵兩聲，隨即氣力一散，再也爬不起來。"
			]
		},
		"朝廷": {
			"default": [
				"{name} 被擊倒在地，官帽一歪，原本端正的威儀也隨之散了。",
				"{name} 踉蹌著退了半步，髮束已亂，卻再無力維持那副官差的架子。",
				"{name} 身形一晃，官袍下擺狼狽地掃過地面，威風頃刻盡失。",
				"{name} 原本整整齊齊的髮束早已凌亂不堪，再也撐不起那身朝廷威勢。"
			]
		},
		"飛禽": {
			"default": [
				"{name} 頓時如斷了線的風箏，在半空失序盤旋數圈後重重墜落。",
				"{name} 再無半分振翅之力，翎羽凌亂，隨即應聲墜地。",
				"{name} 翅影一亂，原本掠空的身姿驟然失衡，斜斜栽落下來。",
				"{name} 在空中掙扎著拍動幾下翅膀，終究還是無力地摔落在地。"
			]
		},
		"鬼神": {
			"default": [
				"{name} 收斂起原本瀰漫四周的不安氣息，四下驟然一靜，眾人這才回過神來。",
				"{name} 周身那股令人窒息的威壓忽然潰散，像一場噩夢被硬生生掐斷。",
				"{name} 纏繞四周的陰冷氣息一寸寸退去，場中終於重新有了活人的呼吸。",
				"{name} 那股壓在心頭的邪異感忽然鬆開，四周重歸死一般的平靜。"
			]
		},
		"語魅": {
			"default": [
				"{name} 身形一顫，籠罩四周的迷霧隨之潰散，只餘零碎暗影消沒於風中。",
				"{name} 原本盤繞不去的詭譎氣息忽然失了依附，像退潮般迅速散去。",
				"{name} 身影在扭曲中一寸寸淡去，最終只剩薄霧般的殘痕消散無蹤。",
				"{name} 那股貼在耳畔低語般的不祥感驟然斷裂，暗影隨即退縮進虛空。",
				"{name} 失了形體，像一抹被風吹散的殘夢，頃刻潰散於無聲之中。"
			]
		},
		"機關": {
			"default": [
				"{name} 火花四濺，機括一陣亂響後徹底停擺。",
				"{name} 齒輪卡死，伴隨刺耳摩擦聲沉重倒落。",
				"{name} 動力驟失，殘餘機件抖動幾下後歸於死寂。"
			]
		},
		"default": {
			"default": [
				"{name} 倒下，已無力再戰。",
				"{name} 氣息一滯，終究再也站不起來。"
			]
		}
	},
	"enemy_attack": {
		"江湖人士": {
			"default": [
				"{name} 一聲低喝，運勁使出 {skill}，出手間自有幾分老到火候，直逼 {target}。",
				"{name} 腳下一沉，使出 {skill}，招路沉穩老練，顯然是多年磨出的手上功夫。",
				"{name} 不疾不徐地遞出 {skill}，看似平淡，實則勁路老辣，直取 {target}。"
			]
		},
		"地痞": {
			"default": [
				"{name} 吊兒郎當地歪著身子，嘴裡罵罵咧咧，抬手就是一記 {skill} 朝 {target} 砸去。",
				"{name} 啐了一聲，帶著幾分痞氣使出 {skill}，橫衝直撞地撲向 {target}。",
				"{name} 那副不可一世的神情還掛在臉上，{skill} 夾雜著亂無章法的橫勁朝著 {target} 打了過去。"
			]
		},
		"朝廷": {
			"default": [
				"{name} 冷眼掃過 {target}，隨即俐落使出 {skill}，舉手投足間不見半分遲疑。",
				"{name} 神色不動，{skill} 已如令出法隨般直取 {target}，乾脆得近乎冷酷。",
				"{name} 面無表情地逼近，一記 {skill} 乾淨利落地落向 {target}，毫無憐憫可言。"
			]
		},
		"野獸": {
			"default": [
				"{name} 喉間低吼，使出的 {skill} 帶著一股兇蠻之氣，猛地朝 {target} 撲咬過去。",
				"{name} 弓起脊背，使出 {skill}，帶著野性兇光直衝 {target}。",
				"{name} 腳爪刨地，隨著 {skill} 暴起撲殺，直取 {target}。"
			]
		},
		"飛禽": {
			"default": [
				"{name} 驟然振翅，使出的 {skill} 挾風自半空俯衝向 {target}。",
				"{name} 翅影一掠，{skill} 伴著尖喙與利爪迎面襲向 {target}。",
				"{name} 長鳴一聲，兜了半圈後使出 {skill}，猛然撲落。"
			]
		},
		"爬蟲": {
			"default": [
				"{name} 貼地疾竄，使出的 {skill} 帶著陰冷氣息逼近 {target}。",
				"{name} 身軀一弓，{skill} 已如毒牙般朝 {target} 閃電噬去。",
				"{name} 尾身一甩，使出 {skill}，陰惻惻地纏向 {target}。"
			]
		},
		"語魅": {
			"default": [
				"{name} 身影一晃，使出的 {skill} 像霧中伸出的惡念般襲向 {target}。",
				"{name} 周身霧氣翻湧，{skill} 便像自陰影深處探出的惡意，直撲 {target}。",
				"{name} 無聲無息地逼近，{skill} 如同從迷霧裡長出的獠牙般咬向 {target}。"
			]
		},
		"鬼神": {
			"default": [
				"{name} 威壓驟沉，使出的 {skill} 逼得 {target} 幾乎喘不過氣來。",
				"{name} 周身邪氣翻騰，{skill} 一出便壓得人心神震顫。",
				"{name} 不過一抬手，{skill} 已裹著不祥之氣直逼 {target}。"
			]
		},
		"機關": {
			"default": [
				"{name} 機括連響，使出的 {skill} 冰冷而精準地鎖向 {target}。",
				"{name} 齒輪急轉，伴著金鐵摩擦聲，{skill} 朝 {target} 直直壓去。",
				"{name} 構件一轉，{skill} 毫無遲疑地朝 {target} 發動。"
			]
		},
		"default": {
			"default": [
				"{name} 運起 {skill}，殺勢直逼 {target}。",
				"{name} 一招 {skill} 遞出，勁風當面壓向 {target}。"
			]
		}
	},
	"enemy_suffer": {
		"江湖人士": {
			"default": [
				"{name} 身形一震，原本穩住的架勢也亂了一拍。",
				"{name} 勉力接下這一擊，氣息卻已隱隱不穩。",
				"{name} 被這一下逼得連退數步，胸中真氣一陣翻湧。"
			]
		},
		"地痞": {
			"default": [
				"{name} 痛得齜牙咧嘴，原本的兇相也垮了半分。",
				"{name} 挨了這一下，嘴裡罵聲更難聽，身形卻已站不穩。",
				"{name} 被打得一個踉蹌，臉上的狠勁都快掛不住了。"
			]
		},
		"朝廷": {
			"default": [
				"{name} 身形一晃，原本端整的步伐也被逼亂了。",
				"{name} 官袍一抖，硬接下這一擊後氣勢明顯弱了三分。",
				"{name} 明明還想穩住儀態，卻已被逼得後退半步。"
			]
		},
		"野獸": {
			"default": [
				"{name} 吃痛低吼，兇性更盛，卻也露出幾分狼狽。",
				"{name} 被這一下打得身子一偏，利爪胡亂刨地。",
				"{name} 哀鳴一聲，原本凶猛的撲勢也被硬生生打斷。"
			]
		},
		"飛禽": {
			"default": [
				"{name} 翅影一亂，在半空中搖晃了幾下。",
				"{name} 吃了這一擊，羽翎紛飛，飛勢也跟著失衡。",
				"{name} 原本俯衝的勢頭一滯，在空中勉強扇動幾下翅膀。"
			]
		},
		"爬蟲": {
			"default": [
				"{name} 身軀一抽，陰冷的滑行軌跡也跟著亂了。",
				"{name} 吃痛地蜷了一下，鱗片間泛起一陣顫動。",
				"{name} 原本悄無聲息的逼近，被這一下打得亂了節奏。"
			]
		},
		"語魅": {
			"default": [
				"{name} 形體一陣扭曲，霧影也跟著散亂了些。",
				"{name} 周身那股詭譎氣息驟然一滯，像被打散了一角。",
				"{name} 暗影翻卷，被逼得連原本凝聚的形態都模糊了。"
			]
		},
		"鬼神": {
			"default": [
				"{name} 威壓一滯，那股壓得人胸口發緊的氣息也跟著鬆了一瞬。",
				"{name} 周身邪意翻湧，像是被這一下硬生生撼動了根基。",
				"{name} 那雙眸光微微一晃，四周的陰冷也淡了幾分。"
			]
		},
		"機關": {
			"default": [
				"{name} 機身一震，齒輪間傳出一陣刺耳雜響。",
				"{name} 挨了這一下，構件接縫處迸出幾點火花。",
				"{name} 被擊得一陣卡頓，原本流暢的運作聲都亂了節拍。"
			]
		},
		"default": {
			"default": [
				"{name} 身形一晃，氣息頓時亂了幾分。",
				"{name} 被這一下逼得踉蹌失勢。"
			]
		}
	},
	"innerforce_applied": {
		"清風": {
			"default": "風姿清逸，氣息若幽蘭。",
			"liuyu": "劉語塵身邊清風揚起，氣如斷浪，架勢剛中帶柔。",
			"shumian": "風聲不語，書眠凝神，氣清風無聲。"
		},
		"夢影": {
			"default": "若夢似幻，氣息縹緲難測，似真似假。",
			"shumian": "夢影心法與書眠的氣質如出一轍，攻守之間自成一境。"
		},
		"赤陽": {
			"default": "內力奔騰如火，攻勢洶湧，一往無前。",
			"lieshao": "列肖的內力在赤陽真經的運行下，陽剛而不燥。"
		},
		"無極": {
			"default": "無極之氣自丹田湧現，氣息深沉難測。",
			"liuyu": "劉語塵收斂呼吸，無極心法如深海般靜默。"
		},
		"破軍": {
			"default": "破軍之勢，一往無前，不留退路。",
			"lieshao": "列肖的目光像在與命運賭一把，破軍心法隨刀勢一同壓下。"
		},
		"靈風": {
			"default": "靈風拂面，身法飄忽，氣機若有若無。",
			"shumian": "靈風心法在書眠筆鋒間流轉，落筆之前，氣路已先一步封死退路。"
		}
	},

	"innerforce_switch": {
		"清風": {
			"default": "他緩緩運起清風訣，氣如流水，散而不亂。",
			"liuyu": "劉語塵吐出一口真氣，清風訣自丹田而起，劍未出鞘，氣先成鋒。"
		},
		"夢影": {
			"default": "她閉上眼，夢影心法在經脈間流轉，如月色灑落水面。",
			"shumian": "書眠的氣息漸沉，夢影心法展開，思緒與殺機一同靜了下來。"
		},
		"赤陽": {
			"default": "赤陽真氣勃然而起，仿若烈日當空。",
			"lieshao": "列肖胸口起伏略深，赤陽真經運轉之下，周身熱浪翻湧。"
		},
		"無極": {
			"default": "無極心法展開，念頭收束成一片空白。",
			"liuyu": "劉語塵吐出一口濁氣，心境歸於無極，一切鋒芒盡藏於鞘。"
		},
		"破軍": {
			"default": "破軍心法一啟，氣勢直指勝負終局。",
			"lieshao": "列肖拂過刀背，破軍經絡啟動之際，也默默替自己闢了前路。"
		},
		"靈風": {
			"default": "靈風心法輕啟，氣息如風行草上，不著壓痕。",
			"shumian": "書眠換氣極輕，靈風心法讓她的身形像落筆前的筆鋒，收而未發。"
		}
	},

	# 防禦姿態：依角色
	"defend": {
		"default": {
			"default": "他收招後氣沉丹田，雙臂微抬，小心提防對手動向。"
		},
		"liuyu": {
			"default": "劉語塵略一退後，將重心壓低，劍鋒斜指，目光緊盯敵手。"
		},
		"shumian": {
			"default": "書眠不再前逼，只是微微側身，筆鋒下垂，像在等對方先露出破綻。"
		},
		"lieshao": {
			"default": "列肖左手搭在琴身，右手停在弦上，似退非退，音殺隨時可能再起。"
		}
	},

	# 使用道具：施放者視角（effect + 角色）
	"item_use": {
		"heal": {
			"default": "藥香在空氣裡散開，緊繃的氣息略微鬆動。",
			"liuyu": "藥香混著淡淡鐵銹味，在急促呼吸間化開，殺伐之氣收斂了幾分。",
			"shumian": "細細藥氣染上紙墨的味道，壓在胸口的悶痛悄然卸去一角。",
			"lieshao": "辛辣藥味順喉而下，翻湧的氣血慢慢歸回既定的節奏，只餘一絲灼熱盤旋不散。"
		},
		"mp_heal": {
			"default": "一口氣順著藥力緩緩下沉，枯竭的真氣像是被重新點亮。",
			"liuyu": "藥力沿著經脈回流，劉語塵指尖一緊，劍鋒深處的氣又重新亮了起來。",
			"shumian": "溫熱藥氣像墨跡暈開，書眠原本發緊的心神慢慢鬆了些。",
			"lieshao": "那點藥勁像酒一樣辣，卻把列肖體內散亂的琴音一一收了回來。"
		},
		"buff_speed": {
			# 🧪 泛用：把「讓人變快」的東西交給某人，不指定是藥、粉或符
			"default": "他打開小瓶，將那點奇物一抖，細細藥霧順著氣流推向腳邊，一股輕盈之氣油然而生。",
			# 劉語塵：出手利落，真氣送藥，動作偏俠客
			"liuyu": "劉語塵指尖一翻，從袖中彈出一撮藥粉，真氣一送，那縷藥霧恰好在腳踝盤旋了一圈。",
			# 書眠：有那種「把東西從紙縫裡抖出去」的感覺
			"shumian": "書眠捏著藥瓶，輕輕一振，藥霧像被她從紙縫裡抖出來似的，沿地滑向立足之處。",
			# 列肖：半吊兒郎當，但其實節奏算得很準
			"lieshao": "列肖懶懶一甩手，把藥粉灑進風裡，不特意瞄準，卻讓風自己去挑該落在誰腳邊。"
		},
		# 出招的人視角：降低對方速度
		"debuff_speed": {
			"default": "手腕一抖，小小暗器破風貼地而出，逼得對手腳下氣勁一滯。",
			"liuyu": "劉語塵從袖中彈出暗器，寒光貼著地面竄去，逼得對方腳下生亂，寸步難行。",
			"shumian": "書眠指尖一彈，細碎機括像散墨般飛出，把對方的腳步牢牢牽住。"
		},
				"haste_talisman": {
						# 🧾 泛用：施展「讓步伐變快／牽動節奏」的法寶，不限定外觀
						"default": "當他從行囊中取出那張靈符時，四周空氣像被扯動，數道疾風在身側盤旋而起，連戰局的節奏都跟著一偏。",
						# 劉語塵：偏出手、牽動風勢，不講是貼自己還是丟敵人
						"liuyu": "劉語塵指尖一翻，那符咒被真氣催亮，被青光照耀的瞬間也不自覺輕了起來。",
						# 書眠：她是「送出去」那個人，符光像紙鷂／墨痕滑行
						"shumian": "那張靈符夾在書眠纖細的指間，就在她舉手的那一霎那，靈光灑落在眾人的腳上。",
						# 列肖：用琴當發射器，把「速度」丟進樂句裡
						"lieshao": "列肖將那張靈符按壓在琴弦上，指尖一撥，符紋隨弦音震盪飛出，腳步也隨著音律輕了起來。"
				},
				"fire_talisman_ally": {
						"default": "符紙啪地貼上時，火紋一寸寸亮起，熱浪順著經脈蔓延，殺氣也被燒得更盛。",
						"liuyu": "劉語塵指尖一抖，符火貼上盔甲，熱力沿著劍勢蔓延，劍鋒像被重新煉過般更顯鋒銳。",
						"shumian": "書眠將符紙輕輕一按，火紋在紙面悄然蔓開，像墨跡被燒亮，連她的筆鋒都染上了炙熱。",
						"lieshao": "列肖把符紙扣在琴背，火光順著弦音竄進血脈，笑意間透著灼熱。"
				},
				"fire_talisman_enemy": {
						"default": "他將符紙翻出，火紋亮起的一瞬，熱浪筆直朝敵陣推去，像要把對手整個燒成焦灰。",
						"liuyu": "劉語塵勾指把符紙彈出，火線劃出一道赤紅弧光，殺意隨之鋪向敵陣。",
						"shumian": "書眠折起符紙，指尖輕彈，火紋化作一條燒紅的墨線，筆直落向敵影。",
						"lieshao": "列肖拈符作弦，啪地一撥，火紋被音浪推送出去，像把一簇火星塞進敵陣。"
				},

				# 萬用預設
				"default": {
						"default": "氣息隨著道具的力量微微起伏，戰局也跟著偏了一寸。"
				},
		"bomb_single": {
			"default": "他將小巧的霹靂彈往前一拋，細小機括一響，火光瞬間竄開。"
		},
		"bomb_aoe": {
			"default": "他抬手拋出那枚沉甸甸的霹靂彈，雷聲尚未落下，空氣已先被壓得發悶。"
		}
	},

	# 遭受道具效果：中招者視角
	"item_suffer": {
		"debuff_speed": {
			"default": "腳下氣勁一滯，步伐不自覺地沉了下去。",
			"liuyu": "勁道纏上腳踝，劉語塵的步伐像被無形所牽，難再全速縱躍。",
			"shumian": "細碎異力黏在她的鞋底，每踏一步都像踩進半乾的墨跡。"
		},
		# 🌀 輕身散 / 提速類效果：被施加在「我身上」時的感受
				"buff_speed": {
						"default": "身形一輕，步伐間多了幾分風聲。",
						"liuyu": "藥力入體，劉語塵腳底像是踩上風，重心變得格外輕盈。",
						"shumian": "她微微吐氣，身影像被從紙上剪下來似的，輕得幾乎要飄開。",
						"lieshao": "列肖活動了一下手腕，像是終於找到節拍，步伐隨著心中鼓點快了半拍。"
				},
				"fire_talisman_ally": {
						"default": "胸口像被火線掃過，熱氣催得手臂微顫，力量卻真真切切地被點亮。",
						"liuyu": "符火貼身，劉語塵握劍的手指微燙，劍意隨之一滲，殺氣也被撩起了。",
						"shumian": "那張符紙一貼，她胸腔像塞進一枚小火炭，筆鋒也比方才更鋒利了些。",
						"lieshao": "列肖低笑一聲，胸口被符火燙得發熱，指尖敲弦時多了幾分狠勁。"
				},
				"fire_talisman_enemy": {
						"default": "火紋猛地炸開，熱浪像一鞭抽在身上，勁道沿著燒痕一路灼入血脈。"
				},
				"default": {
						"default": "一股異力纏上四肢，讓人每走一步都像踩在厚泥裡。"
				},
		"bomb_single": {
			"default": "炸光在影團身上炸開一團白痕，黑霧被震得四散飛濺。"
		},
		"bomb_aoe": {
			"default": "雷爆在陣中連環炸開，成片陰影被掀得東倒西歪，黑霧亂成一片。"
		},

	},

		# 🔷 AOE 技能的多目標受擊敘事（例：翔龍十八掌）
		# key = "技能id|狀態"，
		# 狀態：normal / ke / crit / down（你在 BattleController 裡組好的 state_key）
		"aoe_suffer": {
				"default": {
						"normal": [
								"掌風層層拍過去，敵陣雖未立刻潰散，卻像被攪亂了一池死水。",
								"那一輪攻勢落下時，敵影齊齊一震，腳下步伐都悄悄亂了半拍。"
						],
						"ke": [
								"真勁順著破綻層層炸開，整排身影像被掀起的紙人，一個比一個難以站穩。",
								"剋門之力沿著氣脈逆斬而上，陰影被刮得七零八落，連聚攏的黑霧都晃出裂縫。"
						],
						"crit": [
								"有一掌重重落在陣眼，氣浪從中央炸開一圈空白，邊緣的身影都被震得踉蹌後退。",
								"其中一記掌勁猛然拔高，像是把這一輪攻勢推上頂點，餘威在敵陣中久久不散。"
						],
						"down": [
								"終於有幾道身影撐不住，像被抽走骨架般斜斜倒地，再也爬不起來。",
								"亂成一團的陰影裡，有人膝一軟跪進血水與黑霧之中，氣息迅速潰散。"
						]
				},

		# 你可以之後把 "skill_xianglong18" 改成實際 skill_data 裡的 id
		"skill_xianglong18|ke": {
			"default": "充滿真勁的力道在語魅的軀殼上撕開了一道裂縫，黑霧從傷口裡狂湧而出，須臾後裂口才勉強癒合。"
		},
		"skill_xianglong18|crit": {
			"default": "那團扭曲的氣息猛然一縮，形體抖動幾下，陰影卻又重新黏合。"
		},
		"skill_xianglong18|normal": {
			"default": "掌勁在陰影身上炸開一圈漣漪，黑霧被打得一陣翻湧，陣腳隨之一亂。"
		},
		"skill_xianglong18|down": {
			"default": "有幾縷陰影被掌風正面掃中，輪廓扭曲成一團，再也無法重新聚攏，只能轟然潰散。"
		}
	}
}


var status_apply_tones := {
	"stun": "點穴落在要害，氣脈驟然一滯。",
	"poison": "暗勁無聲滲入經脈，毒意已悄然伏下。",
	"confuse": "言語如霧，心神被撥得搖搖欲墜。",
	"weak": "一縷虛耗之勁纏上胸膈，元氣頓時浮動。",
	"seal_mp": "指勁封鎖關節要穴，內息流轉瞬間受阻。",
	"default": "勁力一轉，異常之勢已悄然種下。"
}

var status_suffer_tones := {
	"slow": {
		"江湖人士": [
			"{name} 腳下一滯，原本流暢的步法頓時沉了下來。",
			"{name} 像是被無形重物拖住，身形再難靈動轉換。"
		],
		"地痞": [
			"{name} 腳步一沉，連原本那股兇狠衝勁都慢了半拍。",
			"{name} 像踩進爛泥裡似的，再怎麼發狠也快不起來。"
		],
		"野獸": [
			"{name} 四肢像灌了鉛般沉重，撲勢頓時一滯。",
			"{name} 原本兇猛的奔撲被拖慢，低吼聲裡都透著焦躁。"
		],
		"飛禽": [
			"{name} 翅勢一沉，再難保持原本的俐落掠空。",
			"{name} 像是被看不見的濕氣纏住，振翅也變得遲滯。"
		],
		"語魅": [
			"{name} 霧影流轉的速度明顯慢了下來，像被什麼拖住了。",
			"{name} 那股飄忽難測的身形忽然凝滯，暗影也不再靈巧。"
		],
		"default": "動作忽然一沉，像被無形阻力拖慢。"
	},
	"stun": {
		"江湖人士": [
			"{name} 氣脈一滯，眼神都渙散了一瞬。",
			"{name} 身形搖晃兩下，像是連神識都被這一下打散了。"
		],
		"地痞": [
			"{name} 眼前一黑，方才那點兇狠勁頭也瞬間斷了。",
			"{name} 被震得腦中嗡然作響，整個人一時怔在原地。"
		],
		"朝廷": [
			"{name} 腦中一震，連原本端整的架式都維持不住。",
			"{name} 神色一陣恍惚，手中原本講究的章法頓時散亂。"
		],
		"野獸": [
			"{name} 被震得一陣發懵，低吼都跟著斷了。",
			"{name} 原本兇猛的目光一黯，身形也僵在原地。"
		],
		"語魅": [
			"{name} 霧影微滯，像是連那股邪念都被打散了一瞬。",
			"{name} 暗影顫了一下，整團氣息都像失去了依憑。"
		],
		"default": "眼前一黑，四肢像被釘在原地。"
	},
	"poison": {
		"江湖人士": [
			"{name} 臉色驟變，像有一股陰冷之氣順著經脈鑽了進去。",
			"{name} 呼吸一亂，顯然毒性已悄悄滲入體內。"
		],
		"地痞": [
			"{name} 臉皮一抽，罵聲還沒出口，毒意已先一步竄上來。",
			"{name} 身子猛地一顫，顯然那股毒氣已經發作。"
		],
		"野獸": [
			"{name} 發出一聲躁怒低吼，卻壓不住毒意侵骨的痛楚。",
			"{name} 皮毛下的肌肉一陣抽動，毒性已然入體。"
		],
		"爬蟲": [
			"{name} 原本陰冷的氣息忽然一滯，像連牠都受不住這毒性反噬。",
			"{name} 身軀緊緊蜷縮了一下，毒意在體內悄然蔓延。"
		],
		"語魅": [
			"{name} 周身霧色一陣渾濁，那股詭氣像被污濁之物侵蝕。",
			"{name} 原本凝聚的暗影裡滲出一絲敗壞氣息，像是受了污染。"
		],
		"default": "胸口微麻，毒性正沿著血脈悄悄擴散。"
	},
	"confuse": {
		"江湖人士": [
			"{name} 目光一散，像是連眼前敵我都一時分不清了。",
			"{name} 神思被攪得一團亂，連原本熟極而流的招路都失了方向。"
		],
		"地痞": [
			"{name} 嘴裡罵著罵著，自己都像不知道該朝誰出手。",
			"{name} 那股狠勁還在，眼神卻已經亂得沒了準頭。"
		],
		"朝廷": [
			"{name} 原本講究章法的出手忽然一亂，像連誰是敵誰是友都辨不清了。",
			"{name} 神色微變，原本井井有條的心神被攪成一片渾沌。"
		],
		"語魅": [
			"{name} 那股詭譎意念彼此衝撞，連自身形體都顯得搖晃不定。",
			"{name} 暗影流轉失序，像是連牠自己都被自己的惡念反噬。"
		],
		"default": "耳畔嗡鳴不止，出手方向忽然失了準頭。"
	},
	"seal_mp": {
		"江湖人士": [
			"{name} 胸口一滯，原本運轉順暢的內息像被硬生生卡住。",
			"{name} 氣脈一閉，再想運功時已感到處處受阻。"
		],
		"朝廷": [
			"{name} 呼吸忽然一窒，原本穩當的氣勁再難提聚。",
			"{name} 那套看似井然的運息節奏，被這一下生生打亂。"
		],
		"語魅": [
			"{name} 四周詭氣一滯，像是連那股凝聚形體的核心都被鎖住。",
			"{name} 原本翻湧不休的邪氣忽然收縮，像被無形鎖鏈束住。"
		],
		"default": "經脈像被鎖住，真氣難再順勢運行。"
	},
	"weak": {
		"江湖人士": [
			"{name} 面色一白，像是連撐住身形的那口元氣都被抽走了。",
			"{name} 氣血頓衰，原本勉力提著的精神也明顯萎了下去。"
		],
		"地痞": [
			"{name} 剛才還兇神惡煞，這會兒卻像一下子被抽乾了力氣。",
			"{name} 身子一軟，那股蠻橫氣勢明顯弱了下來。"
		],
		"野獸": [
			"{name} 嗚咽一聲，四肢顫了顫，連兇性都像被磨去了幾分。",
			"{name} 原本緊繃的筋骨忽然鬆垮下來，整個勢頭都弱了。"
		],
		"default": "氣海一沉，連呼吸都變得虛浮乏力。"
	},
	"blind": {
		"江湖人士": [
			"{name} 下意識偏頭避讓，視線卻已被擾得一片散亂。",
			"{name} 眼前一花，再想鎖定對手時已失了準頭。"
		],
		"地痞": [
			"{name} 連眨幾下眼，嘴裡罵得更兇，卻怎麼也看不真切。",
			"{name} 被晃得眼冒金星，連人影都抓不穩。"
		],
		"飛禽": [
			"{name} 眼前失了準頭，原本精準的俯衝也變得歪斜。",
			"{name} 翅膀拍得再急，也難補回那一瞬失去的視準。"
		],
		"default": "砂影掠過眼前，視野瞬間晃成一片。"
	},
	"root": {
		"江湖人士": [
			"{name} 腳下像被什麼拖住，再難像先前那般靈巧挪移。",
			"{name} 步法一滯，連閃身騰挪都慢了半拍。"
		],
		"地痞": [
			"{name} 腳底像黏在地上似的，再想躲閃已慢了一步。",
			"{name} 剛想閃躲，身子卻像被什麼絆住，狼狽得很。"
		],
		"野獸": [
			"{name} 四肢發沉，原本敏捷的撲躍再也施展不開。",
			"{name} 想躍開時卻慢了半拍，整個身形都顯得笨重。"
		],
		"default": "下盤被勁力纏住，步法轉挪大受牽制。"
	},
	"default": {
		"default": "異常感在體內擴散，行動明顯受阻。"
	}
}

# 🩸 被擊中時的反應語（區分我方 ally / 敵方 enemy）
# key:
#   - "normal"     : 一般被擊中（非剋制、非防禦）
#   - "weak"       : 被克制屬性擊中
#   - "def_normal" : 防禦狀態下被擊中（非剋制）
#   - "def_weak"   : 防禦狀態下仍被克制屬性擊中
var hit_reactions := {
	"ally": {
		"default": {
			"normal": [
				"身形一震，真氣運行略顯紊亂，卻仍咬牙穩住腳步。"
			],
			"weak": [
				"勁力順著破綻一路鑽入臟腑，那一瞬間呼吸幾乎要斷。"
			],
			"def_normal": [
				"護身氣勁硬生生擋下多半力道，餘勁卻依舊在經脈裡亂竄。"
			],
			"def_weak": [
				"就算提氣護身，剋門之力仍趁隙滲入，護體真氣被打得陣陣發顫。"
			]
		},

		"liuyu": {
			"normal": [
				"劉語塵悶哼一聲，腳步連退兩步，卻仍強撐著站穩。",
				"劍還握在手中，胸口卻先挨了一記，劉語塵眉頭一皺，悶咳了一聲。"
			],
			"weak": [
				"勁道沿著軟肋一路竄入臟腑，劉語塵臉色一沉：這一招正中破綻。",
				"這一擊不偏不倚地擊中了劉語塵氣路未穩之處，他握劍的指節僵硬了片刻。"
			],
			"def_normal": [
				"他雙臂一錯，勉強化開來勢，護身氣勁被震得微微發麻。",
				"劍鋒橫擋，力道順勢滑過，他順勢卸去多半勁力，只餘胸口一悶。"
			],
			"def_weak": [
				"明知是剋門一路，他仍咬牙硬封，護身罡氣被打得一陣錯亂。",
				"劍上真氣被震得支離破碎，劉語塵心知再吃幾記這樣的招數，恐怕氣脈難全。"
			]
		},

		"lieshao": {
			"normal": [
				"列肖眉梢一跳，琴弦微顫，胸口一悶卻只冷笑出聲。",
				"力道毫不遮掩地透過琴身傳入臂骨，他不只挨了一擊，也被撞亂一弦音。"
			],
			"weak": [
				"那股力道順勢擊在他尚未復平的舊傷上，列肖一時連琴音都壓低了半分。",
				"勁氣沿著經絡逆流而上，他指尖一抖，差點掐錯弦。"
			],
			"def_normal": [
				"列肖抬手護胸，餘勁透過臂骨傳來，但微不足道的痛意絲毫不影響他的笑意半分。",
				"琴身橫在身前替列肖擋下大半衝擊，只剩微不足道的餘波稍微擾了琴音幾許，律尚在。"
			],
			"def_weak": [
				"明知不利仍強撐著將餘勁導入琴身，琴音一顫，彷彿替他挨了這一記。",
				"那一下幾乎要將他的護身音勁打散，列肖只用更懶散的笑意壓住臉色的發白。"
			]
		},

		"shumian": {
			"normal": [
				"書眠身形一晃，袖底的紙頁散出兩三張，她連忙按住胸口。",
				"力道震得她呼吸一窒，指間原本夾著的紙角微微歪斜。"
			],
			"weak": [
				"那股力量仿佛將她從夢縫裡硬拉出來，書眠眼神一瞬恍惚，氣息亂了半拍。",
				"勁力鑽入未完全閉合的經脈氣口，她悶聲退了一步，睫毛不自覺顫了顫。"
			],
			"def_normal": [
				"她下意識側身用臂膀擋下來勢，力道仍透進肩骨，疼得眉頭微微一皺。",
				"袖下真氣一繃，將多半勁道擋在臂外，卻仍在骨縫裡留下一陣酸麻。"
			],
			"def_weak": [
				"就算提氣護身，這一路剋門勁力仍鑽入縫隙，書眠悶聲退了兩步，指間紙頁微微發顫。",
				"護身氣幕被生生撕開一線，她低頭喘了口氣，像在把疼痛一頁一頁地壓回書裡。"
			]
		}
	},

	"enemy": {
		"default": {
			"normal": [
				"那團扭曲的氣息猛然一縮，形體抖動幾下，陰影卻又重新黏合。"
			],
			"weak": [
				"充滿真勁的力道在語魅身上撕開了一道裂縫，黑霧從傷口裡狂湧而出，須臾後裂口才勉強癒合。"
			],
			"def_normal": [
				"它似乎試圖聚攏氣息護身，卻仍被打得輪廓一陣模糊。"
			],
			"def_weak": [
				"防禦的氣幕被直接扯碎，陰影像被陽光逼退般亂竄，發出含糊不清的低鳴。"
			]
		}
	}
}


func get_tone_text(category: String, key: String, user_id: String, side: String = "") -> String:
	# 🔹 特例：被擊中語氣（category = "hit", key = hit_kind）
	if category == "hit":
		return _get_hit_text(user_id, key, side)
	if category == "status_apply":
		return String(status_apply_tones.get(key, status_apply_tones.get("default", "")))
	if category == "status_suffer":
		return _get_status_suffer_text(key)

	if not tone_map.has(category):
		return ""

	var cat_map = tone_map[category]

	# 1）內功：看 prefix（key）
	if category == "innerforce_applied" or category == "innerforce_switch":
		if not cat_map.has(key):
			return ""
		var prefix_map = cat_map[key]
		if prefix_map.has(user_id):
			return prefix_map[user_id]
		return prefix_map.get("default", "")

	# 2）使用道具 / 遭受道具：看 effect（key）
	elif category == "item_use" or category == "item_suffer":
		if key == "" or key == "default":
			return ""

		var effect_map = cat_map.get(key, null)
		if effect_map == null:
			effect_map = cat_map.get("default", null)
		if effect_map == null:
			return ""

		if effect_map.has(user_id):
			return effect_map[user_id]
		return effect_map.get("default", "")

	# 2-1）戰鬥開場白：看 intro key
	elif category == "battle_intro":
		if key == "":
			return ""
		var intro_map = cat_map.get(key, null)
		if intro_map == null:
			intro_map = cat_map.get("default", null)
		if intro_map == null:
			return ""
		if intro_map.has(user_id):
			return intro_map[user_id]
		return intro_map.get("default", "")

	# 3）AOE 受擊：key = "skillId|state" 或 "state"
	elif category == "aoe_suffer":
		if key == "":
			return ""

		# 3-1️⃣ 先嘗試專屬 key（例如 "skill_xianglong18|ke"）
		var tone_group = cat_map.get(key, null)
		if tone_group != null:
			if tone_group.has(user_id):
				return tone_group[user_id]
			return tone_group.get("default", "")

		# 3-2️⃣ 專屬沒有 → 退回共用 default，依 state 抽一句
		var state_name := ""
		var pipe_index := key.find("|")
		if pipe_index != -1:
			state_name = key.substr(pipe_index + 1, key.length() - pipe_index - 1)
		else:
			state_name = key  # 你也可以直接傳 "normal" / "ke" 進來

		var default_group = cat_map.get("default", null)
		if default_group == null:
			return ""

		var arr = default_group.get(state_name, [])
		if typeof(arr) == TYPE_ARRAY and not arr.is_empty():
			return arr[randi() % arr.size()]

		# 再不行就用 normal 頂著
		arr = default_group.get("normal", [])
		if typeof(arr) == TYPE_ARRAY and not arr.is_empty():
			return arr[randi() % arr.size()]

		return ""

	# 3-1）敵方攻擊／受擊／倒地敘事：依 archetype key
	elif ["enemy_attack", "enemy_suffer", "enemy_defeat"].has(category):
		var group = cat_map.get(key, null)
		if group == null:
			group = cat_map.get("default", null)
		if group == null:
			return ""
		var line_source = group.get("default", "")
		if group.has(user_id):
			line_source = group[user_id]
		return _resolve_text_or_array(line_source)

	# 4）其他（defend 等）：不吃 key，只看角色
	else:
		if cat_map.has(user_id):
			return cat_map[user_id].get("default", "")
		if cat_map.has("default"):
			return cat_map["default"].get("default", "")
	return ""


func _get_status_suffer_text(key: String) -> String:
	var effect_id := key
	var archetype := ""
	if key.find("|") != -1:
		var parts := key.split("|", false, 1)
		effect_id = str(parts[0])
		if parts.size() > 1:
			archetype = str(parts[1])
	if effect_id == "speed_debuff":
		effect_id = "slow"

	var effect_map = status_suffer_tones.get(effect_id, null)
	if typeof(effect_map) != TYPE_DICTIONARY:
		effect_map = status_suffer_tones.get("default", {})
	if typeof(effect_map) != TYPE_DICTIONARY:
		return ""

	if archetype != "":
		if effect_map.has(archetype):
			return _resolve_text_or_array(effect_map[archetype])
		if effect_map.has("江湖人士"):
			return _resolve_text_or_array(effect_map["江湖人士"])

	if effect_map.has("default"):
		return _resolve_text_or_array(effect_map["default"])

	var default_map = status_suffer_tones.get("default", {})
	if typeof(default_map) == TYPE_DICTIONARY and default_map.has("default"):
		return _resolve_text_or_array(default_map["default"])
	return ""


func _resolve_text_or_array(value) -> String:
	if typeof(value) == TYPE_ARRAY:
		var arr: Array = value
		if arr.is_empty():
			return ""
		return str(arr[randi() % arr.size()])
	return str(value)



# 🩹 被擊中語氣挑選（依 side = "ally" / "enemy"）
func _get_hit_text(user_id: String, hit_kind: String, side: String) -> String:
	var branch := side
	if branch == "":
		branch = "ally"  # 預設當作我方

	if not hit_reactions.has(branch):
		return ""

	var side_map = hit_reactions[branch]

	var char_map = side_map.get(user_id, null)
	if char_map == null:
		char_map = side_map.get("default", null)
	if char_map == null:
		return ""

	var group: Array = []

	match hit_kind:
		"weak":
			group = char_map.get("weak", [])
		"def_normal":
			group = char_map.get("def_normal", [])
		"def_weak":
			group = char_map.get("def_weak", [])
		_:
			group = char_map.get("normal", [])

	if group.is_empty():
		return ""

	var idx := randi() % group.size()
	return group[idx]
