extends Node
## Audio v1 (GDD 16): buses (Master/Music/SFX/Voice/UI), pooled positional SFX with per-sound
## limiting, UI sounds, music + ambience, and the data-driven voice system:
##   data/audio/voice_manifest.json  -> factions/units/events, priorities, cooldowns
##   res://audio/voice/<faction>/<folder>/<event>_<n>.ogg    recorded lines (drop-in)
##   res://audio/voice/announcer/<event>_<n>.ogg
##   res://audio/voice_placeholder/...                       TTS placeholders (fallback)
## Variants are picked at random without immediate repeats (shuffle bag). A line plays when
## its channel is idle or it outranks the line that is playing; cooldowns are per unit type.

const BUSES := ["Music", "SFX", "Voice", "UI"]
const MANIFEST := "res://data/audio/voice_manifest.json"
const SFX := {
	"rifle": "res://audio/sfx/rifle.ogg", "mg": "res://audio/sfx/mg_burst.ogg", "autocannon": "res://audio/sfx/autocannon.ogg",
	"cannon": "res://audio/sfx/tank_cannon.ogg", "missile": "res://audio/sfx/missile_launch.ogg", "grenade": "res://audio/sfx/grenade_launch.ogg",
	"flak": "res://audio/sfx/flak.ogg", "expl_small": "res://audio/sfx/explosion_small.ogg", "expl_large": "res://audio/sfx/explosion_large.ogg",
	"collapse": "res://audio/sfx/building_collapse.ogg", "impact": "res://audio/sfx/impact_dirt.ogg", "body_fall": "res://audio/sfx/body_fall.ogg",
	"construct": "res://audio/sfx/construct.ogg", "place": "res://audio/sfx/place_structure.ogg", "power_down": "res://audio/sfx/power_down.ogg",
	# M2 (TPLA)
	"tpla_carbine": "res://audio/sfx/tpla_carbine.ogg", "tpla_hmg": "res://audio/sfx/tpla_hmg.ogg", "tpla_quad": "res://audio/sfx/tpla_quad.ogg",
	"tpla_rpg": "res://audio/sfx/tpla_rpg.ogg", "tpla_salvo": "res://audio/sfx/tpla_salvo.ogg", "tpla_scrap_cannon": "res://audio/sfx/tpla_scrap_cannon.ogg",
	"tpla_rust_launch": "res://audio/sfx/tpla_rust_launch.ogg", "tpla_rust_sizzle": "res://audio/sfx/tpla_rust_sizzle.ogg",
	"expl_huge": "res://audio/sfx/explosion_huge.ogg", "salvage": "res://audio/sfx/salvage.ogg", "tunnel": "res://audio/sfx/tunnel.ogg",
	"trap_click": "res://audio/sfx/trap_click.ogg",
	# M2.4 weapon effects
	# M4.1 sound design: heavy .50 cal, door minigun
	"hmg_heavy": "res://audio/sfx/hmg_heavy.ogg", "minigun": "res://audio/sfx/minigun.ogg",
	"flame": "res://audio/sfx/flame.ogg", "howitzer": "res://audio/sfx/howitzer.ogg", "hit_metal": "res://audio/sfx/hit_metal_1.ogg",
	# M4.3 (synthesised, tools/m43/gen_sfx_m43.py): heavy weapons and movement
	"rocket_heavy": "res://audio/sfx/rocket_heavy.ogg", "missile_heavy": "res://audio/sfx/missile_heavy.ogg",
	"artillery_heavy": "res://audio/sfx/artillery_heavy.ogg", "cannon_heavy": "res://audio/sfx/cannon_heavy.ogg",
	"jet_takeoff": "res://audio/sfx/jet_takeoff.ogg",
}
## M4.3: looping movement sound per vehicle class (played on the unit while it moves / flies)
const MOVE_LOOPS := {"tank": "res://audio/sfx/move_tank_loop.ogg", "ifv": "res://audio/sfx/move_ifv_loop.ogg",
	"light": "res://audio/sfx/move_light_loop.ogg", "heli": "res://audio/sfx/move_heli_loop.ogg", "jet": "res://audio/sfx/move_jet_loop.ogg"}
static func move_class(ud: UnitDef) -> String:
	if ud == null or ud.tags.has("suicide") or String(ud.id).ends_with("_drone") or ud.tags.has("infantry") or not (ud.tags.has("vehicle") or ud.move_layer == &"air"):
		return ""
	if ud.move_layer == &"air":
		return "jet" if ud.tags.has("jet") else "heli"
	if ud.armor_type == &"heavy" or ud.tags.has("tank") or ud.tags.has("spg"):
		return "tank"
	if ud.tags.has("ifv") or ud.tags.has("aa") or ud.tags.has("artillery") or ud.speed_mtps < 2200:
		return "ifv"
	return "light"
## M2.4: alternative takes picked at random (plus pitch jitter) so repeated fire does not loop.
const VARIANTS := {
	"expl_small": ["res://audio/sfx/explosion_small.ogg", "res://audio/sfx/explosion_small_b.ogg", "res://audio/sfx/explosion_small_c.ogg"],
	"hit_metal": ["res://audio/sfx/hit_metal_1.ogg", "res://audio/sfx/hit_metal_2.ogg", "res://audio/sfx/hit_metal_3.ogg"],
}
const UI := {"click": "res://audio/ui/click.ogg", "select": "res://audio/ui/select.ogg", "error": "res://audio/ui/error.ogg",
	"confirm": "res://audio/ui/confirm.ogg", "alert": "res://audio/ui/alert.ogg", "build_ready": "res://audio/ui/build_ready.ogg"}
## M3.4: Malachi's own United States tracks (audio/music/us_*.ogg, from his "USA MUSIC" Drive
## folder, OGG Vorbis 128 kbps). "Base Command" is the menu music (loops).
## M3.5 (Malachi: "Make music shuffle for all teams so it's different each game"): every match
## plays its own random order (MUSIC_RNG, view only - never the sim's PCG32 or the global RNG),
## no faction always opens with the same track, and Base Command no longer opens US matches (it
## stays the menu music and comes up later in the US shuffle).
## The old synthesized rock tracks are kept in audio/music/superseded (not packaged).
const MUSIC := {"menu": "res://audio/music/us_base_command.ogg", "battle": "res://audio/music/us_defend_the_border.ogg"}
const US_PLAYLIST := ["res://audio/music/us_base_command.ogg", "res://audio/music/us_defend_the_border.ogg",
	"res://audio/music/us_mission_accomplished.ogg", "res://audio/music/us_zero_hour.ogg"]
## Fallback shuffle for a faction without its own list.
const BATTLE_PLAYLIST := US_PLAYLIST
## M3.2: battle music follows the local player's faction (tools/gen_music_m32.py): Russia
## hard-bass techno + march, Germany Berlin club techno, Iran war drums + Persian instruments;
## M3.4: the United States plays Malachi's tracks.
## M3.5: Malachi's own Russia (ru_*) and Iran (ir_*) tracks from his "Russia music" / "Iran Music"
## Drive folders (OGG Vorbis). Russia keeps the M3.3 "Steppe March"; the synthesized "Red Bounce"
## hard bass is superseded by "Moscow Techno". Iran keeps "Zagros" alongside its seven new tracks.
## Both now have 3+ tracks, so they no longer borrow other factions' music (MIN_POOL).
const RU_PLAYLIST := [
		"res://audio/music/battle_ru_steppe_march.ogg",
		"res://audio/music/ru_red_banner_march.ogg",
		"res://audio/music/ru_forward_comrades.ogg",
		"res://audio/music/ru_iron_rhythm.ogg",
		"res://audio/music/ru_moscow_techno_1.ogg",
		"res://audio/music/ru_moscow_techno_2.ogg",
		"res://audio/music/ru_desionaries.ogg"]
const IR_PLAYLIST := [
		"res://audio/music/ir_defend_the_holy_land.ogg",
		"res://audio/music/ir_iran_victory.ogg",
		"res://audio/music/ir_triumph_of_the_dunes.ogg",
		"res://audio/music/ir_descent_into_dust.ogg",
		"res://audio/music/ir_dusty_loop.ogg",
		"res://audio/music/ir_setars_waiting_riff.ogg",
		"res://audio/music/ir_iron_and_flower.ogg",
		"res://audio/music/battle_ir_zagros.ogg"]
const FACTION_PLAYLISTS := {
	&"us": US_PLAYLIST,
	&"ecc": RU_PLAYLIST,
	&"eu": ["res://audio/music/battle_de_tiefgarage.ogg"],
	&"tpla": IR_PLAYLIST,
}
var battle_faction: StringName = &""
var _shuffle: Array = []
var _last_battle := ""
## M3.5: factions with fewer tracks than this also draw on the other factions' battle tracks, so
## their matches differ too (only Germany, with one track of its own, still borrows).
const MIN_POOL := 3
var music_rng := RandomNumberGenerator.new()   ## view-only randomness for the music order
var match_order: Array = []                    ## the order picked for the current match (tests)
const AMBIENT := {"wind": "res://audio/ambient/desert_wind.ogg", "river": "res://audio/ambient/river.ogg"}

var manifest: Dictionary = {}
var faction_audio: Dictionary = {}   ## data/audio/faction_audio.json
var _streams: Dictionary = {}
var _pool3d: Array = []
var _ui_players: Array = []
var _music: AudioStreamPlayer
var _ambient: AudioStreamPlayer
var _unit_voice: AudioStreamPlayer
var _announcer: AudioStreamPlayer
var _unit_prio := 0
var _ann_prio := 0
var _ann_queue: Array = []
var _last_play: Dictionary = {}      ## sfx key -> msec
var _cool: Dictionary = {}           ## voice key -> msec until allowed
var _bags: Dictionary = {}           ## voice key -> Array of paths (shuffle bag)
var _last_line: Dictionary = {}      ## voice key -> last path
var _variants: Dictionary = {}       ## voice key -> [paths, is_placeholder]
var world_root: Node3D = null        ## set by the match; positional SFX parent
var announcer_faction := "eu"        ## local player's faction: picks the announcer voice (M2)
var music_track := ""

func _init() -> void:
	music_rng.randomize()
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	# light ducking-free compressor on SFX so big battles don't clip
	var si := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(si) == 0:
		var c := AudioEffectCompressor.new()
		c.threshold = -14.0
		c.ratio = 3.0
		AudioServer.add_bus_effect(si, c)
	var mi := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(mi) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -0.5
		AudioServer.add_bus_effect(mi, lim)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var f := FileAccess.open(MANIFEST, FileAccess.READ)
	if f:
		var j = JSON.parse_string(f.get_as_text())
		if j is Dictionary:
			manifest = j
	var fa := FileAccess.open("res://data/audio/faction_audio.json", FileAccess.READ)
	if fa:
		var j2 = JSON.parse_string(fa.get_as_text())
		if j2 is Dictionary:
			faction_audio = j2
	_music = _player("Music")
	_music.finished.connect(_on_music_finished)
	_ambient = _player("SFX")
	_ambient.volume_db = -14.0
	_unit_voice = _player("Voice")
	_announcer = _player("Voice")
	_unit_voice.finished.connect(func(): _unit_prio = 0)
	_announcer.finished.connect(_ann_next)
	for i in 4:
		_ui_players.append(_player("UI"))
	apply_volumes()
	EventBus.settings_changed.connect(apply_volumes)

func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p

func apply_volumes() -> void:
	var st := get_node_or_null("/root/Settings")
	if st == null:
		return
	for pair in [["Master", "vol_master"], ["Music", "vol_music"], ["SFX", "vol_sfx"], ["Voice", "vol_voice"], ["UI", "vol_ui"]]:
		var v = st.g(pair[1])
		var lin := 1.0 if v == null else float(v)
		var i := AudioServer.get_bus_index(pair[0])
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(lin, 0.0001)))
		AudioServer.set_bus_mute(i, lin <= 0.001)

func stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_streams[path] = s
	return s

# ---------------------------------------------------------------- SFX
## Positional one-shot. Limited to 3 overlapping and one start per 45 ms per sound.
func sfx(key: String, pos: Vector3, vol_db: float = 0.0, pitch_var: float = 0.06) -> void:
	if world_root == null or not is_instance_valid(world_root):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(key, -1000)) < 45:
		return
	var busy := 0
	var free_p: AudioStreamPlayer3D = null
	for p: AudioStreamPlayer3D in _pool3d:
		if p.playing:
			if p.get_meta("k", "") == key:
				busy += 1
		elif free_p == null:
			free_p = p
	if busy >= 3:
		return
	if free_p == null:
		if _pool3d.size() >= 24:
			return
		free_p = AudioStreamPlayer3D.new()
		free_p.bus = "SFX"
		free_p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		free_p.unit_size = 22.0
		free_p.max_distance = 90.0
		free_p.panning_strength = 0.6
		world_root.add_child(free_p)
		_pool3d.append(free_p)
	var path: String = SFX.get(key, "")
	if VARIANTS.has(key):
		var vs: Array = VARIANTS[key]
		path = vs[randi() % vs.size()]
	var s := stream(path)
	if s == null:
		return
	_last_play[key] = now
	free_p.set_meta("k", key)
	free_p.stream = s
	free_p.volume_db = vol_db
	free_p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	free_p.global_position = pos
	free_p.play()

## Per-faction weapon sound for a weapon vfx kind.
func weapon_sfx(faction: String, vfx_kind: String, structure: bool) -> String:
	var fd: Dictionary = faction_audio.get(faction, faction_audio.get("eu", {}))
	if structure and fd.get("structure_weapons", {}).has(vfx_kind):
		return fd["structure_weapons"][vfx_kind]
	return fd.get("weapons", {}).get(vfx_kind, "rifle")

func faction_sfx(faction: String, what: String, fallback: String) -> String:
	return faction_audio.get(faction, {}).get(what, fallback)

func ui(key: String) -> void:
	var s := stream(UI.get(key, ""))
	if s == null:
		return
	for p: AudioStreamPlayer in _ui_players:
		if not p.playing:
			p.stream = s
			p.play()
			return

func play_music(track: String) -> void:
	if track == music_track and _music.playing:
		return
	music_track = track
	if track == "battle":
		_shuffle.clear()
		match_order.clear()
		_next_battle_track()
		return
	var s := stream(MUSIC.get(track, ""))
	if s == null:
		_music.stop()
		return
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true   # M3.4: the menu track is also in the US shuffle (which unloops it)
	_music.stream = s
	_music.volume_db = -4.0
	_music.play()

func battle_playlist() -> Array:
	return FACTION_PLAYLISTS.get(battle_faction, BATTLE_PLAYLIST)

## M3.5: the tracks a match of this faction shuffles: its own, plus (when it has fewer than
## MIN_POOL) the other factions' battle tracks; the menu track only where it is the faction's own.
func battle_pool() -> Array:
	var pool: Array = battle_playlist().duplicate()
	if pool.size() < MIN_POOL:
		for f in FACTION_PLAYLISTS:
			for tr_path in FACTION_PLAYLISTS[f]:
				if not pool.has(tr_path) and tr_path != MUSIC["menu"]:
					pool.append(tr_path)
	return pool

## A fresh random order (Fisher-Yates on music_rng). The match never opens with the menu track
## or with the track the last match ended on.
func shuffled_order() -> Array:
	var order := battle_pool()
	for i in range(order.size() - 1, 0, -1):
		var j := music_rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	if order.size() > 1:
		for k in order.size():
			if order[0] != MUSIC["menu"] and order[0] != _last_battle:
				break
			order.push_back(order.pop_front())
	return order

## Shuffle without repeats: each pass plays every track once, never the same one twice in a row.
func _next_battle_track() -> void:
	if _shuffle.is_empty():
		_shuffle = shuffled_order()
		if match_order.is_empty():
			match_order = _shuffle.duplicate()
	_last_battle = _shuffle.pop_front()
	var s := stream(_last_battle)
	if s == null:
		_music.stop()
		return
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = false
	_music.stream = s
	_music.volume_db = -5.0
	_music.play()

func _on_music_finished() -> void:
	if music_track == "battle":
		_next_battle_track()

func play_ambient(key: String) -> void:
	var s := stream(AMBIENT.get(key, ""))
	if s == null:
		_ambient.stop()
		return
	if _ambient.stream != s or not _ambient.playing:
		_ambient.stream = s
		_ambient.play()

func stop_ambient() -> void:
	_ambient.stop()

func on_match_end() -> void:
	world_root = null
	_pool3d.clear()
	stop_ambient()

# ---------------------------------------------------------------- voices
func _folder_of(faction: String, unit_id: String) -> String:
	var fd: Dictionary = manifest.get("factions", {}).get(faction, {})
	return str(fd.get("units", {}).get(unit_id, {}).get("folder", unit_id.trim_prefix(faction + "_")))

func announcer_folder(fac: String = "") -> String:
	var f := fac if fac != "" else announcer_faction
	return str(manifest.get("announcer", {}).get("folders", {}).get(f, "announcer"))

## Variant list for a key: [paths, source] with source 0 = your recording, 1 = AI-generated
## voice, 2 = robotic placeholder. Lookup: res://audio/voice/ -> res://audio/voice_ai/ ->
## res://audio/voice_placeholder/ (unit, then generic). Recordings always win.
func variants(faction: String, folder: String, event: String) -> Array:
	var key := faction + "/" + folder + "/" + event
	if _variants.has(key):
		return _variants[key]
	var maxv := int(manifest.get("max_variants", 9))
	var dirs: Array
	if faction == "announcer":
		dirs = [["res://audio/voice/%s/" % folder, 0], ["res://audio/voice_ai/%s/" % folder, 1], ["res://audio/voice_placeholder/%s/" % folder, 2],
			["res://audio/voice/announcer/", 0], ["res://audio/voice_ai/announcer/", 1], ["res://audio/voice_placeholder/announcer/", 2]]
	else:
		dirs = [["res://audio/voice/%s/%s/" % [faction, folder], 0], ["res://audio/voice_ai/%s/%s/" % [faction, folder], 1],
			["res://audio/voice_placeholder/%s/%s/" % [faction, folder], 2], ["res://audio/voice_placeholder/%s/_generic/" % faction, 2],
			["res://audio/voice_placeholder/eu/_generic/", 2]]
	var out := [[], 2]
	for d in dirs:
		var found: Array = []
		for n in range(1, maxv + 1):
			var p: String = d[0] + "%s_%d.ogg" % [event, n]
			if ResourceLoader.exists(p):
				found.append(p)
		if not found.is_empty():
			out = [found, d[1]]
			break
	_variants[key] = out
	return out

func _pick(key: String, paths: Array) -> String:
	if paths.size() == 1:
		return paths[0]
	var bag: Array = _bags.get(key, [])
	if bag.is_empty():
		bag = paths.duplicate()
		bag.shuffle()
		if bag[0] == _last_line.get(key, ""):
			bag.push_back(bag.pop_front())
	var p: String = bag.pop_front()
	_bags[key] = bag
	_last_line[key] = p
	return p

func _rule(faction: String, event: String) -> Dictionary:
	if faction == "announcer" or faction.begins_with("announcer"):
		return manifest.get("announcer", {}).get("events", {}).get(event, {"priority": 1, "cooldown": 1.0})
	return manifest.get("events", {}).get(event, {"priority": 1, "cooldown": 0.0})

## Unit acknowledgement / chatter for the LOCAL player's units.
func unit_voice(faction: String, unit_id: String, event: String) -> bool:
	if is_drone(unit_id):   # M4.2: drones do not talk - a short motor rev for select / move / attack
		return drone_ack(event)
	var folder := _folder_of(faction, unit_id)
	var rule := _rule(faction, event)
	var key := faction + "/" + folder + "/" + event
	var now := Time.get_ticks_msec()
	if now < int(_cool.get(key, 0)):
		return false
	var prio := int(rule.get("priority", 1))
	if _unit_voice.playing and prio <= _unit_prio and prio < 2:
		return false
	if _unit_voice.playing and prio < _unit_prio:
		return false
	var v := variants(faction, folder, event)
	if v[0].is_empty():
		return false
	var s := stream(_pick(key, v[0]))
	if s == null:
		return false
	_cool[key] = now + int(float(rule.get("cooldown", 0.0)) * 1000.0)
	_unit_prio = prio
	_unit_voice.stream = s
	_unit_voice.pitch_scale = 1.0
	_unit_voice.play()
	return true

## M4.2: scout / explosive drones (all factions) have no voice, only a motor hum.
const DRONE_ACK := "res://audio/sfx/drone_ack.ogg"
const DRONE_LOOP := "res://audio/sfx/drone_hum_loop.ogg"
static func is_drone(unit_id: String) -> bool:
	return unit_id.ends_with("_drone")

func drone_ack(event: String) -> bool:
	if not event in ["select", "move", "attack", "created"]:
		return false
	var now := Time.get_ticks_msec()
	if now < int(_cool.get("drone_ack", 0)):
		return false
	_cool["drone_ack"] = now + 250
	var s := load(DRONE_ACK) as AudioStream
	if s == null:
		return false
	_unit_prio = 1
	_unit_voice.stream = s
	_unit_voice.pitch_scale = randf_range(0.94, 1.08)
	_unit_voice.play()
	return true

## Battle-control announcer (EVA-style; original wording). Queues up to 2 lines.
func announce(event: String) -> bool:
	var rule := _rule("announcer", event)
	var now := Time.get_ticks_msec()
	if now < int(_cool.get("ann/" + event, 0)):
		return false
	_cool["ann/" + event] = now + int(float(rule.get("cooldown", 1.0)) * 1000.0)
	var prio := int(rule.get("priority", 1))
	if _announcer.playing:
		if prio > _ann_prio + 1:
			_ann_queue.clear()
		else:
			if _ann_queue.size() < 2:
				_ann_queue.append(event)
			return true
	return _ann_play(event, prio)

func _ann_play(event: String, prio: int) -> bool:
	var v := variants("announcer", announcer_folder(), event)
	if v[0].is_empty():
		return false
	var s := stream(_pick("ann/" + event, v[0]))
	if s == null:
		return false
	_ann_prio = prio
	_announcer.stream = s
	_announcer.play()
	return true

func _ann_next() -> void:
	_ann_prio = 0
	if not _ann_queue.is_empty():
		var e: String = _ann_queue.pop_front()
		_ann_play(e, int(_rule("announcer", e).get("priority", 1)))

## Honest status for Settings/credits: manifest lines by source (your recording / AI voice /
## robotic placeholder / silent).
func voice_status() -> Dictionary:
	var counts := [0, 0, 0]
	var total := 0
	var missing := 0
	for fac in manifest.get("factions", {}):
		var fd: Dictionary = manifest["factions"][fac]
		for uid in fd.get("units", {}):
			var ud: Dictionary = fd["units"][uid]
			for ev in ud.get("events", []):
				total += 1
				var v := variants(fac, str(ud["folder"]), ev)
				if v[0].is_empty():
					missing += 1
				else:
					counts[int(v[1])] += 1
	var folders: Dictionary = manifest.get("announcer", {}).get("folders", {"eu": "announcer"})
	for f in folders:
		for ev in manifest.get("announcer", {}).get("faction_events", {}).get(f, manifest.get("announcer", {}).get("events", {}).keys()):
			total += 1
			var v2 := variants("announcer", str(folders[f]), ev)
			if v2[0].is_empty():
				missing += 1
			else:
				counts[int(v2[1])] += 1
	return {"recorded": counts[0], "ai": counts[1], "placeholder": counts[2], "missing": missing, "total": total}
