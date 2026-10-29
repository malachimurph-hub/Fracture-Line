class_name UnitIcons
## M3.3 Phase 4 (item 9): HUD icons for units and structures, rendered from the game's own models
## by tools/gfx_m33/icons.gd into res://ui/icons/<id>.png. Missing ids return null (text button).
static var _cache: Dictionary = {}

static func of(id: Variant) -> Texture2D:
	var k := String(id)
	if k == "":
		return null
	if _cache.has(k):
		return _cache[k]
	var p := "res://ui/icons/%s.png" % k
	var t: Texture2D = load(p) if ResourceLoader.exists(p) else null
	_cache[k] = t
	return t
