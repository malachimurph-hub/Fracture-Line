# MZKT-7930 Stage 1 audit

Audit and design only. No mesh, no unit data, and no simulation code. Stage 2 does not start until Malachi picks the open items at the end.

The player builds one bare 8x8 chassis at the Vehicle Factory, then picks one module. The pick is permanent. There is no repair module.

| Module | What it is | Modelled first? |
|---|---|---|
| A | Long-range high-altitude anti-air. Pantsir-style combined turret. | Later. This is the existing Pantsir role. |
| B | Radar. Large sight, stealth detection, artillery range aura. | Yes, with the bare chassis. |
| C | Long-range cruise missile. Four boxed canisters on a trainable elevating arm. | Later. |

A and C do not share a launcher. A is the turret with a search dish, a tracking radar, twin missile racks and twin autocannons. C is the separate box launcher. An earlier note suggested one launcher with different canisters. The Pantsir references close that.

Paint is Russian green `#96A468`, the same as the T-90 and the finished Mi-8. No badges, plates, words, stars, woodland camo, or the hazard chevrons from the photos.

References saved with this note:

- `docs/m4_7/refs/mzkt_radar_side.jpg`, `mzkt_radar_front.jpg` — module B.
- `docs/m4_7/refs/mzkt_missile_1.jpg`, `mzkt_missile_2.jpg`, `mzkt_missile_3.jpg` — module C, style only. The cab in those photos is not our cab.
- Spec sheet MZKT-RU.7930-415.S.28.01 — authoritative chassis numbers, quoted below. It is the Pantsir-on-MZKT sheet, so its radar-top height belongs to module A, not to the flat panel on B.

## 1. What is already in the repo

Russia already has two MZKT-7930-shaped trucks. They are separate factory units, not a shared chassis.

| Unit | Factory | Tags | Weapons | Sight | Notes |
|---|---|---|---|---|---|
| `ecc_iskander` | `ecc_factory`, no building gate | `vehicle`, `artillery`, `setup` | `ecc_iskander`, 15 tiles, minimum 5 | 9 | 5 s still before it can fire (`UsSys.SETUP_TICKS` = 100). Twin canisters. |
| `ecc_pantsir` | factory, requires `ecc_ministry` | `vehicle`, `aa`, `deploy`, `deploy_aa` | gun 6.5 tiles, SAM 12 tiles, air only | 12 | 8 s still before either weapon fires (`EccSys.DEPLOY_TICKS` = 160). A planted Pantsir joins the air-defence net. |
| `ecc_reaper` | factory, after Grim Reaper research | `vehicle`, `artillery`, `deploy` | 21 tiles, minimum 6.5 | 10 | 16x16, not this chassis. Same 8 s deploy. |
| `ecc_msta` | factory, needs the depot | `vehicle`, `artillery`, `spg` | `ecc_152mm`, 15 tiles, minimum 4 | 10 | Tracked SPG. |
| `ecc_tos` | factory | `vehicle`, `artillery` | `ecc_tos`, 4.8 tiles, minimum 1 | 8 | TOS-1A. No setup tag. |

`ecc_factory.produces` lists Iskander and Pantsir as their own icons. Nothing in the factory is a bare hull, and nothing asks the player to pick a module after a unit exists.

The live meshes are the procedural kit in `tools/m47/ru_hulls.gd` (`iskander`, `pantsir`), written to `view/units/ecc/iskander.tscn` and `pantsir.tscn`. Both use `sc := 0.24`. `tools/m47/vehicles_m47.gd` says the missile trucks use 0.24 so a 13 m TEL still fits the camera. Pantsir's length constant is `12.7 * 0.24` (3.05 u). Iskander's is `13.0 * 0.24` (3.12 u). Pantsir already has `Outriggers` with four legs, a `TurretPivot`, a `Radar` hinge that folds for travel, and a `Barrel` for the guns. `VehicleView.set_plant` lowers those outriggers and raises that radar when the deploy timer runs. `WorldView` sets `elevate` on any artillery piece so its `Barrel` lifts to fire.

There is no morph, transform, or "replace this unit's definition" path. `UnitDef.abilities` is unused by the HUD. The command card is built in `ui/hud/hud.gd`. Factory buttons come from `BuildingDef.produces` and are icon buttons; the name is the tooltip. The closest "pick one of several" UI is the Russian tower fitting in `_ecc_commands`: one icon per fitting, tooltip for the name, and the button disappears once that structure is fitted.

`UnitDef.detector` already reveals hidden units and hidden structures inside that unit's sight. The only detector in the roster is `eu_sentinel` (sight 12). Setting the flag is enough for stealth detection. It does not change weapon range.

Weapon range is read in two places, both straight from `WeaponDef.range_mt`:

- `CombatSys._fire_unit` rejects a shot past `FX.mt_to_fx(wd.range_mt)`.
- `OrderSys.max_range` uses the same value to decide where the unit stops.

A range bonus has to change both, or the gun drives to the old range and never uses the extra reach. One tile is 1000 milli-tiles.

Auras that exist today, and why none of them can host a range bonus:

| System | What it does | Why it is the wrong host |
|---|---|---|
| `shield_aura_radius` / `shield_aura_pct` | `PowerSys` grants shield hit points to units on the same team. The view draws a dome. | It refills a shield. It does not read weapons. |
| `heal_aura` + `BuildingDef.aux_radius` | A powered building heals its owner's units. | Buildings only. Heals hit points. |
| Jammer, `RosterSys.JAM_RADIUS` = 6 tiles | Enemy vehicles near a Spectre cannot fire. | A deny, and the radius is a constant, not a per-unit field. |
| `detector` | Reveals stealth inside `sight`. | Sight only. No effect on allied weapons. |

The jammer is the right shape to copy: a pre-pass collects the trucks, and the range check asks "is a halted friendly radar within N tiles?" once. The answer is yes or no. It is not a stack of bonuses.

`ecc_up_hack_radar` is the Black Market minimap blackout. It is unrelated.

## 2. Chassis dimensions

From MZKT-RU.7930-415.S.28.01. These are the base truck, and the radar-top line is the Pantsir radar, module A.

| Measure | mm | m |
|---|---:|---:|
| Overall length | 12,670 | 12.670 |
| Width, body | 3,150 | 3.150 |
| Width over mirrors | 4,076 | 4.076 |
| Cab height | 3,025 to 3,290 | 3.025 to 3.290 |
| Height to the top of the body | 4,290 | 4.290 |
| Height to the radar top | 5,890 | 5.890 |
| Front overhang, then the three axle gaps, then rear overhang | 2,995 + 2,350 + 3,900 + 2,200 + 1,000 | 12.445 summed |
| Track, centre to centre | 2,375 | 2.375 |
| Tyre outer span | 3,070 | 3.070 |

The five station numbers sum to 12,445 mm. The published length is 12,670 mm. The extra 225 mm is not assigned. Stage 2 should put it on the front bumper and keep the 1,000 mm rear overhang as written. Axle stations from the bumper, if that is accepted: 3,220, 5,570, 9,470 and 11,670 mm.

The implied tyre section is (3,070 − 2,375) / 2 = 347.5 mm. Use the span and the track. Do not invent a wider tyre.

Module sizes that are not on the sheet, estimated from the photos and flagged:

- Module B panel. In the side photo the flat array stands about one and a half cab-heights, so roughly 4.5 to 5 m of panel, on a pedestal behind the cab. The sheet's 5.89 m radar top is the Pantsir dish, not this panel. Do not reuse 5.89 m as the panel height.
- Module B cabin. A box behind the array, about cab height, with doors, vents and a side ladder. The mast with the small Yagi sits over the cab roof.
- Module C box. Four rectangular cells, two by two, lattice frames at the ends, raised by one hydraulic arm. No length is published here. Stage 2 traces the photos for proportion and does not lock a metre figure in this audit.
- Module C generator. A louvered box on the frame behind the cab, with a railing and a short mast. Four jacks with foot pads, one near each corner of the launcher bed.

## 3. Scale

Compared with meshes already on screen. The T-90 hull figure is the one measured for the Mi-8 audit (2.13 u on a 6.86 m hull). BMP-3 v2 is 2.22 u at 0.311. The reduced Mi-8 fuselage at 0.218 is about 4.0 u.

| | 0.311 u/m (tanks) | 0.24 u/m (live TEL) | 0.218 u/m (reduced Mi-8) |
|---|---:|---:|---:|
| Length 12.670 m | 3.94 u | 3.04 u | 2.76 u |
| Body width 3.150 m | 0.98 u | 0.76 u | 0.69 u |
| Mirrors 4.076 m | 1.27 u | 0.98 u | 0.89 u |
| Cab roof 3.290 m | 1.02 u | 0.79 u | 0.72 u |
| Body top 4.290 m | 1.33 u | 1.03 u | 0.94 u |
| Pantsir radar top 5.890 m | 1.83 u | 1.41 u | 1.28 u |
| Length vs T-90 hull 2.13 u | 1.85× | 1.43× | 1.30× |
| Length vs BMP-3 2.22 u | 1.77× | 1.37× | 1.24× |
| Length vs live Pantsir mesh 3.05 u | 1.29× | 1.00× | 0.91× |

The real truck is 12.67 / 7.14 = 1.77 times a BMP-3 hull. Only 0.311 keeps that ratio. It also makes the truck as long on screen as the Mi-8 after Malachi had that helicopter shrunk, and about 30% longer than the Pantsir mesh players already see.

**Proposed scale: 0.24 units per metre.** That is the scale the Iskander and Pantsir meshes already use, chosen so a 13 m truck fits the camera. The new chassis matches those two instead of outgrowing them. At 0.24 the truck is 3.04 u long, 0.76 u wide, cab roof 0.79 u, Pantsir radar top 1.41 u. A yes on 0.311 is the alternative if the truck should match the tanks and read clearly longer than the live Pantsir.

## 4. Part breakdown

One chassis builder, three module builders, joined at a bed frame behind the cab. Swapping modules is swapping that child, not rebuilding the cab and the axles. Stage 2 builds the chassis and module B only.

### Chassis, shared

- Ladder frame and a flat module bed from behind the cab to the rear overhang. Twist-lock pads at the four corners of the bed, so each module has somewhere to sit.
- Cab, forward. Roof at the 3,290 mm figure. Two-pane windscreen, a door window each side, mirrors out to the 4,076 mm width, a short bumper, lamps, a grille. No badge.
- Eight tyres on the four stations above. First two axles steer. Hubs, not gears. Fenders over each pair.
- Fuel tank and battery box on the frame between the cab and the second axle gap. Exhaust stack on one side of the cab. Spare wheel is not on this chassis unless a module's photo shows one. Module C's photo has a spare on the generator deck; that spare belongs to C, not to the bare truck.
- Flat surfaces get real fittings: door handles, a step under each door, cab grab rails, mudflaps, and a cable run along one frame rail. No text.

### Module B, radar

- Equipment cabin on the rear of the bed. Recessed doors, latches, hinge straps, a vent grille, a side ladder, and two stowage boxes. The cabin wall should not be one plain quad.
- Turntable and pedestal between the cab and the cabin.
- `RadarPivot` on the pedestal, yaw only. One flat panel, slightly thicker at the rim, with a grid of shallow ribs on the face so the array reads at gameplay zoom. The back of the panel gets the hinge arms, a junction box and a cable loop. Not a second texture.
- Mast on the cab roof: a pole and a small Yagi. It does not spin.
- No missile racks, no guns, no outriggers. The cylinders beside the panel in the front photo are not part of this module.

### Module A, anti-air

Built later, on the same bed.

- Long equipment body behind the cab: grilles, a side door, a ladder, stowage boxes. Body top at 4,290 mm.
- Turret ring on that body. `TurretPivot` yaws.
- Search radar on a hinge above the turret. The live Pantsir names this `Radar` and folds it for travel. Keep that name on A so the existing plant animation still folds it.
- Tracking radar on the turret front.
- Two racks of six tubes, one each side, on their own elevate pivots.
- Twin autocannon barrels as `Barrel`, with `MuzzleL` and `MuzzleR`.
- Four outriggers. See the deploy note below.

### Module C, cruise missile

Style from the three photos, on our cab, in `#96A468`. No lettering on the canisters.

- Generator box behind the cab, louvres, a railing around a small deck, a spare wheel lying on that deck, a thin mast.
- Four jacks with round foot pads, parented under `Outriggers`, named so the existing left/right swing in `VehicleView` still works (`LegFR`, `LegFL`, `LegRR`, `LegRL`).
- A turntable on the bed (`TurretPivot`, yaw).
- One hydraulic arm and an elevating frame (`Barrel`, so the artillery elevate path lifts it).
- Four boxed cells, two wide and two high. Lattice end frames. Nose cones stay inside the boxes in the travel pose. The raised pose opens the front lattice.
- Travel pose: box lowered along the bed, jacks up. Deployed pose: jacks down, box raised. The view already animates both, on `plant` and on `elevate`.

## 5. Nodes

```
Root                         VehicleView, selection_radius, bar_height
  Model
    Hull                     chassis mesh only
    Module                   one of B, then later A or C
  HealthBarAnchor
```

Module B under `Module`:

```
Cabin
RadarPivot                 yaw while the aura is active; not named Radar
  Panel
Mast
```

Module A adds `Outriggers`, `TurretPivot`, `Radar` (the folding search hinge), `Barrel`, `MuzzleL`, `MuzzleR`. Module C adds `Outriggers`, `TurretPivot`, `Barrel`.

At 0.24, selection radius 1.6 and bar height 1.9 clear the radar panel. Module A's bar stays near the live Pantsir's 2.45 if the dish folds up to 1.41 u. These move with the scale decision.

`WorldView` spins a node only when its name contains `Rotor`. Module B needs a separate slow yaw on `RadarPivot` while the truck is halted. Do not name the panel `Rotor`, and do not name it `Radar`: that name is the Pantsir fold hinge.

## 6. Module B gameplay

Design only. Numbers below are the proposal.

### Sight

**Sight 20 tiles.** It is the longest sight in the roster, and it stays on while the truck is moving. Detection uses the same number.

Values compared, from `UnitDef.sight`:

| Unit | Sight | Why it is in the list |
|---|---:|---|
| T-90M, T-14, BMPT, most tanks | 8 | Typical armour. |
| BMP-3, BTR, Iskander | 9 | The current missile truck. |
| Msta, helicopters, Tu-160, Grim Reaper | 10 | Top of the ordinary ground and air band. |
| Su-57, F-16 | 11 | Fighters. |
| Pantsir, Sentinel, JTAC, US Reaper drone | 12 | Best current ground sight, and the only detector. |
| TPLA Insurgent | 13 | Best infantry sight. |
| US scout drone | 16 | Best sight of any unit. Not a detector. |
| Proposed MZKT radar | 20 | 1.25× the scout drone, 1.67× Pantsir. |

`range_mt / 1000` is the tile count. Maps in `data/maps`: 128 tiles (Severny Bridge, Twin Ridges, Prairie Crossing, Qanat Gate, Rheinbruck), 192 (Harvest Valley), 224 (Sunfall Basin), 256 (Varno Crossing and the other large maps).

A 20-tile sight is a disc 40 tiles across. On Varno that is 16% of the map width, about 2% of the area. On a 128-tile map it is 31% of the width, about 6% of the area. Pantsir at 12 covers 2.8 times less ground (area scales with the square of sight). Going to 24 would put a 48-tile disc on the small maps, 37% of their width. 20 is the large step past the scout drone without covering a small map. 18 is the fallback if 20 feels wide on the 128-tile maps.

### Stealth

`detector = true`. Anything already hidden from a Sentinel is hidden from this truck out to 20 tiles, and visible inside that.

That flag, as written in `UsSys` and `TplaSys`, reveals all of these inside sight, not only infantry:

- `stealth_still`, `stealth_fire`, `stealth_combat`, `stealth_always` (snipers, marksmen, FSB soldiers, insurgents, SEALs).
- `stealth_air` (YF-22) at the detector's full sight. Ordinary ground units only spot it at contact range.
- `stealth_defense` and `low_sig`.
- Hidden structures: mines, traps, camo. A detector is not limited to units.

Recommend using the existing flag. A stealth-units-only detector would be a new rule. The structure reveal is the consequence to accept or to reject.

### Artillery range aura

Friendly artillery within **12 tiles** of the radar gets **+25% attack range**. The check is a boolean. A second radar covering the same gun does not add another 25%.

12 tiles is Pantsir's sight and is smaller than the radar's own sight, so the truck sees farther than it buffs. A gun has to sit with the radar, not anywhere in the 20-tile vision disc.

Who has the `artillery` tag in the Russia roster, and what +25% does. Integer math is `range_mt * 5 / 4`. Minimum range stays put, so the buff does not grow the dead zone.

| Unit | Tag extras | Range now | With the aura | Counts? |
|---|---|---:|---:|---|
| TOS-1A `ecc_tos` | none | 4.8 | 6.0 | Yes. |
| 2S Msta `ecc_msta` | `spg` | 15.0, minimum 4.0 | 18.75 | Yes. |
| Iskander `ecc_iskander` | `setup` | 15.0, minimum 5.0 | 18.75 | Yes. It still needs its own 5 s setup to fire. |
| Grim Reaper `ecc_reaper` | `deploy` | 21.0, minimum 6.5 | 26.25 | Yes, by the tag rule. This is the balance risk: the longest shot in the faction grows by 5.25 tiles, and on a 128-tile map 26 tiles is a fifth of the width. Exclude it if that shot should stay capped. |
| Module C, when it exists | `artillery`, plus deploy | unset | +25% of whatever its weapon is | Yes. It is a cruise-missile launcher, the same family as Iskander. It does not generate an aura. Two module-C trucks do not buff each other. |
| Module A / Pantsir | `aa`, not `artillery` | SAM 12.0 | unchanged | No. The aura does not extend anti-air range. |
| Silos, towers, the Tu-160 | not the unit tag | | unchanged | No. |

The aura buffs units with the tag whose **owner** is the radar's owner. The shield aura uses team, which would also buff an ally's Longreach, Thunderhead, Blight or Shrike. Owner is the tighter rule. Say if allies should receive it.

The radar truck itself has no artillery weapon, so it never buffs its own shot.

**The aura works only while the truck is halted.** No outriggers and no 8 s deploy on module B. The photos show a panel on a turntable, not jacks. Proposed gate: not moving, and `still >= 20` ticks (1 second), so a stutter does not flicker the bonus. A move order drops it on that tick. Sight and stealth detection stay on while it drives. The alternative is an 8 s deploy, matching Pantsir, which would force jacks the reference does not have.

What has to be added later, when this leaves the audit:

- Two fields on `UnitDef`, `range_aura_radius` and `range_aura_pct`, default 0. Hard-coding the unit id works for one truck and is worse the moment a second faction wants the same trick.
- The same yes/no test in `CombatSys._fire_unit` and `OrderSys.max_range`.
- A ring in the view, the way the shield dome is drawn, so the 12-tile buff is visible. Radius only. No new texture.

Balance risks to decide with the numbers:

- No stacking. Already the recommendation. Two radars are redundancy, not +50%.
- Grim Reaper to 26.25 tiles. The sharp one.
- Module C's base range is unset. Until it has a weapon, do not assume it outranges Iskander. A 15-tile start matches Iskander and becomes 18.75 in the aura.
- The truck is a detector with a 20-tile sight that also reveals mines and stealth aircraft. That is a lot for one chassis even before the aura. Cost and the Ministry gate are still open; see the decisions.
- The aura does not care whether the artillery is set up. Iskander and the Reaper still wait out their own timers before they can use the extra range.

## 7. Deploy, modules A and C

Module A was planned as a deploying anti-air unit, and the live Pantsir already is one: 8 s, outriggers, folding search radar, and neither the gun nor the SAM fires until that timer ends. The new turret photos are the same family. The jacks are on the live mesh.

**Keep the outriggers and the 8 s deploy for A.** Dropping them lets a 12-tile anti-air truck fire on the move. That is a balance change, not an art change. A later option is to let the autocannons fire while mobile and keep the missiles deploy-only. The sim today gates the whole unit, so that split would be new.

Module C follows the missile photos: jacks down, then the box raises. Use the same 8 s `deploy` tag as the Grim Reaper, because the animation is a plant-and-raise rather than Iskander's shorter setup. Travel pose is the box along the bed. It cannot fire until the timer ends.

Module B does not deploy.

## 8. How the permanent pick works

The factory card stays icons. One new chassis icon in `ecc_factory.produces`. Iskander and Pantsir stay in the menu until a later pass explicitly replaces them. Building A now and deleting Pantsir in the same step would remove a unit players already have.

The chassis spawns with no weapon and no detector, sight 9, the same as Iskander. It can drive and it can be shot. On its command card, three icon buttons, names only in the tooltip, the same pattern as the tower fittings:

- Radar dish — module B.
- Combined turret — module A.
- Box launcher — module C.

The click swaps the definition, the scene, the weapons and the tags in place. Hit points carry over as a fraction of the new maximum. The three buttons go away. There is no undo in this design.

There is no code path for that swap yet. `UnitDef.abilities` is not read by the HUD. It is a small new order, not a reuse of research or of the tower fitting (those write a player upgrade or a building extra, and they do not change `def_id`).

Gates that do not survive a single chassis price, left for a decision:

- Pantsir costs 2100 and needs the Ministry. Iskander costs 2400 and does not. One chassis cannot keep both rules unless the buttons check them separately.
- Recommendation: the chassis builds with no Ministry gate. Button A stays disabled until the Ministry exists. Buttons B and C do not. Each button can charge its own cost on top of a hull cost, or the hull can be the full price and the buttons free. This audit does not set the prices. B is the strong one: sight 20, stealth, and a buff to every artillery piece. It should not be the cheap button.

Until a button is pressed the hull is a moving target with no gun. That is acceptable if the hull was not free. Forcing the pick before the unit can leave the factory is the alternative, and it needs a hold on the rally point that production does not have today.

## 9. Risks

- Scale. 0.311 matches the tanks and makes a 3.94 u truck, as long as the reduced Mi-8. 0.24 matches the trucks already on screen and shortens the real 1.77× BMP-3 ratio to 1.37×.
- The 225 mm gap between the axle stations and the published length.
- Module B's panel height is an estimate. The 5.89 m figure is module A's dish.
- Naming the panel `Radar` would fold it if a deploy timer is ever added. Use `RadarPivot`.
- The range bonus has to land in both the shot check and the move check, and it has to be integer and non-stacking.
- Grim Reaper at 26.25 tiles, and a 20-tile detector that also sees mines and stealth aircraft.
- A and C both want `Outriggers` and `Barrel`. They can share the view code. They must not share a mesh.
- Flat cabin walls and the panel back go plain unless the doors, ladder, vents and cable loop are actually built. That is the same note as the Mi-8 cabin.
- Photos contain plates, badges, stencil text and woodland camo. None of that is modelled.
- Triangle budget is a Stage 2 problem. The live Pantsir is the comparison point, not a cap set here.

## Decisions before Stage 2

1. Scale: 0.24, as proposed, or 0.311 to match the tanks.
2. Module B sight: 20, or 18 if the 128-tile maps matter more.
3. Aura: 12 tiles, +25%, no stacking, owner only, halted for 1 s, tag `artillery` including module C and the Grim Reaper. Say if the Reaper is excluded, if allies are included, or if B should deploy for 8 s instead of simply stopping.
4. Detector uses the existing flag, including mines, traps and stealth aircraft. Say if that should be units only.
5. Module A keeps its outriggers and the 8 s deploy.
6. The factory builds a bare chassis. The three icon buttons are the permanent pick. Iskander and Pantsir stay until a later pass. Prices and the Ministry gate on button A are still open.

## What was checked, and what was not

Checked in the repo: `ecc_factory.produces`, the five Russian artillery and anti-air definitions, their weapon `range_mt`, `UnitDef.detector` and `shield_aura_*`, `UsSys` stealth masks, `TplaSys.DETECT`, `RosterSys` jammer and heal aura, `PowerSys` shields, `CombatSys._fire_unit`, `OrderSys.max_range`, `EccSys.DEPLOY_TICKS`, `UsSys.SETUP_TICKS`, `VehicleView` plant and elevate, the Pantsir and Iskander builders in `ru_hulls.gd`, and `MapDef.size` on every map. The five reference photos were read.

Not checked: no Godot run, no measurement of the photos, no published metre figure for the flat panel or the cruise-missile box beyond the estimate flagged above. The axle-sum gap is reported, not resolved.
