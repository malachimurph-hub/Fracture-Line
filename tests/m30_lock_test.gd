extends Node
## M3.0 release locked Russia as "Coming soon"; M3.2 unlocks it (Malachi). The lock mechanism
## (FACTIONS[f]["enabled"] = false) stays for future factions. This test checks that Russia is
## playable everywhere: lobby dropdowns (player + AI), lobby resolver, Map Builder assets, and
## that the lock still works (Content.faction_enabled honours "enabled": false).
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
	check("Russia is playable", Content.faction_enabled(&"ecc") and Content.playable_factions().has(&"ecc"), Content.playable_factions())
	check("all four factions playable", Content.playable_factions().size() == 4, Content.playable_factions())
	check("lock mechanism kept: unknown / disabled faction is not enabled", not Content.faction_enabled(&"nope"))
	var cfg := SkirmishConfig.default_setup()
	cfg["slots"][0]["faction"] = "ecc"
	cfg["slots"][1]["kind"] = "ai"
	cfg["slots"][1]["faction"] = "ecc"
	var r: Dictionary = SkirmishConfig.resolve(cfg)
	var ecc_slots: Array = r["slots"].filter(func(s): return s["faction"] == "ecc")
	check("lobby resolver starts Russia for the player and the AI", ecc_slots.size() >= 2, r["slots"].map(func(s): return s["faction"]))
	check("Russian AI gets its personality", ecc_slots.any(func(s): return s["kind"] == "ai" and String(s.get("personality", "")) == "ecc_steppe"))
	var lobby: Node = load("res://ui/skirmish_setup.tscn").instantiate()
	add_child(lobby)
	for i in 10:
		await get_tree().process_frame
	var on := 0
	var drops: Array = []
	for o in lobby.find_children("*", "OptionButton", true, false):
		var ob := o as OptionButton
		for k in ob.item_count:
			if ob.get_item_text(k).begins_with(tr("FACTION_ECC")):
				drops.append(ob)
				if not ob.is_item_disabled(k) and not ob.get_item_text(k).contains(tr("LOBBY_COMING_SOON")):
					on += 1
	check("Russia selectable (no 'Coming soon') in every faction dropdown", drops.size() == 4 and on == 4, "%d/%d" % [on, drops.size()])
	var mb: Node = load("res://ui/map_builder.tscn").instantiate()
	var ecc_assets := 0
	var has_head := false
	for c in mb.asset_categories():
		has_head = has_head or (String(c[0]).contains(tr("LOBBY_COMING_SOON")))
		for a in c[1]:
			if String(a.get("kind", "")).begins_with("ecc_"):
				ecc_assets += 1
	mb.free()
	check("Map Builder: Russian assets listed, no 'Coming soon' heading", not has_head and ecc_assets > 0, ecc_assets)
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
