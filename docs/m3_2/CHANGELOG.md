# M3.2 changelog (branch m32, in progress; Russia still locked as "Coming soon")

M3.2 is a combined release. It starts with Russia; more items will be added before release.

## Russia: buildings (Malachi's list, all models original and procedural)
- **Kremlin (HQ)**: red-brick walls with swallowtail merlons, towers with green tent spires and
  ruby stars, a clock gate tower, a cream palace with a green roof and flag dome, and a
  white cathedral with gold onion domes. The brick gate house's arch lines up with the HQ exit tile
  (local x +0.5, front), so Engineer Vehicles drive out of it.
- **Supply Depot, Barracks, Vehicle Factory**: brutalist, with raw concrete slabs, repeating deep-set
  window grids, pilotis and heavy cantilevers. The depot has a cantilevered dock roof on raking
  legs. The barracks is a slab block on columns. The factory is a finned hall with sawtooth roof
  lights and a cantilevered office bridge over the doors.
- **Gas Processing Plant (power)**, Amur GPP style: three processing columns with platforms,
  two spherical tanks, a pipe rack, a burning flare stack and a control room.
- **Ministry of Defense (new, tech)**: a Stalinist stepped tower with a spire and star over
  a colonnaded stone wing. It unlocks the Tu-160 and the Black Market.
- **Black Market (new, passive income)**: a warehouse trading post with containers, striped
  stall awnings, crates and string lights. Same numbers as the US Data Center: $2500, 20 s,
  3x3, passive income 4, and it needs the Ministry of Defense.
- **Kornet Nest** (was Defence Bunker): a sandbag ring with two tripod 9M133 Kornet launchers.
  New weapon `ecc_kornet` (anti-tank missile, 95 dmg, 8.5 tiles, 2-round clip, ground only).
- **ZAK-30 Citadel** (was Air Defence Site): a naval-style turret with twin six-barrel 30 mm guns
  on a concrete plinth. New weapon `ecc_zak30` (air only, 24-round bursts).
- **Airfield (new)**: the shared 8x8 air base, using the M3.1 taxi, runway and hangar layout
  with 6 slots, in Russian colours with a flag.
- Engineer Vehicle and Cargo Truck kept and polished. The engineer has tool boxes, spare track
  and a rear beacon; the truck has a spare wheel, roof hatch, tool box and mud flaps.

## Russia: aircraft
- **Su-57** fighter: R-77 air-to-air missiles plus guided bombs. $1500, 2 slots (cloned from
  the Wraith).
- **Tu-160** heavy bomber: white swing-wing bomber, about 3.1 tiles long, so it fits a two-bay
  (4-slot) park. Big and slow: speed 4.3 (Thunderlance 4.8), 1050 hp, turn 95 deg/s. Its
  bombing run drops four bombs of 240 dmg each (2.6-tile splash, slight scatter), then it lands
  to rearm (52 s). $2800, needs the Ministry of Defense.
- **Ka-52** attack helicopter: coaxial counter-rotating rotors, side-by-side cockpit, Vikhr
  missiles and a 30 mm cannon. $1600, no slot (hovers).
- All three have new Russian-accent voice lines (select, move, attack, under fire; created
  and veteran reuse them).
- `world_view`: rotors honour a `rotor_dir` meta (coaxial counter-rotation), and heavy bombers
  with a selection radius above 1.25 cast a larger shadow.

## Russia: AI
- Roles: tech is the Ministry of Defense and income is the Black Market. The airfield is built
  after the Ministry: at 13 min on hard or 16 min on medium, never on easy, and only with more
  than $2400.
- Russia uses the shared AIPlayer air layer like Germany: jets fly sorties and are reserved
  from ground waves, and airfield slots are checked before queuing.
- Personality weights were added for the Ka-52 (2), Su-57 (1) and Tu-160 (1).
- Powers kept: Recon Drone, Supply Convoy, Artillery Strike, Field Repair.

## Tools
- `tools/gfx_m32/ru_m32.gd`: generators, merged after `ru_m30` in `us_m7.jobs()`.
  `_airbase8` gained an `ecc` palette.
- `tests/m32_preview.tscn -- buildings|air out.png`: preview renders.

---

# M3.2 part 2: Malachi's new items (same combined release, no APK)

## 1. M777A2 emplacement
- The Firebase pad is now ringed by concrete Jersey barriers (gap on the ammo side) on a gravel
  pad, instead of sandbags (`tools/gfx_m32/new_m32.gd` `us_firebase`).

## 2. AA turrets shoot ground too
- Each AA structure keeps its air weapon (now air-only) and gains a weaker ground-only weapon,
  so AA is never a better ground defence than the AT bunkers:
  Patriot `us_patriot_gnd` (9 dmg hmg, 7 tiles), Flak Tower `eu_gatling_gnd` (7 quad),
  Wasp Nest `tpla_wasp_gnd` (14 AT, clip 3), ZAK-30 `ecc_zak30_gnd` (7 quad, clip 24).
  Test: air DPS > ground DPS for all four.

## 3. US Drone Operator
- New research **Drone Warfare** (`us_up_drones`, $1500, 30 s) at the Strategic Center. Upgrades
  are unit defs tagged `upgrade`: they are researched once and stored in `SimPlayer.upgrades`
  (saved). `prereqs_met` honours them.
- **Drone Operator** (`us_drone_operator`, Barracks, $600, needs Drone Warfare). The command
  card has **Bomb Drone** and **Scout Drone** buttons. Each spawns a selectable, controllable
  drone at the operator. A drone that is used or lost comes back after 60 s; the button shows
  the countdown.
  - Bomb drone: fixed-wing loitering munition, 260 AT dmg + splash, one-way (suicide).
  - Scout drone: unarmed quadcopter with 16-tile sight.
- The AI (US) researches Drone Warfare, keeps about 1 operator per 10 combat units, launches
  bomb drones when enemies are near, and sends them at the closest visible vehicle.

## 4. Funds cap $2,000,000
- `SUPPLY_CAP` is 2,000,000. Start money options now include $100k, $500k, $1M and $2M.
- The HUD shows money with thousands separators, and the font steps down for 7 digits.

## 5. Germany Field Engineer
- `eu_field_engineer` (Barracks, $450, rifle). It builds barricades and AT minefields only, and
  repairs structures (the builder repair order). While standing still it also repairs the most
  damaged own vehicle within 2 tiles (2% max HP per 0.5 s, free), with welding sparks.

## 6. Barricades
- **Sandbag Barricade** ($100, 700 HP) and **Concrete Barricade** ($250, 1600 HP) for all four
  factions, 2x1. Builders and Field Engineers can build them.
- Select infantry and tap an own barricade to man it (max 3). Manned troops are protected and
  fire from cover with the garrison range bonus. The barricade card has an Exit button with a
  count, and the world overlay shows n/3. When the barricade is destroyed, the troops are
  ejected.

## 7 and 8. No unit cap, queue 15
- The pop cap is effectively removed (1,000,000; old saves are raised on load). The AI keeps a
  soft limit of 90 for performance.
- Production queues hold 15 per building.

## 9. Bridges
- Real bridge model, built per tile in a span frame:
  - Asphalt deck on a concrete slab, with a dashed centre line, white lane dashes, expansion
    joints and patches.
  - Curbs and edge lines, steel railings and a riveted through-truss (chords, verticals, X
    diagonals, gussets, lateral struts) on the water sides.
  - Three girders and cross-beams under the deck.
  - Concrete piers with caps and cut-waters every 3 tiles.
  - Abutments, wing walls, portal pylons and approach ramps where the span meets land.
  - Lamp posts.

## 10. Graphics: "Zero Hour look" pass
- **Grade:** cooler, darker ambient (warm sun vs blue shadows), much less haze, higher contrast,
  and saturation tuned per biome. Crisper, darker sun shadows.
- **Glow:** soft-light bloom on Ultra and High (off on Medium and Low).
- **Terrain shader:** painterly warm/cool patches and mid-scale mottling, cavity AO from the
  NRAO maps baked into the albedo, and darker steep slopes.
- **Model shader:** hand-painted bevel edge highlights (sun side), stronger form shading (darker
  undersides, brighter tops) and a stronger rim lift.
- **Ground scatter:** dense grass/scrub tufts and pebbles (MultiMesh per chunk, fog-aware, no
  shadows). Density follows the preset: Ultra 1.0, High 0.6, Medium 0.3, Low off.
- **Explosions:** white-hot core flash, inner fireball, spark spray, a black mushroom smoke
  column and a shock ring on big blasts. Burning wrecks get denser smoke, hotter flames and
  embers.
- Ultra stays the default. No new textures were added, so the APK size impact is about zero.
- Before/after: `builds/m3_2/preview/m32_gfx_before_after.png`.

## 11. Faction battle music
- `tools/gen_music_m32.py`: four new original numpy-synthesised tracks:
  - US: "Liberty Steel" (military rock). It joins the 3 existing rock tracks.
  - Russia: "Red Bounce" (hard-bass techno).
  - Germany: "Tiefgarage" (Berlin club techno).
  - Iran: "Zagros" (daf, tombak, war booms, santur tremolo and tar-like plucks in a Shur-style
    mode with a koron 2nd).
- Battle music follows the local player's faction. The menu stays rock (Breach Point).
- About +5.3 MB OGG.
- Samples: `builds/m3_2/preview/m32_music_{us,russia,germany,iran}.ogg`.

## 12. Capture specialists (ZH-style)
- US **Breacher**, Germany **Sturmtrupp** and Russia **Saboteur** are new: Barracks, $350,
  120 HP, sidearm. The existing Iranian **Insurgent** gains the ability.
- Select one and tap an enemy (or neutral) structure. It walks up and captures in 6 s, shown by
  a gold progress bar over the structure. Moving away or dying cancels the capture.
  Minefields, walls and traps can't be captured.
- On capture, ownership transfers: the queue is dropped and garrisons are ejected. The
  captor keeps the original faction's build list (Zero Hour style), and the unit survives.
- The AI trains one specialist after 4 minutes and sends it at lightly guarded visible
  enemy structures.

## 13. Press-and-hold info cards
- Holding any build, train, research or drone button for 0.4 s, or a selection type chip, the
  portrait, or a General-tray power row, shows a compact card. It works on locked buttons too.
  Releasing hides it, and the release never builds. A normal tap still builds.
- The card shows:
  - Name, cost and build time, plus pop and size.
  - The one-line description.
  - HP, armour, speed and sight.
  - Each weapon's damage, range, rate and air/ground targets.
  - Good vs / weak vs, derived from the combat table.
  - Missing prerequisites.
  - For buildings: power +/-, income per minute, what it trains and unlocks, garrison, air
    slots and free unit.
  - For powers: rank, cost, cooldown, radius and duration.
- Every number comes from the defs (`ui/hud/info_card.gd`).
- Queue cancel is now a right-click or a queue-chip tap, because long-press shows the card.

## Tests
- `roster` gains `_roster_m32`: queue 15 and $2M cap, AA ground vs air DPS, Field Engineer build
  rules, capture (cancel by moving, success in about 6 s, captured camp trains its original
  units), barricade max 3 and exit, research once and unlock, drone launch, and the 60 s
  replenish.
- `audio`: faction playlists load and are distinct.
- UI text test (`HudTextCheck`):
  - Every info card on every faction card is translated, data-driven (income, power, turret
    range present) and on screen.
  - A hold-gesture check: the card shows on locked and ready buttons and the release does not
    build.

## M3.2: Russia unlocked
- Russia (Malachi) is now selectable for players and AI in every lobby slot, listed in the Map Builder and resolved by the lobby. The "Coming soon" lock is kept for future factions (`"enabled": false` in `Content.FACTIONS`). `m30_lock_test` was rewritten to check that Russia is playable.
