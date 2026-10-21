class_name HudTextCheck
extends RefCounted
## UI test helper (M2): walks the HUD and returns every button whose text overflows or would
## be clipped. HudButtons use their own fit result (full name, <= 2 lines, >= 9 dp font,
## price/count on its own line); plain Buttons are measured against their content box. Also
## checks the 48 dp minimum tap target on the command card, filters, queue chips, top bar.

static func problems(hud) -> Array:
	var out: Array = []
	_walk(hud.root, out)
	# nothing may hang off the selection panel or the screen (that would clip the label)
	var panel: Rect2 = hud.sel_panel.get_global_rect().grow(0.5)
	var screen: Rect2 = hud.root.get_global_rect().grow(0.5)
	for box in [hud.sel_types, hud.queue_box]:
		for c in box.get_children():
			if c is Control and (c as Control).is_visible_in_tree() and not panel.encloses((c as Control).get_global_rect()):
				out.append("'%s' sticks out of the selection panel" % (c.label_text if c is HudButton else c.get("text")))
	_on_screen(hud.root, screen, out)
	if not hud.portrait_fit_ok:
		out.append("selection portrait name does not fit")
	return out

static func _walk(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Control and not (c as Control).is_visible_in_tree():
			continue
		if c is HudButton:
			var b: HudButton = c
			if b.label_text != "" or b.sub != "":
				if not b.text_fits():
					out.append("'%s' / '%s' does not fit in %s (font %d)" % [b.label_text.replace("\n", " "), b.sub, b.size, b.fit_size])
				if b.fit_size < HudButton.MIN_FONT and b.label_text != "":
					out.append("'%s' font below minimum" % b.label_text)
				if minf(b.size.x, b.size.y) < 47.5 and b.label_text.length() > 1:
					out.append("'%s' tap target %s < 48 dp" % [b.label_text.replace("\n", " "), b.size])
		elif c is Button:
			var pb: Button = c
			if pb.text != "":
				var f := pb.get_theme_font("font")
				var fs := pb.get_theme_font_size("font_size")
				var sb := pb.get_theme_stylebox("normal")
				var avail := pb.size.x - (sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT) if sb != null else 0.0)
				var w := 0.0
				for line in pb.text.split("\n"):
					w = maxf(w, f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
				if w > avail + 0.5:
					out.append("button '%s' text %.0f > %.0f" % [pb.text.replace("\n", " "), w, avail])
		_walk(c, out)

static func _on_screen(n: Node, screen: Rect2, out: Array) -> void:
	for c in n.get_children():
		if c is Control and not (c as Control).is_visible_in_tree():
			continue
		if c is BaseButton and not screen.encloses((c as Control).get_global_rect()):
			out.append("button '%s' is partly off screen %s" % [(c.label_text if c is HudButton else c.get("text")), (c as Control).get_global_rect()])
		_on_screen(c, screen, out)
