extends RefCounted
class_name SpecialItemUseHandler

const LIU_YU_BOOK_PORTRAIT = "res://assets/sprites/Liu_Yu/LiuYu_headshot.png"

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

func play_special_use_dialog(item_def: Dictionary, target) -> Dictionary:
	var event_id = str(item_def.get("special_use_event", ""))
	if event_id == "":
		return {"handled": false}
	var lines = _build_dialog_lines(event_id, target)
	if lines.is_empty():
		return {"handled": false}
	await _play_dialog_now(lines)
	return {
		"handled": true,
		"event_id": event_id,
	}

func _play_dialog_now(lines: Array) -> void:
	var tree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var dialog_manager = tree.root.get_node_or_null("GameRoot/DialogManager")
	if dialog_manager == null or not dialog_manager.has_method("show_dialog_sequence"):
		return
	var was_paused = tree.paused
	var prev_mode = dialog_manager.process_mode
	dialog_manager.process_mode = Node.PROCESS_MODE_ALWAYS
	if was_paused:
		tree.paused = false
	await dialog_manager.show_dialog_sequence(lines)
	dialog_manager.process_mode = prev_mode
	if was_paused:
		tree.paused = true

func _build_dialog_lines(event_id: String, target) -> Array:
	var portrait_path = LIU_YU_BOOK_PORTRAIT
	if target != null and typeof(target) == TYPE_DICTIONARY:
		portrait_path = str((target as Dictionary).get("portrait_path", LIU_YU_BOOK_PORTRAIT))
	if portrait_path == "":
		portrait_path = LIU_YU_BOOK_PORTRAIT
	match event_id:
		"book_reading_lamp_whisper":
			return [
				{ "text": "你翻開《燈後微聲》，紙頁很薄，像怕驚動夜色似的。", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "書頁上只寫著短短幾行：", "speaker": 1, "portrait": portrait_path },
				{ "text": "《燈後微聲》｜書眠著\n\n燈後人未睡，影薄貼窗紗。\n欲把心頭事，收成指上沙。\n一語若能出，未必驚天下。\n只怕無人問，輕輕也作啞。", "speaker": 1, "portrait": portrait_path },
				{ "text": "(你將那幾行字重看了一遍。)", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵：「……奇怪，明明只是幾句短詩，卻像有人替我把那口氣慢慢順出來了。」", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵：「原來有些說不出口，不是因為它不夠重；恰恰是因為它太輕、太貼近心口，一碰就散。」", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵靜了一會，將書頁輕輕合上。", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "你對那些難以言明的細微情緒，似乎看得更清楚了一些。\n【智慧 +5】", "speaker": 0, "portrait": "" },
			]
		"book_reading_eaves_echo":
			return [
				{ "text": "你翻開《簷聲未盡》，頁角還留著淡淡潮氣，像是剛從一場雨裡收回來。", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "書頁中夾著一首小詩：", "speaker": 1, "portrait": portrait_path },
				{ "text": "《簷聲未盡》｜書眠著\n\n簷前一滴遲，未落已成音。\n人行街角外，燈在水痕深。\n若問微光處，原來早可尋。\n只是心太急，不曾側耳聽。", "speaker": 1, "portrait": portrait_path },
				{ "text": "(你望著最後一句，目光停了停。)", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵：「不是世上沒有徵兆，只是人一旦走得太急，連命運擦肩的聲音都聽不見。」", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵：「……若能多看一眼，多停一瞬，也許原本錯過的東西，就不會那麼容易從手邊漏掉。」", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "你將書收起時，忽然覺得四周那些細碎的光點，比方才更容易映入眼中了。", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "你對細微徵兆與偶然相逢的感知，似乎靈敏了些。\n【幸運 +5】", "speaker": 0, "portrait": "" },
			]
		"book_reading_ink_unfallen":
			return [
				{ "text": "你翻開《未落之墨》，紙上沒有太多修辭，只有一段靜靜鋪開的短文。", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "《未落之墨》｜書眠著\n\n人多看重落筆之後的形，卻少有人停在落筆之前。\n筆尖將觸未觸之時，字尚未生，意卻已滿。\n那一瞬若有遲疑，字便散；若有決意，紙未受墨，氣先入骨。\n真正有力的，不在寫成之後，而在不肯草率落下的那一刻。", "speaker": 1, "portrait": portrait_path },
				{ "text": "(你下意識望向自己的手。)", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵：「……原來筆意不是把力道全摔出去。」", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵：「而是先把心神收住，讓那一下真正有去處。」", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "你合上書冊，胸中那股將發未發的力道，竟比平時更沉、更穩。", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "你對筆意出手前的收束與決意，有了更深一層的領會。\n【筆意傷害提升】", "speaker": 0, "portrait": "" },
			]
		"book_reading_breath_beyond_words":
			return [
				{ "text": "你翻開《字外有息》，發現這一頁比其他頁都留了更多空白。", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "《字外有息》｜書眠著\n\n人以為字能盡意，故見鋒便懼，見重便傷。\n其實字有盡處，意亦有息。\n若只盯著紙上墨痕，便容易忘了：寫字之人，總有未寫之處；讀字之人，也該有不必全然承受的地方。\n能在字外替自己留一口氣，便不至於被他人的筆意全數帶走。", "speaker": 1, "portrait": portrait_path },
				{ "text": "(你沉默片刻，指尖輕輕拂過那片空白。)", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵：「……是啊。不是每一句重話，我都非得把它吃進去不可。」", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "劉語塵：「若懂得在字外替自己留一步，旁人的筆意再深，也未必能直入心口。」", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "你將書頁闔上時，忽然覺得胸口那道看不見的邊界，比方才分明了一些。", "speaker": 2, "portrait": LIU_YU_BOOK_PORTRAIT },
				{ "text": "你對筆意侵襲的承受方式，似乎穩住了幾分。\n【筆意抗性提升】", "speaker": 0, "portrait": "" },
			]
		_:
			return []
