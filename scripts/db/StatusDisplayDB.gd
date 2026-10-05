extends RefCounted
## Display data of battle statuses that is NOT derived from the status id alone: a name shown to the player and the
## key of the icon to use. Everything else falls back to the id (icon file `status_<id>.png`, name from the UI).
##
## 魘鱗護體 is the shield the 墨鱗魘將 puts on itself (internal id `yumei_entanglement`, kept so the accepted Phase
## Break logic and tests are untouched). Its icon is NOT a boss-only icon: any strong guard / invulnerability /
## protective-body effect of another boss or story move may share it. The existing `status_yumei_entanglement.png` is
## a separate DEBUFF icon "語魅纏身" that is kept and deliberately bound to nothing here.

const GUARD_BARRIER_NAME := "魘鱗護體"
## Icon of the shared "strong guard" effect. The art is still to come: until the file exists the status is shown
## by its fallback (nothing / text), never by the debuff icon.
const GUARD_BARRIER_ICON := "status_guard_barrier"

const OVERRIDES: Dictionary = {
	"yumei_entanglement": {"name": GUARD_BARRIER_NAME, "icon": GUARD_BARRIER_ICON, "kind": "guard"},
}


static func display_name(status_id: String, fallback: String = "") -> String:
	return String((OVERRIDES.get(status_id, {}) as Dictionary).get("name", fallback))


## Icon key (file name without extension) for a status id; `status_<id>` unless overridden.
static func icon_key(status_id: String) -> String:
	return String((OVERRIDES.get(status_id, {}) as Dictionary).get("icon", "status_%s" % status_id))


## "guard" for a protective effect, "" for ordinary statuses (which are told apart by buff / debuff elsewhere).
static func kind(status_id: String) -> String:
	return String((OVERRIDES.get(status_id, {}) as Dictionary).get("kind", ""))
