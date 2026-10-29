class_name InfoCard
extends RefCounted
## M3.2 press-and-hold info card: every number comes from the content defs (balance CSVs), never
## hard-coded. build(kind, id, sim, pid) -> {"title": String, "lines": PackedStringArray}
## kind: "unit" | "building" | "power". Lines are short (<= ~46 chars) for the S24 Ultra card.

const ARMORS := ["infantry", "light", "heavy", "structure", "air"]

static func build(kind: String, id: StringName, sim: SimWorld, pid: int) -> Dictionary:
	match kind:
		"unit":
			return _unit(Content.unit(id), sim, pid)
		"building":
			return _building(Content.building(id), sim, pid)
		"power":
			return _power(Content.powers.get(id), sim, pid)
	return {}

static func _t(k: String) -> String:
	return TranslationServer.translate(k)

static func _desc(key: String) -> String:
	var d := _t(key + "_DESC")
	return "" if d == key + "_DESC" else d

static func _secs(ms: int) -> String:
	return ("%ds" % (ms / 1000)) if ms % 1000 == 0 else ("%.1fs" % (ms / 1000.0))

static func _armor_name(a: String) -> String:
	return _t("INFO_ARMOR_" + a.to_upper())

## Weapon line: "Rifle: 18 dmg, 5.5 tiles, 0.7s · ground" (+ clip, air/ground).
static func _weapon_line(wid: String) -> String:
	var wd: WeaponDef = Content.weapon(StringName(wid))
	if wd == null:
		return ""
	var tg: Array = []
	if wd.targets_ground:
		tg.append(_t("INFO_GROUND"))
	if wd.targets_air:
		tg.append(_t("INFO_AIR"))
	var s := _t("INFO_WEAPON") % [wd.damage, wd.range_mt / 1000.0, wd.cooldown_ms / 1000.0, "/".join(tg)]
	if wd.splash_mt > 0:
		s += _t("INFO_SPLASH")
	return s

## Good vs: armour classes where the best weapon's multiplier is >= 100 %; weak vs: classes no
## weapon can hit or where every weapon is < 50 %.
static func _versus(weapons: PackedStringArray) -> Array:
	var good: Array = []
	var weak: Array = []
	if weapons.is_empty():
		return [good, weak]
	for a in ARMORS:
		var best := 0
		for wid in weapons:
			var wd: WeaponDef = Content.weapon(StringName(wid))
			if wd == null:
				continue
			if (a == "air" and not wd.targets_air) or (a != "air" and not wd.targets_ground):
				continue
			best = maxi(best, Content.combat.mult(wd.damage_type, StringName(a)))
		if best >= 100:
			good.append(_armor_name(a))
		elif best < 50:
			weak.append(_armor_name(a))
	return [good, weak]

## Damage types that hit this armour class for >= 120 %.
static func _vulnerable(armor: StringName) -> Array:
	var out: Array = []
	for dt in Content.combat.table:
		if int(Content.combat.table[dt].get(String(armor), 100)) >= 120:
			out.append(_t("INFO_DMG_" + String(dt).to_upper()))
	return out

static func _locked(sim: SimWorld, pid: int, prereqs: PackedStringArray) -> String:
	if sim == null or pid < 0:
		return ""
	var miss: Array = []
	for p in prereqs:
		if not sim.has_completed(pid, p):
			var b: BuildingDef = Content.building(p)
			var u: UnitDef = Content.unit(p) if b == null else null
			miss.append(_t(b.name_key) if b != null else (_t(u.name_key) if u != null else String(p)))
	return "" if miss.is_empty() else _t("INFO_REQUIRES") % ", ".join(miss)

static func _unit(d: UnitDef, sim: SimWorld, pid: int) -> Dictionary:
	if d == null:
		return {}
	var L := PackedStringArray()
	if d.tags.has("upgrade"):
		L.append(_t("INFO_RESEARCH") % [d.cost, _secs(d.build_time_ms)])
	else:
		L.append(_t("INFO_COST_TIME") % [d.cost, _secs(d.build_time_ms)] + ((" · " + _t("INFO_POP") % d.pop) if d.pop > 0 else ""))
	var ds := _desc(d.name_key)
	if ds != "":
		L.append(ds)
	if not d.tags.has("upgrade"):
		L.append(_t("INFO_UNIT_STATS") % [d.max_hp, _armor_name(String(d.armor_type)), d.speed_mtps / 1000.0, d.sight])
		for wid in d.weapons:
			L.append(_weapon_line(wid))
		var vs := _versus(d.weapons)
		if not vs[0].is_empty():
			L.append(_t("INFO_GOOD_VS") % ", ".join(vs[0]))
		var weak: Array = vs[1].duplicate()
		for x in _vulnerable(d.armor_type):
			weak.append(x)
		if d.weapons.is_empty():
			weak.push_front(_t("INFO_UNARMED"))
		if not weak.is_empty():
			L.append(_t("INFO_WEAK_VS") % ", ".join(weak))
		if d.transport_capacity > 0:
			L.append(_t("INFO_TRANSPORT") % d.transport_capacity)
		if d.detector:
			L.append(_t("INFO_DETECTOR"))
	var lk := _locked(sim, pid, d.prereqs)
	if lk != "":
		L.append(lk)
	return {"title": _t(d.name_key), "lines": L}

static func _building(d: BuildingDef, sim: SimWorld, pid: int) -> Dictionary:
	if d == null:
		return {}
	var L := PackedStringArray()
	L.append(_t("INFO_COST_TIME") % [d.cost, _secs(d.build_time_ms)] + " · " + _t("INFO_SIZE") % [d.footprint.x, d.footprint.y])
	var ds := _desc(d.name_key)
	if ds != "":
		L.append(ds)
	L.append(_t("INFO_HP") % d.max_hp)
	if d.power > 0:
		L.append(_t("INFO_POWER_GEN") % d.power)
	elif d.power < 0:
		L.append(_t("INFO_POWER_USE") % -d.power)
	if d.tags.has("income_burst") and d.income_amount > 0:
		L.append(_t("INFO_INCOME_BURST") % [d.income_amount, d.income_period_s] + " (" + _t("INFO_INCOME") % EconSys.per_minute(d) + ")")
	elif d.passive_income > 0 or d.income_amount > 0:
		L.append(_t("INFO_INCOME") % EconSys.per_minute(d))
	if d.capture_income > 0:
		L.append(_t("INFO_INCOME_CAPTURED") % (d.capture_income * 60))
	if d.is_refinery:
		L.append(_t("INFO_REFINERY"))
	if not d.produces.is_empty():
		var n: Array = []
		for u in d.produces:
			var ud: UnitDef = Content.unit(u)
			if ud != null:
				n.append(_t(ud.name_key))
		L.append(_t("INFO_PRODUCES") % ", ".join(n))
	var unlocks: Array = []
	for bid in Content.building_order(d.faction):
		var b2: BuildingDef = Content.building(bid)
		if b2 != null and b2.prereqs.has(String(d.id)):
			unlocks.append(_t(b2.name_key))
	if not unlocks.is_empty():
		L.append(_t("INFO_UNLOCKS") % ", ".join(unlocks))
	for wid in d.weapons:
		L.append(_weapon_line(wid))
	var vs := _versus(d.weapons)
	if not vs[0].is_empty():
		L.append(_t("INFO_GOOD_VS") % ", ".join(vs[0]))
	if not d.weapons.is_empty() and not vs[1].is_empty():
		L.append(_t("INFO_WEAK_VS") % ", ".join(vs[1]))
	if d.garrison_capacity > 0:
		L.append(_t("INFO_GARRISON") % d.garrison_capacity)
	if d.air_slots > 0:
		L.append(_t("INFO_AIR_SLOTS") % d.air_slots)
	if d.free_unit != &"":
		var fu: UnitDef = Content.unit(d.free_unit)
		if fu != null:
			L.append(_t("INFO_FREE_UNIT") % _t(fu.name_key))
	var lk := _locked(sim, pid, d.prereqs)
	if lk != "":
		L.append(lk)
	return {"title": _t(d.name_key), "lines": L}

static func _power(d: PowerDef, _sim: SimWorld, _pid: int) -> Dictionary:
	if d == null:
		return {}
	var L := PackedStringArray()
	L.append(_t("INFO_POWER_RANK") % [d.rank_required, d.point_cost])
	L.append(_t(d.desc_key))
	var s := _t("INFO_COOLDOWN") % (d.cooldown_ms / 1000)
	if d.radius > 0:
		s += " · " + _t("INFO_RADIUS") % d.radius
	if d.duration_ms > 0:
		s += " · " + _t("INFO_DURATION") % _secs(d.duration_ms)
	L.append(s)
	if d.stub:
		L.append(_t("TRAY_COMING"))
	return {"title": _t(d.name_key), "lines": L}
