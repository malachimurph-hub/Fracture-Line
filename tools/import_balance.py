#!/usr/bin/env python3
"""Regenerate data/*.tres from data/balance/*.csv (the balance source of truth).
Run: python3 tools/import_balance.py   (tests/test_content.gd fails if .tres drift from CSV)."""
import csv, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BAL = os.path.join(ROOT, "data", "balance")

def sn(v): return '&"%s"' % v
def s(v): return '"%s"' % v
def psa(v): return 'PackedStringArray(%s)' % ", ".join('"%s"' % x for x in v.split("|") if x)
def b(v): return "true" if str(v).strip() in ("1", "true", "True") else "false"

def write(path, script, cls, props):
    lines = ['[gd_resource type="Resource" script_class="%s" load_steps=2 format=3]' % cls, "",
             '[ext_resource type="Script" path="%s" id="1_s"]' % script, "", "[resource]", 'script = ExtResource("1_s")']
    for k, v in props:
        lines.append("%s = %s" % (k, v))
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w") as f:
        f.write("\n".join(lines) + "\n")

def rows(name):
    with open(os.path.join(BAL, name)) as f:
        return list(csv.DictReader(f))

def fac_of(i):
    return i.split("_", 1)[0]

for r in rows("units.csv"):
    short = r["id"].split("_", 1)[1]
    fac = fac_of(r["id"])
    write("data/units/%s/%s.tres" % (fac, r["id"]), "res://data/defs/unit_def.gd", "UnitDef", [
        ("id", sn(r["id"])), ("faction", sn(fac)), ("name_key", s(r["name_key"])), ("desc_key", s(r["name_key"] + "_DESC")),
        ("cost", r["cost"]), ("build_time_ms", r["build_time_ms"]), ("pop", r["pop"]), ("prereqs", psa(r["prereqs"])),
        ("tags", psa(r["tags"])), ("max_hp", r["max_hp"]), ("armor_type", sn(r["armor_type"])), ("weapons", psa(r["weapons"])),
        ("speed_mtps", r["speed_mtps"]), ("move_layer", sn(r["move_layer"])), ("sight", r["sight"]), ("radius_mt", r["radius_mt"]),
        ("shield_aura_radius", r["shield_aura_radius"]), ("shield_aura_pct", r["shield_aura_pct"]),
        ("harvest_capacity", r["harvest_capacity"]), ("role", sn(r["role"])),
        ("view_scene", s("res://view/units/%s/%s.tscn" % (fac, short))), ("stubs", psa(r["stubs"])),
        ("loco", sn(r.get("loco", ""))), ("turn_dps", r.get("turn_dps", "0") or "0"), ("accel_ms", r.get("accel_ms", "0") or "0"),
        ("turret_dps", r.get("turret_dps", "0") or "0"), ("abilities", psa(r.get("abilities", ""))),
        ("transport_capacity", r.get("transport_capacity", "0") or "0"), ("detector", b(r.get("detector", "0"))),
        ("air_slots", r.get("air_slots", "0") or "0")])

for r in rows("buildings.csv"):
    short = r["id"].split("_", 1)[1]
    fac = fac_of(r["id"])
    write("data/buildings/%s/%s.tres" % (fac, r["id"]), "res://data/defs/building_def.gd", "BuildingDef", [
        ("id", sn(r["id"])), ("faction", sn(fac)), ("name_key", s(r["name_key"])), ("desc_key", s(r["name_key"] + "_DESC")),
        ("category", sn(r["category"])), ("cost", r["cost"]), ("build_time_ms", r["build_time_ms"]),
        ("footprint", "Vector2i(%s, %s)" % (r["footprint_w"], r["footprint_h"])), ("max_hp", r["max_hp"]), ("power", r["power"]),
        ("grid_radius", r["grid_radius"]), ("sight", r["sight"]), ("prereqs", psa(r["prereqs"])), ("produces", psa(r["produces"])),
        ("is_hq", b(r["is_hq"])), ("is_refinery", b(r["is_refinery"])), ("passive_income", r["passive_income"]),
        ("income_amount", r.get("income_amount", "0") or "0"), ("income_period_s", r.get("income_period_s", "0") or "0"),
        ("free_unit", sn(r["free_unit"])), ("shield_pct", r["shield_pct"]),
        ("view_scene", s("res://view/buildings/%s/%s.tscn" % (fac, short))), ("stubs", psa(r["stubs"])),
        ("weapons", psa(r["weapons"])), ("needs_power_to_fire", b(r["needs_power_to_fire"])),
        ("garrison_capacity", r["garrison_capacity"]), ("capturable", b(r["capturable"])),
        ("capture_income", r["capture_income"]), ("buildable", b(r["buildable"])),
        ("tags", psa(r.get("tags", ""))), ("aux_radius", r.get("aux_radius", "0") or "0"),
        ("air_slots", r.get("air_slots", "0") or "0")])

for r in rows("weapons.csv"):
    write("data/weapons/%s.tres" % r["id"], "res://data/defs/weapon_def.gd", "WeaponDef", [
        ("id", sn(r["id"])), ("damage", r["damage"]), ("range_mt", r["range_mt"]), ("min_range_mt", r["min_range_mt"]),
        ("cooldown_ms", r["cooldown_ms"]), ("damage_type", sn(r["damage_type"])), ("splash_mt", r["splash_mt"]),
        ("targets_air", b(r["targets_air"])), ("targets_ground", b(r["targets_ground"])), ("vfx", sn(r["vfx"])),
        ("min_tier", r.get("min_tier", "0") or "0"),
        ("pre_attack_ms", r.get("pre_attack_ms", "0") or "0"), ("pre_attack_type", sn(r.get("pre_attack_type", "attack") or "attack")),
        ("clip_size", r.get("clip_size", "0") or "0"), ("reload_ms", r.get("reload_ms", "0") or "0"),
        ("aim_deg", r.get("aim_deg", "12") or "12"), ("scatter_mt", r.get("scatter_mt", "0") or "0"),
        ("scatter_inf_mt", r.get("scatter_inf_mt", "0") or "0")])

for r in rows("powers.csv"):
    write("data/powers/%s.tres" % r["id"], "res://data/defs/power_def.gd", "PowerDef", [
        ("id", sn(r["id"])), ("name_key", s(r["name_key"])), ("desc_key", s(r["desc_key"])), ("rank_required", r["rank_required"]), ("point_cost", r["point_cost"]), ("stub", b(r["stub"])),
        ("cooldown_ms", r["cooldown_ms"]), ("radius", r["radius"]), ("duration_ms", r["duration_ms"]),
        ("amount", r["amount"]), ("kind", sn(r["kind"]))])

ct = rows("combat_table.csv")
entries = []
for r in ct:
    inner = ", ".join('"%s": %s' % (k, v) for k, v in r.items() if k != "damage_type")
    entries.append('"%s": {%s}' % (r["damage_type"], inner))
write("data/combat_table.tres", "res://data/defs/combat_table.gd", "CombatTable", [("table", "{" + ", ".join(entries) + "}")])
print("balance import done")
