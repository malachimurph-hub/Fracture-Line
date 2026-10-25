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
