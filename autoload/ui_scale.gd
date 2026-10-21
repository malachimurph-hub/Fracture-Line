extends Node
## DPI-aware UI scale. 1 logical UI unit == 1 dp (Android density-independent pixel).
## Android: dp = densityDpi / 160. Desktop/web: scaled from window height so the layout
## matches a ~420 dp tall landscape phone. Multiplied by the user's UI scale setting.
signal changed
var dp: float = 1.0
var safe_rect: Rect2 = Rect2()   ## safe area in logical units (cutouts, gesture bar)

func _ready() -> void:
	get_tree().root.size_changed.connect(_recompute)
	EventBus.settings_changed.connect(_recompute)
	_recompute.call_deferred()

func is_mobile() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios")

func _recompute() -> void:
	var win := get_tree().root
	var size := Vector2(win.size)
	if size.x <= 0:
		return
	var base: float
	if OS.has_feature("android") or OS.has_feature("ios"):
		base = DisplayServer.screen_get_dpi() / 160.0
	else:
		base = maxf(1.0, size.y / 420.0)
	dp = maxf(0.5, base * float(Settings.g("ui_scale")))
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_size = Vector2i(int(size.x / dp), int(size.y / dp))
	win.content_scale_factor = 1.0
	var sa := Rect2(DisplayServer.get_display_safe_area())
	var win_pos := Vector2(DisplayServer.window_get_position())
	if sa.size.x <= 0 or not (OS.has_feature("android") or OS.has_feature("ios")):
		safe_rect = Rect2(Vector2.ZERO, size / dp)
	else:
		safe_rect = Rect2((sa.position - win_pos) / dp, sa.size / dp).intersection(Rect2(Vector2.ZERO, size / dp))
	changed.emit()

func logical_size() -> Vector2:
	return Vector2(get_tree().root.content_scale_size)

## mm -> logical units
func mm(v: float) -> float:
	return v / 25.4 * 160.0
