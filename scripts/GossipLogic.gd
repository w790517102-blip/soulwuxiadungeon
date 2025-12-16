# file: GossipLogic.gd
extends Node

static func check_triggered(topic: String) -> bool:
	if topic == "":
		return false

	var flags := [
		"heard_oldman_%s" % topic,
		"heard_wanderoldman_%s" % topic,
		"heard_waterwoman_%s" % topic
	]

	return flags.all(GlobalState.get_flag) and not GlobalState.get_flag("triggered_%s_gossip_summary" % topic)

static func trigger_summary(topic: String) -> Array:
	GlobalState.set_flag("triggered_%s_gossip_summary" % topic, true)
	match topic:
		"zuoyin":
			return [
				{ "text": "原來左飲是這樣的人啊...", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "看來如果要贏得他認可，我必須要親自登門拜訪他一趟。", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" }
			]
		"teashop":
			return [
				{ "text": "這琴聲...不是單純的音律，像是在引導情緒沉澱。", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" },
				{ "text": "看來我得進去看看，是誰在彈這首曲子。", "speaker": 2, "portrait": "res://assets/sprites/Liu_Yu/LiuYu_headshot.png" }
			]
		_:
			return []
