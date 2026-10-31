class_name ScreenBase
extends Control
## Full-screen menu base: background, theme, safe-area margin container ("body").

var body: MarginContainer

func _ready() -> void:
	AudioDirector.play_music("menu")
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#14171c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var stripe := ColorRect.new()
	stripe.color = Color(UiTheme.GOLD, 0.08)
	stripe.set_anchors_preset(Control.PRESET_FULL_RECT)
	stripe.anchor_left = 0.62
	add_child(stripe)
	body = MarginContainer.new()
	add_child(body)
	UiScale.changed.connect(_fit)
	# 0.3.7 fix: body grew to a stale, too-tall size when a child's minimum size spiked during the
	# first layout (the main menu's centred button column then sat below the screen on phones).
	# Re-fit on our own resize, when body's minimum size changes, and once after the first frame.
	resized.connect(_fit)
	body.minimum_size_changed.connect(_fit, CONNECT_DEFERRED)   # a container never shrinks back by itself
	_fit()
	_fit.call_deferred()
	build()

func _fit() -> void:
	var sr := UiScale.safe_rect
	if sr.size.x <= 0:
		sr = Rect2(Vector2.ZERO, UiScale.logical_size())
	body.position = sr.position + Vector2(12, 8)
	body.size = sr.size - Vector2(24, 16)

func build() -> void:
	pass

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()

func go_back() -> void:
	pass
