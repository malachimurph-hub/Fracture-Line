# FRACTURE LINE: 1:1 roster map to C&C Generals: Zero Hour (M2.4)

Zero Hour (ZH) is used **only as a structural reference**: which roles exist in each base faction,
and how they gate each other. The checks were made against EA's GPL-3.0 source release at
/workspace/reference/cnc-zh and public knowledge of the game.
- The source names the faction templates (e.g. `ChinaNuclearMissileLauncher`, `GLAScudStorm`,
  `ChinaTankOverlord*`), but the INI data with the unit stats is not in the release.
- Every FRACTURE LINE name, model, sound and number is original. Costs and times are our own tuning.
- ZH names appear only in the left column of this design document, as the reference role. They
  never appear in the game.

## Faction mapping

| FRACTURE LINE | ZH base faction | Why | In this build |
|---|---|---|---|
| **TPLA** | GLA | Insurgents, tunnels, salvage upgrades, toxins, cheap swarms, no power, holes that rebuild (GDD §3, §21) | Yes |
| **EU Alliance** | China | Heavy armour in mass, attrition, slow late-game front, power grid, EMP and jamming. The GDD gives no explicit ZH mapping; the EU is the closest match to China's tank-and-mass doctrine | Yes |
| United States | USA | Air power, drones and precision strikes (GDD §3). Malachi is designing the roster (see the US section) | No. Planned in this document |
| Western Alliance | Spread across ZH USA and China roles: special forces, stealth infantry, artillery, fortification. There is no clean 1:1 | | No (M5) |

**Status key**
- **exists:** already in the game before M2.4.
- **added:** new in M2.4 as a real, working unit or structure.
- **stub:** in the build tree with a model, but its core mechanic is not implemented; shown as `[STUB]` in game.
- **later:** not in M2.4.

Tier key: T0 base, T1 basic production, T2 needs a T1 production building, T3 needs a tech centre.

---
## EU Alliance (ZH China)

### Vehicles
| ZH role (reference) | FRACTURE LINE | Role | Cost / build s / tier | Prereqs (built at) | Special | Status |
|---|---|---|---|---|---|---|
| Dozer | **Construction Crawler** | Builder | 1000 / 10 / T0 | HQ | Armoured builder | exists |
| Supply Truck | **Harvester Rig** | Gatherer | 800 / 10 / T0 | Logistics Hub | Free MG turret, 400 per load | exists |
| Battlemaster | **Leopold MBT** | Main battle tank | 1000 / 12 / T2 | Heavy Factory | Turret 75°/s | exists |
| Overlord | **Brennus Siege Tank** | Super-heavy tank | 1800 / 18 / T3 | Heavy Factory + Signals Center | Twin cannon (2-round clip), slow, very tough. Bolt-on add-ons [STUB] | added |
| Gattling Tank | **Flakwerk AA** | Anti-air / anti-infantry | 800 / 12 / T2 | Motor Pool | Flak bursts | exists |
| Dragon Tank | **Salamander Flame Tank** | Anti-infantry / anti-garrison | 900 / 12 / T2 | Motor Pool | Short-range flame. New `flame` damage type (strong vs infantry, weak vs armour) | added |
| Troop Crawler | **Wolfhound IFV** | APC / raider | 750 / 10 / T2 | Motor Pool | Autocannon. Carries 4 infantry (load / unload is real from M2.4; was a stub) | exists (transport added) |
| Nuke Cannon | **Thunderhead Howitzer** | Long-range heavy artillery | 1600 / 16 / T3 | Heavy Factory + Signals Center | 14-tile range, 4-tile minimum, 1.5 s set-up before firing, big splash with scatter | added |
| Inferno Cannon | **Hearth Mortar** | Medium artillery | 1000 / 12 / T2 | Motor Pool | 10-tile incendiary mortar, scatter | added |
| ECM Tank | **Spectre Jammer** | Electronic warfare | 900 / 10 / T3 | Motor Pool + Signals Center | Jamming field: enemy vehicles within 6 tiles cannot fire. Unarmed | added |
| Listening Outpost | **Sentinel Outpost** | Detector / scout | 800 / 10 / T2 | Motor Pool | Detector: reveals stealthed units and structures in sight (12). Carries 2 infantry | added |
| Helix (helicopter) | **Kestrel Helo** | Air transport / gunship | 1500 / 15 / T3 | Airstrip | No air layer yet | stub |
| MiG (jet) | **Corvid Jet** | Air strike | 1500 / 15 / T3 | Airstrip | No air layer yet | stub |
| (no ZH equivalent) | **Aegis Shield Carrier** | Mobile shield | 1200 / 15 / T2 | Heavy Factory | Area shield aura | exists (EU extra) |

### Structures
| ZH role (reference) | FRACTURE LINE | Role | Cost / build s / tier | Prereqs | Special | Status |
|---|---|---|---|---|---|---|
| Command Center | **Directorate HQ** | HQ | 2500 / 45 / T0 | - | Builds Crawlers, +5 power | exists |
| Nuclear Reactor | **Grid Reactor** | Power | 800 / 10 / T0 | - | +10 power | exists |
| (grid extension) | **Pylon** | Power / shield grid | 300 / 5 / T0 | Reactor | EU extra | exists |
| Supply Center | **Logistics Hub** | Refinery | 1500 / 15 / T0 | Reactor | Passive +3/s | exists |
| Barracks | **Barracks** | Infantry | 600 / 10 / T1 | Reactor | | exists |
| War Factory | **Motor Pool** + **Heavy Factory** | Vehicles (light / heavy) | 1500 / 15, 2000 / 20 / T1–T2 | Barracks / Motor Pool | | exists |
| Bunker | **Gun Bunker** | Defence | 1000 / 12 / T1 | Barracks | Armed bunker (cannon) | exists |
| Gattling Cannon | **Flak Tower** | AA / anti-infantry defence | 1000 / 12 / T1 | Barracks | Rapid-fire, hits ground and air, needs power | added |
| Propaganda Center | **Signals Center** | Tech centre (T3 gate) | 1500 / 15 / T2 | Motor Pool | Unlocks T3. Research upgrades [STUB] | added |
| Speaker Tower | **Field Relay Mast** | Support | 600 / 8 / T3 | Signals Center | Repairs friendly units within 6 tiles by 1% HP/s | added |
| Internet Center | **Data Exchange** | Economy / intel | 2000 / 16 / T3 | Signals Center | Passive +4 supply/s. Shared-radar hacking [STUB] | added |
| Airfield | **Airstrip** | Aircraft | 1500 / 15 / T3 | Signals Center | Real building. Its aircraft are stubs | added (products stub) |
| Land Mines upgrade | **Minefield** | Mines | 300 / 4 / T1 | Barracks | Hidden, detonates under enemy ground units (built by the Crawler) | added |
| Nuclear Missile | **Concord Pylon** | Superweapon | 5000 / 60 / T3 | Signals Center | EMP storm not implemented | stub |

### Infantry (for completeness)
| ZH role | FRACTURE LINE | Status |
|---|---|---|
| Red Guard | Grenadier Squad | exists |
| Tank Hunter | Lancer Squad | exists |
| Hacker | Signals Tech (hacks buildings for income) | later |
| Black Lotus (hero) | Col. Ilse Vantongeren (hero, a tank in our design) | later |

---
## TPLA (ZH GLA)

### Vehicles
| ZH role (reference) | FRACTURE LINE | Role | Cost / build s / tier | Prereqs (built at) | Special | Status |
|---|---|---|---|---|---|---|
| Worker (infantry) | **Laborer** | Builder / gatherer | 200 / 5 / T0 | Den / Stash | On foot | exists |
| Technical | **Rattler Technical** | Raider | 500 / 6 / T1 | Chop Shop | Salvage tiers 1–3 | exists |
| Scorpion Tank | **Scrapback Tank** | Light tank | 650 / 9 / T1 | Chop Shop | Second gun at tier 2 | exists |
| Marauder Tank | **Junkhammer Tank** | Heavy salvage tank | 900 / 12 / T2 | Chop Shop + Workshop | Heavy cannon, salvage tiers | added |
| Quad Cannon | **Hailstorm AA** | AA / anti-infantry | 700 / 9 / T1 | Chop Shop | Quad guns (12-round clip) | exists |
| Rocket Buggy | **Shrike Rocket Buggy** | Hit-and-run artillery | 800 / 9 / T2 | Chop Shop + Workshop | Rocket salvos | exists |
| Toxin Tractor | **Rot Sprayer** | Anti-infantry / area denial | 600 / 9 / T1 | Chop Shop | Short-range corrosive spray, leaves rust zones | added |
| SCUD Launcher | **Blight Mortar** | Long-range artillery | 900 / 11 / T2 | Chop Shop + Workshop | Corrosive shells | exists |
| Radar Van | **Earwig Van** | Detector / scout | 500 / 8 / T1 | Chop Shop | Detector, 14-tile sight. Radar scan [STUB] | added |
| Bomb Truck | **Mule Bomb Truck** | Suicide | 600 / 8 / T2 | Chop Shop + Workshop | Detonates on target. Disguise [STUB] | exists |
| Combat Cycle | **Jackal Bike** | Fast scout / raider | 350 / 5 / T1 | Chop Shop | Fastest unit, light MG. Rider swap [STUB] | added |
| Battle Bus | **Rust Bus** | Transport | 800 / 10 / T2 | Chop Shop + Workshop | Carries 8 infantry. Becomes a bunker when destroyed [STUB] | added |

### Structures
| ZH role (reference) | FRACTURE LINE | Role | Cost / build s / tier | Prereqs | Special | Status |
|---|---|---|---|---|---|---|
| Command Center | **Den** | HQ | 2500 / 45 / T0 | - | Builds Laborers | exists |
| Supply Stash | **Stash** | Supply drop-off | 1500 / 14 / T0 | - | | exists |
| Barracks | **Recruitment Camp** | Infantry | 500 / 9 / T1 | - | | exists |
| Arms Dealer | **Chop Shop** | Vehicles | 1600 / 16 / T1 | Camp | | exists |
| Palace | **Workshop of Grievances** | Tech centre | 1500 / 15 / T2 | Chop Shop | Upgrade research [STUB] (tech gate is real) | exists |
| Black Market | **Bazaar** | Tech / economy | 2500 / 18 / T3 | Workshop | | exists |
| Tunnel Network | **Tunnel** | Shared garrison network | 600 / 8 / T1 | Camp | MG, shared network, heals inside | exists |
| Stinger Site | **Wasp Nest** | AA / anti-vehicle defence | 900 / 10 / T1 | Camp | Missile team (3-round clip), hits ground and air | added |
| Demo Trap | **Demo Trap** | Mine | 200 / 4 / T1 | Camp | Hidden, detonates | exists |
| Fake buildings | **Decoy Yard** | Deception | 300 / 5 / T1 | Camp | Cheap plywood structure. The AI and fog treat it as a real building | added |
| Building holes | **Rebuild Hole** | Auto-rebuild | - | - | | exists |
| Camouflage | **Camo Net** | Stealth | 400 / 6 / T1 | Camp | Hides structures | exists |
| SCUD Storm | **Rust Bloom Silo** | Superweapon | 4500 / 60 / T3 | Bazaar | Spore barrage not implemented | stub |

### Infantry (for completeness)
| ZH role | FRACTURE LINE | Status |
|---|---|---|
| Rebel | Militia | exists |
| RPG Trooper | Rocket Cell | exists |
| Terrorist | (suicide infantry) | later |
| Angry Mob | (mob) | later |
| Hijacker | "The Tinker" (hero hijacker) | later |
| Jarmen Kell (hero) | (sniper hero) | later |
| Saboteur | (saboteur) | later |

---
## Counts (M2.4)
Counted from the tables above. Infantry are not counted, except the TPLA Laborer, which fills the ZH builder slot.

| Faction | Vehicles exist / added / stub | Structures exist / added / stub |
|---|---|---|
| EU Alliance | 6 / 6 / 2 (Kestrel, Corvid aircraft); the Wolfhound's transport is now real | 8 / 6 / 1 (Concord Pylon). The Airstrip is real, but it only lists the two stub aircraft |
| TPLA | 7 / 5 / 0 | 10 / 2 / 1 (Rust Bloom Silo) |
| United States | 0 / 0 / 0. Planning only, see below | 0 / 0 / 0 |

---
## United States (ZH USA): implemented in M2.5
**M2.5 status:** all 11 of Malachi's units plus Dozer and Supply Truck are in and playable, and
the AI plays them. Details are in docs/US_FACTION_M25.md.
- Air layer, airfield slots, land/rearm, sniper stealth and one-shot, the JTAC call-in and
  boost aura, and the 2-soldier Javelin squad are all real.
- Lynx fire-from-inside is still a [STUB].
- Unspecified ZH USA buildings were added as **placeholders pending Malachi's list**: Command
  Center, Fusion Plant (the US uses power), Supply Center, Strategy Center (tech gate only),
  Bulwark SAM Battery (Patriot slot), Fire Base, and Supply Drop Zone.
- Generals powers: UAV Recon, Paradrop, Precision Strike, Field Repair.
- Not done: Paladin, Ambulance, Microwave Tank, Sentry Drone, Chinooks, Stealth Fighter,
  Burton, Detention Camp, and the Particle Uplink superweapon.
- The planning notes below are kept for reference.

Source: Malachi's notes, `rts-design/notes/US_FACTION_NOTES_malachi_2026-10-22.md`. Malachi is designing this faction, so the tables below only **map** his units to ZH USA slots and list the gaps and missing mechanics. Nothing is implemented. All in-game names are original "inspired" names; the bold names are working suggestions for Malachi to accept or replace.

### Malachi's units mapped to ZH USA
| ZH USA slot | Malachi's unit (inspiration) | Working name (suggestion) | Built at | Role and notes | Mechanics needed |
|---|---|---|---|---|---|
| Crusader Tank | Abrams-inspired MBT | **Halberd MBT** | Garage (War Factory) | Main battle tank | none new |
| Humvee | JLTV-inspired vehicle | **Lynx JLTV** | Garage | Fast scout / raider. ZH Humvee carries 5 infantry who fire from inside | transport exists (M2.4); fire-from-inside is new |
| Tomahawk Launcher | M777-inspired howitzer | **Longreach Howitzer** | Garage | Long-range artillery (a towed gun in place of a missile launcher) | artillery exists; JTAC boost is new |
| Avenger | AN/TWQ-1-inspired SHORAD | **Picket SHORAD** | Garage | Short-range air defence. ZH Avenger also laser-paints targets for bonus damage | AA exists; "paint target" bonus optional |
| Ranger | Marine Grunt (1 soldier, M16) | **Marine Rifleman** | Barracks | Basic infantry | none new |
| Missile Defender | Javelin team (1 unit = 2 soldiers) | **Javelin Team** | Barracks | Anti-armour. Two models per unit | multi-model squad view (view only) |
| Pathfinder | Marine Scout Sniper | **Scout Sniper** | Barracks | Invisible while stationary; one-shot kills on infantry | stealth while stationary; infantry one-shot |
| (Burton / laser designation, partial) | Forward JTAC Observer | **JTAC Observer** | Barracks | Single soldier, wide sight, M4, 35% stronger than a Grunt. Calls in air support. Boosts artillery and airstrikes near him | air-support call-in; aura that boosts artillery and airstrikes |
| Aurora Bomber | B-1-inspired heavy bomber | **Thunderlance Bomber** | Airfield | One devastating strike, then lands and reloads (long reload). Uses 4 of 6 airfield slots | air layer; land and rearm; slot capacity |
| Raptor | F-22-inspired fighter | **Wraith Fighter** | Airfield | Best air-to-air; weak ground strike; short reload. Uses 2 slots | air layer; land and rearm; slot capacity; air-to-air targeting |
| Comanche | Apache-inspired attack helicopter | **Harrier Gunship** | Airfield | Rockets against vehicles, 20 mm gun against light vehicles and infantry. Uses 0 slots and never lands | air layer (helicopter, hovers); two weapons by target type (existing per-weapon target rules) |

### ZH USA slots Malachi has not covered yet
- **Builder and economy:**
  - Dozer (builder).
  - Supply Truck, or the ZH Chinook supply helicopter.
  - Supply Drop Zone (passive income building).
- **Vehicles:**
  - Paladin (point-defence laser tank).
  - Ambulance (field repair and cleanup).
  - Microwave Tank (clears garrisons and disables buildings).
  - Sentry Drone (stealth scout drone).
  - Combat Chinook / Chinook (air transport).
- **Air:**
  - Stealth Fighter.
  - Spectre gunship. This is a general's power; it may tie in with the JTAC call-in.
- **Infantry:**
  - Colonel Burton (hero commando).
  - A pilot / veterancy-recovery equivalent.
- **Base structures:**
  - Command Center.
  - Cold Fusion Reactor (power: does the US use power like the EU?).
  - Supply Center.
  - Barracks, War Factory ("Garage") and Airfield are named by Malachi but their stats are not set yet.
- **Tech and support:**
  - Strategy Center (tech gate; Battle Plans: bombard, hold-the-line and search-and-destroy stances).
  - Detention Camp (intel / radar reveal).
- **Defences:**
  - Patriot Missile System (AA and ground; links targets between batteries).
  - Fire Base (artillery bunker).
- **Superweapon:** Particle Uplink Cannon.
- **General's powers** (rank powers already exist): paradrop, A-10 strike, spy drone, emergency repair, fuel-air bomb, Spectre gunship.

### New mechanics his units need (none exist yet)
| Mechanic | Needed by | Notes for the build |
|---|---|---|
| **Air layer** | Bomber, fighter, gunship (and the EU Kestrel and Corvid stubs) | `move_layer = air`: aircraft ignore terrain and occupancy, have their own collision and pathing, can only be hit by weapons with `targets_air`, and need altitude, banking and landing views. This is the largest piece of work and also unblocks the EU aircraft stubs |
| **Land and rearm** | Bomber (one strike, long reload), fighter (short reload) | Ammo per sortie; return to the Airfield when empty; reload only while parked; a timer per slot; automatic return. The gunship skips this (it reloads in the air like ground units) |
| **Airfield slot capacity (6)** | Airfield | Each aircraft has a `slots` cost (bomber 4, fighter 2, gunship 0). Production is blocked when free slots < cost; slots free up when the aircraft dies; parking positions on the pad. Multiple airfields add capacity. This must be deterministic and saved (SimEntity._FIELDS) |
| **Stealth while stationary** | Scout Sniper | After N ticks without moving or firing, the unit becomes stealthy; firing reveals it briefly. This reuses the M2.4 stealth mask and detectors (Sentinel and Earwig already detect), extended from structures to units |
| **One-shot vs infantry** | Scout Sniper | Weapon flag `kills_infantry` (damage = target HP vs the infantry armour class); normal damage otherwise |
| **JTAC air-support call-in** | JTAC Observer | Ability: mark a target. Idle friendly aircraft with ammo (or a cooldown "call" if there is no aircraft) are sent to attack it. Still being designed by Malachi; needs the air layer first |
| **Artillery / airstrike boost aura** | JTAC Observer | While the JTAC is within N tiles of the target area, artillery and airstrike damage and accuracy go up (for example less scatter, +damage %). Can reuse the shield-aura pattern (`shield_aura_radius`/`pct`) as a generic "spotter" aura |
| **Fire from transport** | Lynx JLTV (Humvee slot) | Passengers fire from inside the transport (like garrison fire). M2.4 transports only carry passengers |
| **Multi-soldier squads** | Javelin Team (2 soldiers) | View only: draw 2 models per unit, and remove one at half HP. The sim stays 1 entity |

### Suggested order (after EU / TPLA are done)
1. US base: Command Center, power (decide whether the US uses it), Supply, Barracks, Garage, the 4 garage units and the 4 barracks units. The sniper's stealth-while-stationary reuses the M2.4 detector work.
2. Air layer + Airfield slots + land/rearm: bomber, fighter, gunship. This also turns the EU Kestrel and Corvid stubs into real units.
3. JTAC call-in and the boost aura.
4. Remaining ZH slots (Strategy Center, Patriot, Fire Base, Particle Uplink).

---
## Appendix: ZH general sub-faction units (later)
These map to our sub-generals (GDD §4) and are **not** in M2.4.
- **China, Tank General** → EU "Ironclad": the *Bastion* super-heavy (an Emperor-type Overlord), tank veterancy perks.
- **China, Nuke General** → EU "Static": the *Tempest* EMP mortar (nuke-cannon variant), the *Blackout* doctrine.
- **China, Infantry General** → (no EU equivalent, later): massed infantry, Minigunner-type, Assault Troop Crawler.
- **GLA, Toxin General** → TPLA "Mother Rust": Blight Wagon variants, toxin upgrades on all infantry.
- **GLA, Stealth General** → TPLA "The Mole": hidden buildings, cheaper tunnels, stealthed Rattler variant.
- **GLA, Demolition General** → (partly) TPLA "Scrapjack": salvage bonuses. Demo-type units come later.
