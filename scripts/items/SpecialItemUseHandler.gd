extends RefCounted
class_name SpecialItemUseHandler

const LIU_YU_BOOK_PORTRAIT = "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"
const SHU_MIAN_BOOK_PORTRAIT = "res://assets/sprites/NPC/Yuheng/Su_Mien_headshot2.png"
const LIE_XIAO_BOOK_PORTRAIT = "res://assets/sprites/NPC/LieFong/LieShao_headshot2.png"

const BOOK_EVENT_BY_ITEM_ID = {
	"book_poem_a_int": "book_reading_lamp_whisper",
	"book_poem_b_luck": "book_reading_eaves_echo",
	"book_essay_c_pen_up": "book_reading_ink_unfallen",
	"book_essay_d_pen_resist": "book_reading_breath_beyond_words",
}

func can_handle_item(item_def: Dictionary) -> bool:
	var event_id = str(item_def.get("special_use_event", ""))
	return event_id != ""

func get_read_flag(item_id: String) -> String:
	return "book_read_%s" % item_id

func should_play_special_use_dialog(item_id: String, item_def: Dictionary) -> bool:
	if not can_handle_item(item_def):
		return false
	var first_time_only = bool(item_def.get("special_use_first_time_only", false))
	if not first_time_only:
		return true
	if GlobalState and GlobalState.has_method("get_flag"):
		return not bool(GlobalState.get_flag(get_read_flag(item_id)))
	return true

func play_special_use_dialog(item_def: Dictionary, target) -> Dictionary:
	var event_id = str(item_def.get("special_use_event", ""))
	if event_id == "":
		return {"handled": false}
	var lines = _build_dialog_lines(event_id, target)
	if lines.is_empty():
		return {"handled": false}
	var played := bool(await _play_dialog_now(lines))
	return {
		"handled": played,
		"event_id": event_id,
	}

func play_foreground_sequence(lines: Array) -> void:
	if lines.is_empty():
		return
	await _play_dialog_now(lines)

func get_walnut_fail_dialog_lines() -> Array:
	return [
		{
			"text": "面紅耳赤的捏著胡桃，但即使雙手通紅，胡桃仍然無動於衷。",
			"speaker": 0,
			"portrait": "res://assets/sprites/empty.png",
		}
	]

func _play_dialog_now(lines: Array) -> bool:
	var tree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var dialog_manager = tree.root.get_node_or_null("GameRoot/DialogManager")
	if dialog_manager == null or not dialog_manager.has_method("show_dialog_sequence"):
		return false
	if bool(dialog_manager.get("dialog_active")):
		return false
	var prev_mode = dialog_manager.process_mode
	var had_layer = false
	var prev_layer = 0
	if dialog_manager is CanvasLayer:
		had_layer = true
		prev_layer = int((dialog_manager as CanvasLayer).layer)
		(dialog_manager as CanvasLayer).layer = 2000
	dialog_manager.process_mode = Node.PROCESS_MODE_ALWAYS
	dialog_manager.set_process_unhandled_input(true)
	await dialog_manager.show_dialog_sequence(lines)
	dialog_manager.process_mode = prev_mode
	if had_layer:
		(dialog_manager as CanvasLayer).layer = prev_layer
	return true

func _build_dialog_lines(event_id: String, target) -> Array:
	var actor_key = _resolve_actor_dialog_key(target)
	match event_id:
		"tea_tasting_drunk_moon_qingkui":
			return _build_tea_tasting_drunk_moon_qingkui(actor_key)
		"tea_tasting_brush_mist_newbud":
			return _build_tea_tasting_brush_mist_newbud(actor_key)
		"tea_tasting_deep_roast_chenxiang":
			return _build_tea_tasting_deep_roast_chenxiang(actor_key)
		"tea_snack_delicate_su":
			return _build_tea_snack_delicate_su(actor_key)
		"book_reading_lamp_whisper":
			return _build_book_reading_lamp_whisper(actor_key)
		"book_reading_eaves_echo":
			return _build_book_reading_eaves_echo(actor_key)
		"book_reading_ink_unfallen":
			return _build_book_reading_ink_unfallen(actor_key)
		"book_reading_breath_beyond_words":
			return _build_book_reading_breath_beyond_words(actor_key)
		_:
			return []

func _resolve_actor_dialog_key(target) -> String:
	if target == null or typeof(target) != TYPE_DICTIONARY:
		return "liuyu"
	var d = target as Dictionary
	var actor_id = str(d.get("id", d.get("actor_id", ""))).strip_edges()
	if actor_id == "":
		return "liuyu"
	return actor_id

func _build_tea_tasting_drunk_moon_qingkui(actor_key: String) -> Array:
	match actor_key:
		"lieshao", "liexiao":
			return [
				{ "text": "列霄端起《醉月青魁》，先沒急著喝，只低頭看了一眼那過分\n清亮的茶色。", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "《醉月青魁》\n   回甘不苦澀，提神不擾眠。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "(列霄啜了一口，眉頭原本還壓著，過了片刻，卻沒立刻放下茶盞。)", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄：「……本來以為這種名字，多半只是好聽。」", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄：「倒是沒想到它不搶味，卻能在後勁上慢慢纏住人。」", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄：「不像那些硬把人提起來的藥茶……這種，反倒像是在\n你亂的時候，逼你自己把氣重新收回來。」", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄把茶飲盡時，胸口那股原本微亂的氣息，似乎已被這點\n清苦後的回甘慢慢理順。", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄在茶湯餘韻之中穩住了心神。\n【回復內力】", "speaker": 0, "portrait": "res://assets/sprites/empty.png" },
			]
		"shumian":
			return [
				{ "text": "書眠端起《醉月青魁》，茶湯仍舊清亮，映著杯壁時，\n像月色被人安安靜靜地捧在掌心。", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "《醉月青魁》\n   回甘不苦澀，提神不擾眠。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "(書眠低頭啜了一口，茶氣先清，回甘卻慢，\n像熟人沒有立刻出聲，只先輕輕坐到你身旁。)", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "書眠：「……還是這樣啊。」", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "書眠：「明明入口很靜，偏偏回甘總比人預想的\n還久一點。」", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "書眠：「若不是泡茶的人懂得收手，製茶的人也肯\n把火候留白，它就不會停得這麼剛好。」", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "書眠將杯中餘茶慢慢飲盡，忽然覺得胸口那股原本\n細碎的思緒，也被這點回甘一縷一縷理順了。", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "書眠在熟悉的茶韻之中，再次穩住了心神。\n【回復內力】", "speaker": 0, "portrait": "res://assets/sprites/empty.png" },
			]
		_:
			return [
				{ "text": "你端起《醉月青魁》，茶湯清亮，月色似乎也在杯中\n輕輕晃了一下。", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "《醉月青魁》\n   回甘不苦澀，提神不擾眠。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "(你先啜了一口，茶氣清而不薄，滑過喉間後，\n竟還留著一縷安靜的甜。)", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵：「……這茶不急著把人叫醒，倒像是在等你\n自己慢慢清明過來。」", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵：「若不是泡茶的人手穩，製茶的人心也穩，\n這股回甘不會停得這麼久。」", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "你將餘茶飲盡，只覺原本散亂的思緒一點一點重新收攏，\n內息也隨之平順了些。", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "你在茶湯的回甘之中穩住了心神。\n【回復內力】", "speaker": 0, "portrait": "res://assets/sprites/empty.png" },
			]

func _build_tea_tasting_brush_mist_newbud(actor_key: String) -> Array:
	match actor_key:
		"lieshao", "liexiao":
			return [
				{ "text": "列霄揭開《拂霧新芽》的茶蓋，清氣一下逸出來，輕得\n幾乎讓人覺得沒什麼分量。", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "《拂霧新芽》\n   茶氣清揚，如晨風拂霧。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "(列霄喝下一口，舌尖先覺得淡，等那股清氣真正散開，\n肩背卻比方才鬆了許多。)", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄：「……還真是輕。」", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄：「輕得像沒下手，偏偏等列霄回過神時，那點沉悶\n已經被它掀走了。」", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄：「哼，這種東西要是真拿去趕路，大概比那些只會\n嗆喉嚨的烈茶有用得多。」", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄放下茶盞，原本略顯滯重的身子似乎輕快了些，\n連呼吸都比方才俐落。", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄覺得身法似乎變得更輕快了。\n【敏捷 +5】", "speaker": 0, "portrait": "res://assets/sprites/empty.png" },
			]
		"shumian":
			return [
				{ "text": "書眠揭開《拂霧新芽》的茶蓋，清氣輕輕浮起，\n像一小段久違的晨色先一步落在眼前。", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "《拂霧新芽》\n   茶氣清揚，如晨風拂霧。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "(書眠飲下一口，只覺那股輕意不是浮，而是很細地\n把身上的遲滯一點點拂開。)", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "書眠：「這茶總讓人想起，原來有些沉重不是非得硬扛……\n也可以慢慢散。」", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "書眠：「像清晨一到，霧沒有被誰打碎，只是自己退開了。」", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "書眠把茶盞捧在掌中，肩背間那股原本貼得太緊的悶意，\n似乎也跟著鬆開了些。", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "書眠覺得身心都比方才輕快了些。\n【敏捷 +5】", "speaker": 0, "portrait": "res://assets/sprites/empty.png" },
			]
		_:
			return [
				{ "text": "你揭開《拂霧新芽》的茶蓋，清氣先一步浮了起來，\n像晨間山道尚未散盡的薄霧。", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "《拂霧新芽》\n   茶氣清揚，如晨風拂霧。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "(你低頭飲下一口，只覺胸口一亮，連肩背都鬆開了些。)", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵：「……原來身子發滯時，不一定是氣不夠，\n也可能只是心口積了太多霧。」", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵：「這一口下去，倒像有人替我把多餘的遲滯\n都輕輕拂開了。」", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "茶氣入腹後，你只覺步履與呼吸都比方才更輕了一些，\n整個人像被晨風吹醒。", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "你的身法似乎變得更輕快了。\n【敏捷 +5】", "speaker": 0, "portrait": "res://assets/sprites/empty.png" },
			]

func _build_tea_tasting_deep_roast_chenxiang(actor_key: String) -> Array:
	match actor_key:
		"lieshao", "liexiao":
			return [
				{ "text": "列霄捧起《深焙沉香》，茶色厚，香氣也沉，還沒入口，\n便先有一股穩重的暖意壓了下來。", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "《深焙沉香》\n   火候沉穩，餘香不散。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "(列霄喝下一口，起初只覺得它不急不躁，待茶湯落進胸腹，\n那股厚實才慢慢顯出來。)", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄：「這倒像樣。」", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄：「不花俏，也不討巧，可只要喝進去，整個人就像\n被它從裡頭墊住了。」", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄：「比起那些只求入口討喜的東西，這種慢慢壓下去的勁，\n反而更禁得住。」", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄把茶盞放下時，只覺原本有些浮散的勁道，似乎被這股溫厚\n穩穩收了回來。", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄在溫厚茶氣之中，把底氣重新養了回來。\n【體能 +5】", "speaker": 0, "portrait": "res://assets/sprites/empty.png" },
			]
		"shumian":
			return [
				{ "text": "書眠捧起《深焙沉香》，茶色厚而不沉，尚未入口時，\n便有一縷暖意先自杯口慢慢落了下來。", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "《深焙沉香》\n   火候沉穩，餘香不散。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "(書眠飲下一口，起初只覺得安靜，待茶湯真正落進胸腹，\n才發現那股暖意已經悄悄墊住了整個人。)", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "書眠：「……它不急著討人喜歡。」", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "書眠：「可是只要肯慢一點喝，就會明白，有些厚實本來\n就不是一入口就能讓人發覺的。」", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "書眠將茶盞放下時，只覺原本浮在身上的那層虛氣，\n似乎被這份沉厚穩穩接住了。", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "書眠在溫厚的茶氣之中，把將散未散的底氣重新養了回來。\n【體能 +5】", "speaker": 0, "portrait": "res://assets/sprites/empty.png" },
			]
		_:
			return [
				{ "text": "你捧起《深焙沉香》，茶色較深，未入口前，先有一股\n暖厚的氣息沉沉落了下來。", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "《深焙沉香》\n   火候沉穩，餘香不散。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "(你飲下一口，初時不覺驚豔，待茶湯入喉，\n暖意卻緩緩沉進胸腹，久久不退。)", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵：「這茶倒不搶先出頭……可一旦咽下去，\n便像在身子裡慢慢墊起一層底氣。」", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵：「不是一下叫人振作，而是讓那口快散掉的氣，\n重新有地方落下來。」", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "你把茶盞放下時，只覺筋骨間那股原本虛浮的勁道，\n似乎被這份溫厚慢慢養實了。", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "你的體魄似乎穩健了幾分。\n【體能 +5】", "speaker": 0, "portrait": "res://assets/sprites/empty.png" },
			]

func _build_tea_snack_delicate_su(actor_key: String) -> Array:
	match actor_key:
		"lieshao", "liexiao":
			return [
				{ "text": "列霄拈起一枚《玲瓏酥》，先看了兩眼，像是有些懷疑\n這種小東西到底能有多少份量。", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "《玲瓏酥》\n   一口大小，最宜收拾將散未散的心神。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "(列霄咬下一口，酥皮一碎，甜香卻不膩，意外地沒有\n那種會讓人心煩的黏滯感。)", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄：「……倒比看起來強。」", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄：「本來以為這種點心只中看，沒想到還真能把\n快散掉的氣力兜住一點。」", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄：「也好，至少不是那種只會塞飽肚子、卻半點\n用也沒有的花架子。」", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄將最後一點酥屑拂去，原本有些發空的身子似乎\n也被這一口甜香稍稍補了回來。", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄重新攏住了幾分將散的氣力。\n【回復生命】", "speaker": 0, "portrait": "res://assets/sprites/empty.png" },
			]
		"shumian":
			return [
				{ "text": "書眠取出一枚《玲瓏酥》，酥皮做得細，小小一口，\n卻像把茶席最後那點未說盡的心意留在了手上。", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "《玲瓏酥》\n   一口大小，最宜收拾將散未散的心神。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "(書眠輕輕咬下一口，甜香不膩，碎屑落得很輕，\n倒像在替人把那些散掉的氣力一點點攏回來。)", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "書眠：「點心若做得太滿，反而留不住人。」", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "書眠：「這樣剛好……不會一下把空缺填平，卻能讓原本\n漏風的地方慢慢收住。」", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "書眠把最後一點酥屑拂去，只覺疲乏沒有立刻消散，\n卻也不再像方才那樣鬆散得四處見縫。", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "書眠重新攏住了幾分將散的氣力。\n【回復生命】", "speaker": 0, "portrait": "res://assets/sprites/empty.png" },
			]
		_:
			return [
				{ "text": "你取出一枚《玲瓏酥》，點心不大，邊角卻做得很細，\n像是專為茶席留住餘韻而生。", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "《玲瓏酥》\n   一口大小，最宜收拾將散未散的心神。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "(你輕咬一口，酥皮先碎，甜香卻不膩，像是正好替\n疲乏的身子補上一點剛好的氣力。)", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵：「……這點心倒有意思，不是一下把人填滿，\n而是把散掉的那幾分精神重新攏回來。」", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵：「若是手腳還跟得上、氣息也未亂透，\n這一口下去，確實比想像中更能續得住。」", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "你將最後一點酥屑拂去，只覺疲乏沒有立刻散盡，\n卻已不像方才那樣四處漏風。", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "你重新攏住了幾分將散的氣力。\n【回復生命】", "speaker": 0, "portrait": "res://assets/sprites/empty.png" },
			]

func _build_book_reading_lamp_whisper(actor_key: String) -> Array:
	match actor_key:
		"lieshao", "liexiao":
			return [
				{ "text": "列霄把《燈後微聲》翻開，才看兩行，眉頭便先皺了一下。", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "《燈後微聲》｜書眠著", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "   燈後人未睡，影薄貼窗紗。\n   欲把心頭事，收成指上沙。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "   一語若能出，未必驚天下。\n   只怕無人問，輕輕也作啞。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "(列霄盯著最後一句，半晌沒翻頁。)", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄：「……寫得倒是挺秀氣。」", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄：「可越是這種輕的東西，越容易叫人避不開。」", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄：「說不出口的，未必是因為話太重。有時候偏偏是因為它\n太貼身，一開口就像在承認什麼。」", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄把書闔上，動作不重，卻比方才多停了一會。", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄對那些藏得太近、反而最難說出口的情緒，似乎看清了一些。\n【智慧 +5】", "speaker": 0, "portrait": "res://assets/sprites/empty.png" },
			]
		"shumian":
			return [
				{ "text": "書眠翻開《燈後微聲》，紙頁輕薄得像是會被呼吸驚動。", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "《燈後微聲》｜書眠著", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "   燈後人未睡，影薄貼窗紗。\n   欲把心頭事，收成指上沙。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "   一語若能出，未必驚天下。\n   只怕無人問，輕輕也作啞。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "書眠：（輕聲）「原來有些句子，不是寫給旁人看的……\n而是怕自己有一日，再也聽不見心裡那點聲音。」", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "書眠把書頁闔上時，神色比方才更安定了些。", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "書眠對那些難以言明的細微情緒，似乎看得更清楚了一些。\n【智慧 +5】", "speaker": 0, "portrait": "res://assets/sprites/empty.png" },
			]
		_:
			return [
				{ "text": "你翻開《燈後微聲》，紙頁很薄，像怕驚動夜色似的。", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "書頁上只寫著短短幾行：", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "《燈後微聲》｜書眠著", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "   燈後人未睡，影薄貼窗紗。\n   欲把心頭事，收成指上沙。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "   一語若能出，未必驚天下。\n   只怕無人問，輕輕也作啞。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "(你將那幾行字重看了一遍。)", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵：「……奇怪，明明只是幾句短詩，卻像有人替我把\n那口氣慢慢順出來了。」", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵：「原來有些話無法言喻，不是因為它無關緊要；\n恰恰是因為它太輕、太貼近心頭，一開口便容易誤認為矯情。」", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵靜了一會，將書頁輕輕合上。", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "你對那些難以言明的細微情緒，似乎看得更清楚了一些。\n【智慧 +5】", "speaker": 0, "portrait": "res://assets/sprites/empty.png" },
			]

func _build_book_reading_eaves_echo(actor_key: String) -> Array:
	match actor_key:
		"lieshao", "liexiao":
			return [
				{ "text": "列霄翻開《簷聲未盡》，紙頁微涼，像真沾過一場還沒\n退乾淨的夜雨。", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "《簷聲未盡》｜書眠著", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "   簷前一滴遲，未落已成音。\n   人行街角外，燈在水痕深", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "   若問微光處，原來早可尋。\n   只是心太急，不曾側耳聽。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "(列霄讀到「只是心太急」，唇角動了動，像是想嗤一聲，\n最後卻沒出聲。)", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄：「……哼，倒像是在說教。」", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄：「可人一旦走快了，確實什麼都懶得細看。\n等真錯過了，又只會怪路不對、怪時運不好。」", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄：「若真能多停一步，也許有些本來要漏掉的東西，\n還能來得及收回來。」", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄把書收起時，目光不自覺往四周多掃了一眼。", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄對那些細微徵兆與稍縱即逝的機會，似乎更敏銳了。\n【幸運 +5】", "speaker": 0, "portrait": "res://assets/sprites/empty.png" },
			]
		"shumian":
			return [
				{ "text": "書眠翻開《簷聲未盡》，頁角微卷，像被舊雨聲輕輕沾過。", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "《簷聲未盡》｜書眠著", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "   簷前一滴遲，未落已成音。\n   人行街角外，燈在水痕深。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "   若問微光處，原來早可尋。\n   只是心太急，不曾側耳聽。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "書眠：「我總怕自己寫得太滿，便替旁人把那一瞬的回音\n也說死了。」", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "書眠：「幸好，雨聲還在。人若肯慢一點，還是能聽見。」", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "書眠對細微徵兆與偶然相逢的感知，似乎靈敏了些。\n【幸運 +5】", "speaker": 0, "portrait": "res://assets/sprites/empty.png" },
			]
		_:
			return [
				{ "text": "你翻開《簷聲未盡》，頁角還留著淡淡潮氣，像是剛從\n一場雨裡收回來。", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "書頁中夾著一首小詩：", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "《簷聲未盡》｜書眠著", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "   簷前一滴遲，未落已成音。\n   人行街角外，燈在水痕深。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "   若問微光處，原來早可尋。\n   只是心太急，不曾側耳聽。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "(你望著最後一句，目光停了停。)", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵：「不是世上沒有徵兆，只是人一旦走得太急，\n連命運擦肩的聲音都聽不見。」", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵：「……若能多看一眼，多停一瞬，也許原本\n錯過的東西，就不會那麼容易從手邊漏掉。」", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "你將書收起時，忽然覺得四周那些細碎的光點，比方才\n更容易映入眼中了。", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "你對細微徵兆與偶然相逢的感知，似乎靈敏了些。\n【幸運 +5】", "speaker": 0, "portrait": "res://assets/sprites/empty.png" },
			]

func _build_book_reading_ink_unfallen(actor_key: String) -> Array:
	match actor_key:
		"lieshao", "liexiao":
			return [
				{ "text": "列霄翻開《未落之墨》，才掃過幾行，眼神便沉了下來。", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "《未落之墨》｜書眠著", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "人多看重落筆之後的形，卻少有人停在落筆之前。\n筆尖將觸未觸之時，字尚未生，意卻已滿。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "那一瞬若有遲疑，字便散；若有決意，紙未受墨，氣先入骨。\n真正有力的，不在寫成之後，而在不肯草率落下的那一刻。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "(列霄看著「不肯草率落下」那一句，手指下意識收緊。)", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄：「……這句倒像回事。」", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄：「出手若只是圖個快，力道一下就散了。真正能傷人的，\n往往不是那一下砸出去的狠，而是砸出去之前，心裡已經不退了。」", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄：「原來筆也一樣。」", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄把書闔上時，胸口那股原本外放的勁，反而收得比方才更穩。", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄對筆類型招式出手前的收束與決意，有了更深一層的把握。\n【筆類型傷害提升】", "speaker": 0, "portrait": "res://assets/sprites/empty.png" },
			]
		"shumian":
			return [
				{ "text": "書眠翻開《未落之墨》，目光停在那段她最熟悉的句子上。", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "《未落之墨》｜書眠著", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "人多看重落筆之後的形，卻少有人停在落筆之前。\n筆尖將觸未觸之時，字尚未生，意卻已滿。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "那一瞬若有遲疑，字便散；若有決意，紙未受墨，\n氣先入骨。真正有力的，不在寫成之後，而在不肯\n草率落下的那一刻。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "書眠：（低聲）「寫字是這樣，出手也是。真正會傷人的，\n從來都不是聲勢最大的一筆。」", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "書眠輕輕收指，像把將落未落的筆意重新穩住。", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "書眠對筆術式出手前的收束與決意，有了更深一層的領會。\n【筆類型傷害提升】", "speaker": 0, "portrait": "res://assets/sprites/empty.png" },
			]
		_:
			return [
				{ "text": "你翻開《未落之墨》，紙上沒有太多修辭，只有一段\n靜靜鋪開的短文。", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "《未落之墨》｜書眠著", "speaker": 1, "portrait": "" },
				{ "text": "人多看重落筆之後的形，卻少有人停在落筆之前。\n筆尖將觸未觸之時，字尚未生，意卻已滿。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "那一瞬若有遲疑，字便散；若有決意，紙未受墨，\n氣先入骨。真正有力的，不在寫成之後，而在不肯\n草率落下的那一刻。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "(你下意識望向自己的手。)", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵：「……原來筆意不是把力道全摔出去。」", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵：「而是先把心神收住，讓那一下真正有去處。」", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "你合上書冊，胸中那股將發未發的力道，竟比平時更沉、\n更穩。", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "你對筆術式出手前的收束與決意，有了更深一層的領會。\n【筆類型傷害提升】", "speaker": 0, "portrait": "res://assets/sprites/empty.png" },
			]

func _build_book_reading_breath_beyond_words(actor_key: String) -> Array:
	match actor_key:
		"lieshao", "liexiao":
			return [
				{ "text": "列霄翻開《字外有息》，才看見那大片空白，便先皺了皺眉。", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "《字外有息》｜書眠著", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "人以為字能盡意，故見鋒便懼，見重便傷。其實字有盡處，\n意亦有息。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "若只盯著紙上墨痕，便容易忘了：寫字之人，總有未寫之處；\n讀字之人，也該有不必全然承受的地方。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "能在字外替自己留一口氣，便不至於被他人的筆意全數帶走。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "(列霄看完最後一句，沉默了一會。)", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄：「……說得倒輕巧。」", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄：「可真把什麼都往心口收，最後先垮的只會是自己。」", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄：「若懂得留一步，不是示弱，是免得旁人的字還沒傷完，\n你自己先把自己耗乾了。」", "speaker": 2, "portrait": LIE_XIAO_BOOK_PORTRAIT },
				{ "text": "列霄把書頁闔上，呼吸也比方才沉了一些，像是替自己守住了那條\n不必退讓太多的邊界。\n【筆類型招式抗性提升】", "speaker": 0, "portrait": "res://assets/sprites/empty.png" },
			]
		"shumian":
			return [
				{ "text": "書眠翻開《字外有息》，這一頁的空白仍像當初那樣安靜。", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "《字外有息》｜書眠著", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "人以為字能盡意，故見鋒便懼，見重便傷。其實字有盡處，\n意亦有息。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "若只盯著紙上墨痕，便容易忘了：寫字之人，總有未寫之處；", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "讀字之人，也該有不必全然承受的地方。能在字外替自己\n留一口氣，便不至於被他人的筆意全數帶走。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "書眠：「若我寫下的字曾讓人窒息……那麼至少，\n我希望它也能留下一道能呼吸的縫。」", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "書眠指尖在空白處輕點一下，像替誰留了一步退路。", "speaker": 2, "portrait": SHU_MIAN_BOOK_PORTRAIT },
				{ "text": "書眠對筆術式侵襲的承受方式，似乎穩住了幾分。\n【筆類型招式抗性提升】", "speaker": 0, "portrait": "res://assets/sprites/empty.png" },
			]
		_:
			return [
				{ "text": "你翻開《字外有息》，發現這一頁比其他頁都留了更多空白。", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "《字外有息》｜書眠著", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "人以為字能盡意，故見鋒便懼，見重便傷。\n其實字有盡處，意亦有息。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "若只盯著紙上墨痕，便容易忘了：寫字之人，總有未寫之處；", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "讀字之人，也該有不必全然承受的地方。能在字外替自己\n留一口氣，便不至於被他人的筆意全數帶走。", "speaker": 1, "portrait": "res://assets/sprites/empty.png" },
				{ "text": "(你沉默片刻，指尖輕輕拂過那片空白。)", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵：「……是啊。不是每一句重話，我都非得把它\n吃進去不可。」", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵：「若懂得在字外替自己留一步，旁人的筆意再深，\n也未必能直入心口。」", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "你將書頁闔上時，忽然覺得胸口那道看不見的邊界，比方才\n分明了一些。", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "你對筆術式侵襲的承受方式，似乎穩住了幾分。\n【筆類型招式抗性提升】", "speaker": 0, "portrait": "res://assets/sprites/empty.png" },
			]
