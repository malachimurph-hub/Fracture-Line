extends Node
## M3.0 release: Russia is "Coming soon": locked in every lobby faction dropdown, absent from the
## Map Builder assets, never picked by the menu battle or the lobby resolver. Optional screenshot.
## Run: godot --path . res://tests/m30_lock_test.tscn -- [out.png]
var fails := 0

func check(name: String, ok: bool, info = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ("  (%s)" % str(info) if str(info) != "" else ""))
	if not ok:
		fails += 1

func _ready() -> void:
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.ends_with(".png"):
			out = a
	check("Russia is not playable", not Content.faction_enabled(&"ecc") and not Content.playable_factions().has(&"ecc"), Content.playable_factions())
	check("other factions playable", Content.playable_factions().size() == 3)
	var cfg := SkirmishConfig.default_setup()
	cfg["slots"][1]["faction"] = "ecc"
	var r: Dictionary = SkirmishConfig.resolve(cfg)
	check("lobby resolver never starts Russia", r["slots"].all(func(s): return s["faction"] != "ecc"))
	var lobby: Node = load("res://ui/skirmish_setup.tscn").instantiate()
	add_child(lobby)
	for i in 10:
		await get_tree().process_frame
	var locked := 0
	var drops: Array = []
	for o in lobby.find_children("*", "OptionButton", true, false):
		var ob := o as OptionButton
		for k in ob.item_count:
			if ob.get_item_text(k).begins_with(tr("FACTION_ECC")):
				drops.append(ob)
				if ob.is_item_disabled(k) and ob.get_item_text(k).contains(tr("LOBBY_COMING_SOON")) and ob.selected != k:
					locked += 1
	check("Russia shows 'Coming soon', greyed, in every faction dropdown", drops.size() == 4 and locked == 4, "%d/%d" % [locked, drops.size()])
	var mb: Node = load("res://ui/map_builder.tscn").instantiate()
	var ecc_assets := 0
	var has_head := false
	for c in mb.asset_categories():
		has_head = has_head or (String(c[0]).contains(tr("LOBBY_COMING_SOON")))
		for a in c[1]:
			if String(a.get("kind", "")).begins_with("ecc_"):
				ecc_assets += 1
	mb.free()
	check("Map Builder: Russia 'Coming soon' heading, no Russian assets", has_head and ecc_assets == 0, ecc_assets)
	if out != "" and drops.size() > 1:
		var ob: OptionButton = drops[1]
		ob.show_popup()
		for i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out)
		print("shot ", out)
	print("=== M30 LOCK RESULT: ", "PASS" if fails == 0 else "FAIL")
	get_tree().quit(1 if fails else 0)
