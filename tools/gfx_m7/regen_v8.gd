extends SceneTree
## M2.7b: regenerate older (M2.2 / M2.4 / M2.6) EU + TPLA vehicle views with the kit8 upgrades
## (chamfered armour hulls, track runs, treaded tyres) and the M2.7b remodels, without touching
## any building. Then run add_lods, bake_ao and camo_pass on the written scenes
## (tools/gfx_m7/build_v8.sh does all of it).
##   godot --headless --path . -s res://tools/gfx_m7/regen_v8.gd -- [names... | all]
const V4 := "res://tools/gfx_m4/vehicles_m4.gd"
const C6 := "res://tools/gfx_m6/core_m6.gd"
const E8 := "res://tools/gfx_m7/eu_tp_v8.gd"
const JOBS := {
	"brennus": [V4, "_brennus", "eu"], "thunderhead": [V4, "_thunderhead", "eu"],
	"hearth": [V4, "_hearth", "eu"], "spectre": [V4, "_spectre", "eu"], "sentinel": [V4, "_sentinel", "eu"],
	"kestrel": [V4, "_kestrel", "eu"], "corvid": [V4, "_corvid", "eu"], "junkhammer": [V4, "_junkhammer", "tpla"],
	"sprayer": [V4, "_sprayer", "tpla"], "earwig": [V4, "_earwig", "tpla"], "jackal": [V4, "_jackal", "tpla"],
	"bus": [V4, "_bus", "tpla"], "wolfhound": [C6, "_wolfhound", "eu"], "flakwerk": [C6, "_flakwerk", "eu"],
	"aegis": [C6, "_aegis", "eu"], "scrapback": [C6, "_scrapback", "tpla"], "hailstorm": [C6, "_hailstorm", "tpla"],
	"leopold": [E8, "_leopold", "eu"], "rattler": [E8, "_rattler", "tpla"],
}

func _initialize() -> void:
	var only := Array(OS.get_cmdline_user_args())
	var all := only.is_empty() or "all" in only
	var mat: Material = load("res://view/materials/m3.tres")
	var wrote: Array = []
	for k: String in JOBS:
		if not (all or k in only):
			continue
		var j: Array = JOBS[k]
		if not ResourceLoader.exists(j[0]):
			continue
		var scr: GDScript = load(j[0])
		if j[0] == E8:
			scr.call(j[1])
		else:
			scr.call(j[1], mat)
		wrote.append("res://view/units/%s/%s.tscn" % [j[2], k.trim_suffix("_m4")])
	var f := FileAccess.open("/tmp/gfx_v8_wrote.txt", FileAccess.WRITE)
	for p in wrote:
		f.store_line("WROTE " + p)
	print("regen v8: %d views" % wrote.size())
	quit(0)
