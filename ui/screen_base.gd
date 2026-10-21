class_name ScreenBase
extends Control
## Full-screen menu base: background, theme, safe-area margin container ("body").

var body: MarginContainer

func _ready() -> void:
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
	_fit()
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
