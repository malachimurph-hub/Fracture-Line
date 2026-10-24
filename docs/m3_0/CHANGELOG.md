# Rules of Engagement M3.0 (work in progress, branch m30; no release build yet)

Naming rule: real military designations are used in game text; company and brand names are not.

## A. United States
- **M1A3** (was Halberd MBT): desert tan finish (new camo pattern 3, solid tan with soft tone variation).
- **JLTV** (was Lynx JLTV): desert tan.
- **MAAS - Mobile Anti Air System** (was Picket SHORAD): desert tan.
- **NEW: M3 Bradley** (US only): desert tan, 25mm chain gun (20 dmg, 6-round bursts, hits ground and air), carries
  6 infantry who can fire from inside. 1000 cost, 820 HP. Built at the Motor Pool. Uses the JLTV voice set.
- **M777A2** (was Fire Base): emplaced towed 155mm howitzer with splayed trails, spades, a double-baffle
  brake and recoil cylinders, behind a sandbag ring with ammo. Balance unchanged.
- **LPWS** (was Bulwark SAM battery): C-RAM look, a white radome rotary-gun mount on a flatbed trailer
  with a generator. The weapon is now a rotary gun (tracers) with the same DPS as before.
- **Anti Armor Soldier** (was the 2-man Javelin Team): one soldier, 160 HP (was 260), 350 cost (was 500),
  same missile. Keeps its voices.
- **M1083A1P2 Supply Truck**: remodelled as the 5-ton FMTV 6x6 cargo truck (flat-front cab, three axles,
  canvas-covered bed), olive green.
- **Data Center** replaces the US **Supply Drop Zone**. That was the only US-buildable passive-income
  structure (us_drop_zone, +4 income). It is now a server hall with roof chillers, generators and a fence.
  Same id and balance. The neutral map supply stashes are untouched.
- **US buildings redesigned**, with blinking red rooftop beacons on all of them (Airfield included):
  - Supply Depot: grey warehouse with three bay doors and a loading dock.
  - Headquarters: Pentagon-style five-sided ring.
  - Barracks: three-storey brick dorm with a flagpole out front.
  - Motor Pool: the old Garage, renamed. Same design plus the lights.
  - Fusion Plant: the same design, now all white with no green.
  - Strategic Center: an office tower with a mix of lit and dark windows.
- Voice lines that spoke an old unit name (Halberd, Lynx, Picket, Javelin) were dropped where the unit had
  another line for that event.

- **US paint (Malachi's final choice):** desert tan for the M1A3, JLTV, MAAS, M3 Bradley and Harrier Gunship.
  The original US olive-green finish for the Dozer (keeps its safety-yellow blade and cab), the M1083A1P2
  Supply Truck and the Longreach Howitzer. The Wraith and Thunderlance jets stay dark grey.

## B. Environment
- **Trees**: alpha-cut leaf cards on visible branches (oak, pine, snow pine, palm, scrub, bush). Each kind
  has 3 shape variants, picked per tree. The leaf atlas is self-generated: `tools/m30/gen_leaf_atlas.py`.
- **Civilian buildings**: towers get window mullions, lit windows, blinking aviation lights on the roofs
  (and on antenna tips) and kerb plinths. Shops get lit fronts and glowing signs. The gas station gets
  canopy lights and a lit sign, and the shack gets a lit window, an AC box and a flue.
- **City streets**: raised sidewalks with kerb stones and joints, solid white edge lines, and zebra
  crossings at junctions. This is in addition to the existing dashed centre lines.
- **Mountains and hills**: cliff massifs now rise with distance from their edge, with smooth multi-octave
  relief instead of per-vertex spikes. Their inside corners are chamfered, so there are no tile stair-steps.
  Rock uses triplanar projection (no stretching on the faces), with strata bands, crevice shading,
  sun-bleached ledges and dust or grass on flat ledges. Boulders are faceted, in 3 variants. The M2.9
  anti-tiling and smooth-blend rules still apply.
- **Civilian cars**: real-world scale next to the units (about 0.25 tile per metre, so a sedan is 1.15
  long), with wheel arches, glasshouse pillars, raked screens, mirrors, grille, lamps, plates and hubs.
  The taxi sign and headlights glow.

## C. Europe
- **Panther Tank** (was Leopold): it keeps the M2.7b Leopard 2A6-style model (wedge turret, L55 gun).
- **LTV - Light Tactical Vehicle** (was Wolfhound): remodelled after the Sherpa Light, with a .50 cal on a
  roof ring and a gunner shield. The weapon is now a .50 cal HMG.
- **NEW: Boxer IFV**: 8x8 with an unmanned 30mm turret. It carries 6 infantry who can fire from inside.
  1100 cost, 880 HP. Built at the Motor Pool. Uses the LTV voice set.
- **RCH SPA** (was Thunderhead): 6x6 wheeled 155mm with an armoured cab and an unmanned rear gun module.
  Balance unchanged.
- **Thunderbolt** (was Flakwerk): Poprad-style light 4x4 with a sensor head between two 2-round MANPADS
  pods. The flak gun is replaced by AA missiles (air only, same sustained DPS).
- The **Hearth** stays as the light rocket artillery.

## Also
- In-game text no longer uses brand names: the TPLA "Mirage Fighter" is now the **Delta Fighter**, and
  "Toyota-style" was dropped from the Technical's description.

## D. Factions become single nations
- **EU Alliance is now Germany**, **TPLA is now Iran**, and the planned **ECC is now Russia** (still "coming later"
  in the lobby). The US is unchanged. This leaves room for more nations later.
- Updated the faction names in the main menu subtitle, skirmish lobby, Map Builder palette headings and HUD, plus
  the descriptions and tooltips that named the old factions. "Outside the EU Grid" is now "Outside the power grid".
- Faction badges are now simple roundels in the national flag colours: black-red-gold for Germany,
  green-white-red with a red centre dot for Iran, white-blue-red for Russia. The US star roundel is unchanged.
  The lobby faction picker shows a small flag next to each name. All of these are original, simple designs.
- Units and models are unchanged for now. Internal ids (`eu_`, `tpla_`, `ecc_`) stay the same.

## E. National rosters
Germany and Iran now use real-world equipment roles. Internal ids, costs, HP and roles are mostly unchanged.
- **Germany, new models:** the LTV is now a Dingo/Eagle-style armoured 4x4 with the roof .50 cal. The Thunderbolt
  is a Wiesel Ozelot-style tracked missile carrier. The Hearth is a MARS II-style rocket launcher with the same
  balance. Also new: Puma IFV, Fuchs ECM Carrier, Fuchs EW Jammer, Fennek Recon, Heavy Tank 130 (single
  130 mm gun), Tiger Attack Helicopter, Multirole Fighter (canard delta, grey) and a gas-turbine Power Plant.
- **Germany, name and role swaps:** Salamander flame tank → Puma IFV (keeps the old weapon stats, fires autocannon
  tracers). Aegis shield → Fuchs ECM Carrier (same protection aura). Spectre → Fuchs EW Jammer.
  Sentinel → Fennek Recon. Brennus → Heavy Tank 130. Lancer → Panzerfaust 3 Soldier. Crawler → Engineer Vehicle.
  Hauler → Logistics Truck. Fusion Reactor → Power Plant. Flak Tower → Air Defence Gun. Relay → Repair Post.
  Exchange → Logistics Centre. Shield Overcharge → Smoke Screen.
- **Germany, aircraft now work:** Kestrel (stub) → Tiger Attack Helicopter (anti-tank missiles and gun, attack
  helicopter stats). Corvid (stub) → Multirole Fighter (missiles and guided bombs, jet stats, 2 parking slots).
  The Airstrip is now a real Airfield with 6 parking slots. The German AI builds an Airfield in the late game.
- **Germany, removed:** the Grid Blackout stub power. **Artillery Barrage** (a strike power) replaces it.
- **Iran, new models:** the Technical is a Safir-style military jeep with a DShK. Koksan → Raad-2 Howitzer
  (155 mm SPG). Falcon → F-4E Strike Jet. Delta → Kowsar Fighter (F-5-style).
- **Iran, renamed:** Insurgent → Basij Scout. BMP-2 → Boragh IFV. BHX-35 → Samavat SPAAG. Den → IRGC Headquarters.
  Stash → Supply Depot. Militia Camp → Basij Barracks. Chop Shop → Vehicle Factory. Night Bazaar → Trade Exchange.
  Demo Trap → Anti-Tank Mine. Hole → Rebuild Site. Wasp Nest → Missile Battery. Uprising → Basij Mobilisation.
  Blight Shells → Fateh Missile Barrage. Ambush → Basij Ambush.
- **Iran, removed:** the Scrap Rain crate drop. **Shahed Drone Strike** (a strike power at the enemy's biggest
  group) replaces it.
- **Kept as is (names Malachi chose):** Panther Tank, Boxer IFV, RCH SPA, Thunderbolt, Hearth, LTV, Striker,
  Technical, Backhoe/Supply Pickup and MiG-29. The F-14 was not added (too much work), so the MiG-29 stays.
- Voice lines that say an old name are dropped where the unit has another line for the same event.

## F. Russia
Russia is now playable in the skirmish lobby (no longer "coming later"), in the Map Builder palette and for
the skirmish AI. Internal ids stay `ecc_`. The default paint is Russian green camo.
- **Malachi's units:** T-90M (MBT, 125 mm, close to the Panther), Tiger-M (light armoured 4x4, roof HMG,
  carries 5), BTR (BTR-82A-style 8x8, 30 mm, carries 7, close to the Boxer), Typhoon (heavy MRAP, remote HMG,
  carries 10), 2S Msta (tracked 152 mm howitzer, needs a Supply Depot), Zeus (quad 23 mm AA).
- **Infantry (single soldiers):** Rifleman (AK-74), Machine Gunner (PKM, high rate of fire, strong against
  infantry and weak against armour), RPG Man (RPG-7V3, anti-tank), Infiltrator (elite, AK-12 and grenades,
  hidden while still, needs the Vehicle Factory).
- **Stand-ins so Russia is playable (pending Malachi's list):** Engineer Vehicle (builder), Cargo Truck
  (gatherer), Headquarters, Power Station, Supply Depot, Barracks, Vehicle Factory, Defence Bunker (autocannon)
  and Air Defence Site (SAM). They are Russian-styled and follow the US power economy. There is no airfield,
  because Russia has no aircraft yet.
- **Powers (stand-ins, they reuse existing power types):** Recon Drone, Supply Convoy, Artillery Strike,
  Field Repair.
- **AI:** new "Steppe" personality. It opens Power, Depot, Barracks, Power, Factory, Bunker, then leans on the T-90M.
  It caps infantry, Machine Gunners, Infiltrators and Msta so the army stays tank-led, and it buys and uses the
  four powers.
- **Weapon effects:** all Russian weapons have tracer, shell, rocket and missile effect classes.
- **UI:** Russia theme (dark olive, red frame, gold accents), Map Builder colour, weathering preset.
- **Voices:** 97 lines under `audio/voice_ai/ecc/`. Most are reused male Iran lines that don't say a unit or
  faction name. There are 5 new Russian-accent Chatterbox lines for the T-90M and Machine Gunner. The announcer
  reuses the US announcer.
