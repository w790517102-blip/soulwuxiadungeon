extends Node
class_name ToneMap

const SPECIFIC_POOL_WEIGHT := 0.7
const DEFAULT_POOL_WEIGHT := 0.3

var _last_tone_pick_by_context: Dictionary = {}

# tone_map[category][key][user_id or "default"]
# category:
#   - "innerforce_applied" : 出招時，內功氣息描述（依 prefix + 角色）
#   - "innerforce_switch"  : 切換內功時的描述（依 prefix + 角色）
#   - "defend"             : 防禦姿態描述（依角色）
#   - "item_use"           : 使用道具時的描述（依效果類型 effect + 角色，施放者視角）
#   - "item_suffer"        : 遭受道具效果時的描述（依效果類型 effect + 角色，中招者視角）
#   - "ally_attack"       : 我方單體出手敘事（依武器類型＋角色）
#   - "ally_attack_aoe"   : 我方 AOE 出手敘事（依武器類型＋角色，會回退到 ally_attack）
#   - "ally_dodge"        : 我方／通用閃避敘事（依角色）
#   - "ally_enemy_defeat" : 我方擊倒敵人時的敘事（依角色）
#   - "ally_down_self"    : 我方自己倒地時的敘事（依角色）
#   - "ally_down_reaction": 我方看見隊友倒地時的反應（依角色）
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
		},
		"zueyue_teashop_training": {
			"default": "茶香未散，席間卻已暗自騰起試招的鋒芒。"
		}
	},
	"ally_attack": {
		"劍": {
			"default": [
				"{name} 長劍一指，寒光劃破長空，展開「{skill}」攻勢。",
				"劍氣縱橫，{name} 使出「{skill}」，劍招凌厲逼人！"
			]
		},
		"刀": {
			"default": [
				"{name} 揚刀而起，「{skill}」氣勢如破竹，直劈向 {target}。",
				"刀光斬落，{name} 使出「{skill}」，勢不可擋！"
			]
		},
		"槍": {
			"default": [
				"{name} 長槍一震，使出「{skill}」，槍尖寒芒直逼 {target}。",
				"槍勢如龍，{name} 挺槍使出「{skill}」，勁道筆直貫向 {target}。"
			]
		},
		"棍": {
			"default": [
				"{name} 掄棍而上，使出「{skill}」，棍影挾風壓向 {target}。",
				"棍勢沉雄，{name} 一招「{skill}」掃出，逼得 {target} 不得不硬接。"
			]
		},
		"拳": {
			"default": [
				"{name} 雙拳如風，「{skill}」一式轟出，空氣震動！",
				"{name} 喊聲一震，一拳「{skill}」破空而來！"
			]
		},
		"掌": {
			"default": [
				"{name} 吐氣開聲，掌勢如山，「{skill}」撼得地動山搖！",
				"{name} 身形一旋，掌影連綿，「{skill}」驟然拍至 {target}！"
			]
		},
		"筆": {
			"default": [
				"{name} 揮筆如劍，「{skill}」筆鋒直指敵首，墨氣如劍氣般爆發！",
				"濃墨淋漓，{name} 使出「{skill}」，筆落驚風雨！"
			]
		},
		"琴": {
			"default": [
				"{name} 撫琴一震，旋律間藏殺機，「{skill}」震得 {target} 氣血翻湧。",
				"音律飄渺，{name} 撥弦化刃，「{skill}」凝聚殺意一曲！"
			]
		},
		"default": {
			"default": [
				"在電光石火之間，{name} 凝神運氣，使出「{skill}」。",
				"只見 {name} 身形一閃，「{skill}」如雷霆萬鈞般擊向 {target}。",
				"{name} 一聲低喝，真氣貫通掌心，使出「{skill}」！",
				"{name} 提氣縱身而上，赫然揮出「{skill}」！"
			]
		}
	},
	"ally_attack_aoe": {
		"劍": {
			"default": [
				"{name} 劍光一展，寒芒如圈般朝四周蕩開。",
				"{name} 一劍橫掃而出，劍勢如風，逼得眾敵同時後撤。"
			]
		},
		"刀": {
			"default": [
				"{name} 刀勢大開大闔，一記橫斬便將面前敵人盡數捲入。",
				"{name} 刀光如浪翻起，霸道勁勢朝四周席捲而去。"
			]
		},
		"槍": {
			"default": [
				"{name} 槍勢一抖，寒星點點連成一片，逼向前方眾敵。",
				"{name} 長槍橫攔再掃，槍風如龍尾甩出，震開周遭敵影。"
			]
		},
		"棍": {
			"default": [
				"{name} 棍影翻飛，勁道一圈圈盪開，逼得眾敵難以近身。",
				"{name} 一棍掄圓，呼嘯勁風朝四面八方掃了出去。"
			]
		},
		"筆": {
			"default": [
				"{name} 筆鋒一轉，墨意如煙霞鋪展，將眾敵盡數卷入其中。",
				"{name} 筆走游龍，揮灑出的勁意如墨浪般朝四周漫開。"
			]
		},
		"琴": {
			"default": [
				"{name} 琴音驟起，層層音浪朝四周推盪而出，震得眾敵心神齊顫。",
				"{name} 指下一拂，音勁如漣漪般擴散開來，同時籠住眾敵。"
			]
		},
		"拳": {
			"default": [
				"{name} 拳勁震開，剛猛力道如波般朝四周擴散。",
				"{name} 一拳轟出，餘勢未絕，竟將周遭敵影一併震退。"
			]
		},
		"掌": {
			"default": [
				"{name} 掌風層層推出，如浪疊岸，將眾敵同時捲入其中。",
				"{name} 一掌落下，氣浪翻湧，勁勢朝四面八方盪開。",
				"{name} 使出「{skill}」，掌風層層拍出，氣浪如驟雨般席捲整個敵陣。"
			]
		},
		"default": {
			"default": [
				"{name} 勁勢驟然擴散，眾敵同時被捲入這一波攻勢之中。",
				"{name} 那一擊不再只取一人，而是如潮般朝整片敵陣壓了過去。"
			]
		}
	},
	"ally_dodge": {
		"liuyu": {
			"default": [
				"劉語塵目光微側，早一步看穿來勢，身形一讓，那道攻勢便擦身而過。",
				"劉語塵腳下只輕輕挪開半步，來招便落了空，連衣角都未曾亂上一分。",
				"那股勁風幾乎貼著劉語塵掠過，卻見他身形已悄然錯開，像是早知此招會落在哪裡。",
				"劉語塵不與來勢正面相迎，只順著那一瞬間的空隙側身避過，動作乾淨得近乎冷淡。"
			]
		},
		"shumian": {
			"default": [
				"書眠身影一晃，像紙頁被風輕輕翻過一般，攻勢便從她身側滑了開去。",
				"書眠步伐輕得幾乎不著痕跡，只一轉身，便讓那道攻勢落進了空處。",
				"那一擊眼看便要落在書眠身上，卻見她身形像宣紙上的墨痕輕輕一偏自然游開，避開了攻勢。",
				"書眠退得不急不徐，偏偏正好讓過那一招，彷彿連風都替她留了一線餘地。"
			]
		},
		"lieshao": {
			"default": [
				"列肖懶懶地一側身，像是早就料到對方碰不到自己，那一下便從他身旁空空掠過。",
				"列肖腳下步子看著散漫，偏偏就差那麼一寸，讓來招撲了個空。",
				"眼見攻勢逼近，列肖卻只漫不經心地一晃身，便將那一擊讓得乾乾淨淨。",
				"列肖像是根本沒把這一下放在眼裡，只隨意挪了挪步，對方的勁路便盡數落空。"
			]
		},
		"default": {
			"default": [
				"來勢雖急，卻終究只擦著身影掠過，半分也未能真正碰著。",
				"只見那道攻勢幾乎逼到眼前，卻在最後一瞬被輕巧地讓了過去。",
				"對方招式看似逼人，卻仍差了那麼一線，終究落了個空。",
				"身形微微一側，來招便順勢擦了過去，連步法都未見半點凌亂。",
				"那股勁風幾乎貼身而過，卻始終差著一寸，沒能真正落到實處。",
				"眼看那一擊便要得手，卻被對方抓住空隙，恰到好處地避了開去。"
			]
		}
	},
	"ally_enemy_defeat": {
		"liuyu": {
			"default": [
				"劉語塵收住手中勁路，目光只在倒下的敵人身上停了一瞬，隨即已將心神挪回下一個來敵。",
				"劉語塵一招得手便不再多看，像是早知此戰必有結果，只將劍勢悄然收回。",
				"敵人應聲倒下，劉語塵卻未露半分得色，只靜靜立在原地，像風自竹隙間掠過一般平淡。",
				"劉語塵確認對手再無力起身後，手中招式已然收盡，乾淨得不留半分多餘。"
			]
		},
		"shumian": {
			"default": [
				"書眠見敵人終於倒下，眼中並無半分喜色，只輕輕斂住氣息，像是將方才翻湧的墨意重新收回心底。",
				"那一招定下勝負後，書眠只是靜靜望了對方一眼，神色裡更多的是鬆下一口氣，而非趁勝的凌厲。",
				"敵人失勢倒地，書眠衣袖微垂，像是一頁寫完的詩終於落下最後一筆。",
				"書眠站定身形，望著塵埃漸歇，原本緊繃的眉眼也跟著緩了幾分。"
			]
		},
		"lieshao": {
			"default": [
				"敵人才剛倒下，列肖便懶懶收回手勢，像是這樣的結果本就不值得大驚小怪。",
				"列肖瞥了倒地的對手一眼，神情裡帶著點淡淡的不耐，像是在說這場鬧劇總算肯收場了。",
				"那一擊落定後，列肖只是把氣息一收，眼神淡淡掠過，彷彿勝負早就寫在前頭。",
				"對手終於支撐不住倒下，列肖神色不動，連唇角都只微微一撇，像是意料之中的收尾。"
			]
		},
		"default": {
			"default": [
				"那一擊終於定下勝負，對手再撐不住，頹然倒地。",
				"勝負既分，場中的氣息也隨之一鬆，只剩對手倒地不起。",
				"對方原本還想勉力支撐，終究還是氣力一散，當場倒下。",
				"那股僵持許久的勁頭終於斷了，敵人應聲敗退，再無餘力起身。",
				"只見對手身形一晃，原本撐著的最後一口氣終究散去，整個人頹然倒下。",
				"這一招過後，對方便再也提不起反擊之力，只能無聲地倒在地上。"
			]
		}
	},
	"ally_down_self": {
		"liuyu": {
			"default": [
				"劉語塵身形一晃，原本還勉力穩住的氣息終於斷了，整個人重重跪落下去。",
				"劉語塵強撐著不肯失勢，終究還是撐不住那口氣，身形沉沉倒下。",
				"只見劉語塵手中勁路一散，腳下再難站穩，像是連最後那點支撐也終於被抽空。",
				"劉語塵本還想提氣再戰，胸中那口真息卻已續不上，終究無力地倒了下去。"
			]
		},
		"shumian": {
			"default": [
				"書眠身子輕輕一晃，像被風折落的紙頁般失了依憑，終究無力地倒了下去。",
				"書眠本還想穩住身形，可那口氣終究散了，眼前一暗，整個人便軟了下來。",
				"只見書眠衣袖輕顫，腳下再也支撐不住，像墨痕被雨水沖散一般，悄然倒地。",
				"書眠胸口起伏了兩下，原本勉強提著的精神終於斷了線，身形隨之垮了下去。"
			]
		},
		"lieshao": {
			"default": [
				"列肖腳下踉蹌了一步，原本還帶著幾分散漫的身形終於再撐不住，重重倒了下去。",
				"列肖本還想用最後一點力氣把身形撐住，卻終究失了支撐，整個人向後倒去。",
				"那一下像是徹底抽空了列肖胸中的氣勁，連他慣有的從容都碎了，身形隨之頹然倒地。",
				"列肖被逼得退了半步又半步，終究還是沒能站住，只得狼狽地倒了下去。"
			]
		},
		"default": {
			"default": [
				"胸中那口氣終於續不上，身形一晃，整個人便再也撐不住。",
				"原本還勉強穩住的步伐終於散了，身子隨之一沉，重重倒地。",
				"那一擊像是徹底抽空了僅剩的力氣，整個人終究無力地倒了下去。",
				"再想提氣時已是力不從心，只見身形一軟，頹然倒地。",
				"原本勉強撐住的架勢終於崩散，再也無法站穩。",
				"氣息一斷，身形便再難維持，只能任由自己向地上倒去。"
			]
		}
	},
	"ally_down_reaction": {
		"liuyu": {
			"default": [
				"劉語塵目光驟然一沉，原本平穩的氣息也在那一瞬間亂了一拍。",
				"眼見同伴倒下，劉語塵手中動作明顯一滯，像是胸口被什麼重重一扯。",
				"劉語塵沒有立刻出聲，只是眼神比方才更冷了幾分，連周身的氣息都跟著繃緊。",
				"同伴倒地的那一刻，劉語塵原本收斂的鋒芒像被逼了出來，整個人都沉了下去。"
			]
		},
		"shumian": {
			"default": [
				"書眠見同伴倒下，呼吸明顯亂了一下，連眼底都浮起了掩不住的驚色。",
				"那一幕落進書眠眼裡，像是原本穩住的心緒被重重撥亂，連指尖都微微發顫。",
				"書眠下意識向前一步，眼神裡再沒有方才的從容，只有止不住的擔憂。",
				"見同伴倒地，書眠胸口一緊，像是連原本穩穩落下的筆意都被這一幕驟然打斷。"
			]
		},
		"lieshao": {
			"default": [
				"列肖原本漫不經心的神色忽然冷了下來，連那點懶散都在瞬間收了乾淨。",
				"同伴倒下的一刻，列肖目光微微一沉，原先那副事不關己的模樣終究裂開了一道縫。",
				"列肖看著那道身影倒下，手中動作雖未停，眼神卻比方才更冷、更深了些。",
				"那一瞬間，列肖像是把原本掛在臉上的散漫都收了起來，只剩一股壓得極低的怒意。"
			]
		},
		"default": {
			"default": [
				"眼見同伴倒下，場中的氣息也在那一瞬間亂了一拍。",
				"同伴頹然倒地，原本穩住的節奏也被這一幕硬生生扯亂。",
				"那道身影倒下的瞬間，眾人心頭都像被重重一壓。",
				"見同伴支撐不住倒地，原本緊扣的戰局也在這一刻生出裂縫。",
				"同伴一倒，場中的氣氛驟然沉了下來，連呼吸都像跟著一滯。",
				"那一幕映入眼底，任誰都知道，這一戰已再不能有半分鬆懈。"
			]
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
				"{name} 滑行軌跡驟斷，盤起的軀體再也舒展不開。",
				"{name} 勉強扭動幾下，終究只剩冰冷軀身蜷縮在原地。"
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
		"未知": {
			"default": [
				"{name} 形體一震，終於再也維持不住原本的姿態。",
				"{name} 氣息紊亂，踉蹌幾下後頹然倒下。",
				"{name} 掙扎片刻，終究還是失去再戰之力。"
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
			"default": "{name} 緩緩運起清風訣，氣如流水，散而不亂。",
			"liuyu": "{name} 吐出一口真氣，清風訣自丹田而起，劍未出鞘，氣先成鋒。"
		},
		"流塵": {
			"default": "{name} 運轉流塵訣，身法更輕，目力更準，劍勢也隨之轉為流塵之勢。"
		},
		"夢影": {
			"default": "{name} 改運夢影心法，胸中真氣更盛，筆意流轉也輕靈了幾分。",
			"shumian": "{name} 的氣息漸沉，夢影心法展開，思緒與殺機一同靜了下來。"
		},
		"赤陽": {
			"default": "{name} 催運赤陽真氣，勃然而起，仿若烈日當空。",
			"lieshao": "{name} 胸口起伏略深，赤陽真經運轉之下，周身熱浪翻湧。"
		},
		"無極": {
			"default": "{name} 切換為無極真經，周身氣勁一沉，護勢隨之穩固下來。",
			"liuyu": "{name} 吐出一口濁氣，心境歸於無極，一切鋒芒盡藏於鞘。"
		},
		"破軍": {
			"default": "{name} 一啟破軍心法，氣勢直指勝負終局。",
			"lieshao": "{name} 拂過刀背，破軍經絡啟動之際，也默默替自己闢了前路。"
		},
		"靈風": {
			"default": "{name} 輕啟靈風心法，氣息如風行草上，不著壓痕。",
			"shumian": "{name} 換氣極輕，靈風心法讓身形像落筆前的筆鋒，收而未發。"
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
	},
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
		return _pick_weighted_text(
			prefix_map.get(user_id, null),
			prefix_map.get("default", ""),
			"%s|%s|%s" % [category, key, user_id]
		)

	# 2）使用道具 / 遭受道具：看 effect（key）
	elif category == "item_use" or category == "item_suffer":
		if key == "" or key == "default":
			return ""

		var effect_map = cat_map.get(key, null)
		if effect_map == null:
			effect_map = cat_map.get("default", null)
		if effect_map == null:
			return ""

		return _pick_weighted_text(
			effect_map.get(user_id, null),
			effect_map.get("default", ""),
			"%s|%s|%s" % [category, key, user_id]
		)

	# 2-1）戰鬥開場白：看 intro key
	elif category == "battle_intro":
		if key == "":
			return ""
		var intro_map = cat_map.get(key, null)
		if intro_map == null:
			intro_map = cat_map.get("default", null)
		if intro_map == null:
			return ""
		return _pick_weighted_text(
			intro_map.get(user_id, null),
			intro_map.get("default", ""),
			"%s|%s|%s" % [category, key, user_id]
		)

	# 3）AOE 受擊：key = "skillId|state" 或 "state"
	elif category == "aoe_suffer":
		if key == "":
			return ""

		# 3-1️⃣ 先嘗試專屬 key（例如 "skill_xianglong18|ke"）
		var tone_group = cat_map.get(key, null)
		if tone_group != null:
			return _pick_weighted_text(
				tone_group.get(user_id, null),
				tone_group.get("default", ""),
				"%s|%s|%s" % [category, key, user_id]
			)

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
			return _pick_weighted_text(
				[],
				arr,
				"%s|default|%s|%s" % [category, state_name, user_id]
			)

		# 再不行就用 normal 頂著
		arr = default_group.get("normal", [])
		if typeof(arr) == TYPE_ARRAY and not arr.is_empty():
			return _pick_weighted_text(
				[],
				arr,
				"%s|default|normal|%s" % [category, user_id]
			)

		return ""

	# 3-1）我方攻擊敘事：依武器類型 key
	elif ["ally_attack", "ally_attack_aoe"].has(category):
		return _get_weapon_family_tone(category, key, user_id, true)

	# 3-2）敵方攻擊／受擊／倒地敘事：依 archetype key
	elif ["enemy_attack", "enemy_suffer", "enemy_defeat"].has(category):
		var group = cat_map.get(key, null)
		if group == null:
			group = cat_map.get("default", null)
		if group == null:
			return ""
		return _pick_weighted_text(
			group.get(user_id, null),
			group.get("default", ""),
			"%s|%s|%s" % [category, key, user_id]
		)

	# 4）其他（defend 等）：不吃 key，只看角色
	else:
		var specific_value = null
		if cat_map.has(user_id):
			specific_value = cat_map[user_id].get("default", "")
		var default_value = ""
		if cat_map.has("default"):
			default_value = cat_map["default"].get("default", "")
		if ["ally_dodge", "ally_enemy_defeat", "ally_down_self", "ally_down_reaction"].has(category):
			return get_character_tone_text(category, user_id)
		return _pick_weighted_text(
			specific_value,
			default_value,
			"%s|%s|%s|%s" % [category, key, user_id, side]
		)
	return ""


func get_character_tone_text(category: String, actor_id: String) -> String:
	if not tone_map.has(category):
		print("[ToneMap][character] category=%s raw_actor_id=%s resolved_actor_id=%s specific=false fallback=false result=missing_category" % [category, actor_id, actor_id])
		return ""
	var cat_map = tone_map[category]
	var resolved_actor_id := _canonicalize_character_tone_actor_id(actor_id)
	var specific_value = null
	var found_specific := false
	if resolved_actor_id != "" and cat_map.has(resolved_actor_id):
		specific_value = cat_map[resolved_actor_id].get("default", "")
		found_specific = not _normalize_text_pool(specific_value).is_empty()
	var default_value = ""
	if cat_map.has("default"):
		default_value = cat_map["default"].get("default", "")
	var used_fallback := not found_specific and not _normalize_text_pool(default_value).is_empty()
	print("[ToneMap][character] category=%s raw_actor_id=%s resolved_actor_id=%s specific=%s fallback=%s" % [
		category,
		actor_id,
		resolved_actor_id,
		str(found_specific),
		str(used_fallback)
	])
	return _pick_specific_then_default_text(
		specific_value,
		default_value,
		"%s|%s" % [category, resolved_actor_id]
	)


func _canonicalize_character_tone_actor_id(actor_id: String) -> String:
	var normalized := actor_id.strip_edges().to_lower()
	var alias_map := {
		"liu_yu": "liuyu",
		"liuyu": "liuyu",
		"su_mien": "shumian",
		"shu_mian": "shumian",
		"shumian": "shumian",
		"lie_shao": "lieshao",
		"liexiao": "lieshao",
		"lieshao": "lieshao",
	}
	if alias_map.has(normalized):
		return String(alias_map[normalized])
	return normalized


func get_ally_attack_text(weapon_type: String, user_id: String, is_aoe: bool = false) -> String:
	var normalized_weapon := weapon_type.strip_edges()
	if normalized_weapon == "":
		normalized_weapon = "default"

	if is_aoe:
		var aoe_line := _get_weapon_family_tone("ally_attack_aoe", normalized_weapon, user_id, false)
		if aoe_line != "":
			return aoe_line

	var single_line := _get_weapon_family_tone("ally_attack", normalized_weapon, user_id, false)
	if single_line != "":
		return single_line

	if is_aoe:
		var aoe_default := _get_weapon_family_tone("ally_attack_aoe", "default", user_id, true)
		if aoe_default != "":
			return aoe_default

	return _get_weapon_family_tone("ally_attack", "default", user_id, true)


func _get_weapon_family_tone(category: String, weapon_type: String, user_id: String, allow_default_fallback: bool) -> String:
	if not tone_map.has(category):
		return ""
	var cat_map = tone_map[category]
	var key := weapon_type if weapon_type != "" else "default"
	var group = cat_map.get(key, null)
	if group == null and allow_default_fallback:
		group = cat_map.get("default", null)
		key = "default"
	if group == null:
		return ""
	return _pick_weighted_text(
		group.get(user_id, null),
		group.get("default", ""),
		"%s|%s|%s" % [category, key, user_id]
	)


func _get_status_suffer_text(key: String) -> String:
	var effect_id := key
	var archetype := ""
	if key.find("|") != -1:
		var parts := key.split("|", false, 1)
		effect_id = str(parts[0])
		if parts.size() > 1:
			archetype = str(parts[1])
	if effect_id == "speed_debuff" or effect_id == "debuff_speed":
		effect_id = "slow"

	var effect_map = status_suffer_tones.get(effect_id, null)
	if typeof(effect_map) != TYPE_DICTIONARY:
		effect_map = status_suffer_tones.get("default", {})
	if typeof(effect_map) != TYPE_DICTIONARY:
		return ""

	if archetype != "":
		var archetype_value = null
		if effect_map.has(archetype):
			archetype_value = effect_map[archetype]
		var default_value = effect_map.get("江湖人士", effect_map.get("default", []))
		var archetype_line = _pick_weighted_text(
			archetype_value,
			default_value,
			"status_suffer|%s|%s" % [effect_id, archetype]
		)
		if archetype_line != "":
			return archetype_line

	if effect_map.has("default"):
		return _pick_weighted_text([], effect_map["default"], "status_suffer|%s|default" % effect_id)

	var default_map = status_suffer_tones.get("default", {})
	if typeof(default_map) == TYPE_DICTIONARY and default_map.has("default"):
		return _pick_weighted_text([], default_map["default"], "status_suffer|%s|fallback" % effect_id)
	return ""

func _pick_specific_then_default_text(specific_value, default_value, history_key: String) -> String:
	var specific_pool := _normalize_text_pool(specific_value)
	if not specific_pool.is_empty():
		return _pick_weighted_text(specific_pool, [], "%s|specific" % history_key)
	return _pick_weighted_text([], default_value, "%s|default" % history_key)


func _pick_weighted_text(specific_value, default_value, history_key: String) -> String:
	var specific_pool := _normalize_text_pool(specific_value)
	var default_pool := _normalize_text_pool(default_value)
	if specific_pool.is_empty() and default_pool.is_empty():
		return ""

	var last_line := str(_last_tone_pick_by_context.get(history_key, ""))
	var unique_lines := {}
	for line in specific_pool:
		unique_lines[str(line)] = true
	for line in default_pool:
		unique_lines[str(line)] = true
	if unique_lines.size() > 1 and last_line != "":
		specific_pool = specific_pool.filter(func(line): return str(line) != last_line)
		default_pool = default_pool.filter(func(line): return str(line) != last_line)

	var weights: Dictionary = {}
	var specific_weight := 0.0
	var default_weight := 0.0
	if not specific_pool.is_empty() and not default_pool.is_empty():
		specific_weight = SPECIFIC_POOL_WEIGHT
		default_weight = DEFAULT_POOL_WEIGHT
	elif not specific_pool.is_empty():
		specific_weight = 1.0
	elif not default_pool.is_empty():
		default_weight = 1.0

	for line in specific_pool:
		var key := str(line)
		weights[key] = float(weights.get(key, 0.0)) + (specific_weight / float(specific_pool.size()))
	for line in default_pool:
		var key := str(line)
		weights[key] = float(weights.get(key, 0.0)) + (default_weight / float(default_pool.size()))

	if weights.is_empty():
		var fallback_pool := _normalize_text_pool(specific_value)
		if fallback_pool.is_empty():
			fallback_pool = _normalize_text_pool(default_value)
		if fallback_pool.is_empty():
			return ""
		var fallback_line := str(fallback_pool[0])
		_last_tone_pick_by_context[history_key] = fallback_line
		return fallback_line

	var total_weight := 0.0
	for value in weights.values():
		total_weight += float(value)
	if total_weight <= 0.0:
		return ""

	var roll := randf() * total_weight
	var cumulative := 0.0
	for key in weights.keys():
		cumulative += float(weights[key])
		if roll <= cumulative:
			_last_tone_pick_by_context[history_key] = String(key)
			return String(key)

	var keys := weights.keys()
	var last_key := String(keys[keys.size() - 1])
	_last_tone_pick_by_context[history_key] = last_key
	return last_key

func _normalize_text_pool(value) -> Array:
	var out: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry in value:
			var text := str(entry).strip_edges()
			if text == "":
				continue
			out.append(text)
	elif value != null:
		var single := str(value).strip_edges()
		if single != "":
			out.append(single)
	return out

func _resolve_text_or_array(value) -> String:
	return _pick_weighted_text([], value, "legacy_resolve")



# 🩹 被擊中語氣挑選（依 side = "ally" / "enemy"）
func _get_hit_text(user_id: String, hit_kind: String, side: String) -> String:
	var branch := side
	if branch == "":
		branch = "ally"  # 預設當作我方

	if not hit_reactions.has(branch):
		return ""

	var side_map = hit_reactions[branch]
	var specific_map = side_map.get(user_id, null)
	var default_map = side_map.get("default", null)
	if specific_map == null and default_map == null:
		return ""

	var specific_group: Array = []
	if typeof(specific_map) == TYPE_DICTIONARY:
		match hit_kind:
			"weak":
				specific_group = specific_map.get("weak", [])
			"def_normal":
				specific_group = specific_map.get("def_normal", [])
			"def_weak":
				specific_group = specific_map.get("def_weak", [])
			_:
				specific_group = specific_map.get("normal", [])

	var default_group: Array = []
	if typeof(default_map) == TYPE_DICTIONARY:
		match hit_kind:
			"weak":
				default_group = default_map.get("weak", [])
			"def_normal":
				default_group = default_map.get("def_normal", [])
			"def_weak":
				default_group = default_map.get("def_weak", [])
			_:
				default_group = default_map.get("normal", [])

	return _pick_weighted_text(
		specific_group,
		default_group,
		"hit|%s|%s|%s" % [branch, user_id, hit_kind]
	)
