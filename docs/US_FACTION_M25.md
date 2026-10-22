# United States faction (M2.5)

Playable and AI faction; any lobby slot can pick it. Names are original and only *inspired by*
real equipment roles. Models are procedural (tools/gfx_m5/us_m5.gd, Marine infantry baked by
tools/bake_infantry.gd), palette olive drab #5a6447, aircraft grey #8a9097.
Voices: modern American soldiers + announcer (Kokoro-82M American voices, Apache-2.0), own
"digital tactical radio" filter. Your recordings in res://audio/voice/us/<unit>/ override them.

## Units

| Unit | Inspired by | Cost | HP | Role / notes |
|---|---|---|---|---|
| Dozer | armoured bulldozer | 1000 | 500 | builder |
| Supply Truck | logistics truck | 700 | 650 | gatherer (350 per load) |
| Marine Grunt | Marine rifleman | 225 | 180 | rifle (13 dmg), garrisons |
| Javelin Team | Javelin ATGM team | 450 | 260 | **2 soldiers**; fire-and-forget AT missile, hits helicopters |
| JTAC Observer | joint terminal attack controller | 500 | 243 (= Grunt +35%) | sight 12 (Grunt 7); every 10 s sends an idle aircraft (within 70 tiles) at his target; artillery and air strikes landing within 8 tiles of him do +25% damage with half the scatter |
| Scout Sniper | Marine scout sniper | 600 | 150 | invisible after 2 s standing still (revealed by nearby enemies / detectors); 400-damage rifle one-shots any infantry, ~nothing vs vehicles; needs Strategy Center |
| Lynx | JLTV | 700 | 550 | fast, roof HMG, carries 5 infantry |
| Halberd | Abrams | 1100 | 1050 | main battle tank, heavy armour |
| Picket | Avenger SHORAD | 850 | 520 | Stinger-style AA pods + MG |
| Longreach | M777 | 1400 | 420 | 175-dmg howitzer, range 15, minimum range; needs Strategy Center |
| Harrier Gunship | Apache | 1500 | 700 | helicopter: Hellfire-style missiles (4) + chain gun; hovers, reloads in the air, **no airfield slot, never lands** |
| Wraith Fighter | modern fighter | 1500 | 520 | **2 airfield slots**; best anti-air (4 air-to-air missiles) + one light bomb; short rearm |
| Thunderlance Bomber | heavy bomber | 2500 | 900 | **4 airfield slots**; one 700-damage bomb run, then lands and rearms 45 s; needs Strategy Center |

Airfield: 6 parking slots; production holds ("Airfield full") while slots are used. Jets keep
flying (no hovering), circle targets, return when empty or idle, land and rearm on their spot.

## Buildings

| Building | Notes |
|---|---|
| Command Center | HQ, builds Dozers |
| Fusion Plant | power — *placeholder pending Malachi's list* |
| Supply Center | drop-off, free Supply Truck |
| Barracks | infantry |
| Garage | vehicles |
| Airfield | aircraft, 6 slots |
| Strategy Center | tech — *placeholder pending Malachi's list* |
| Bulwark SAM Battery | AA defence — *placeholder pending Malachi's list* |
| Fire Base | artillery defence — *placeholder pending Malachi's list* |
| Supply Drop Zone | passive income — *placeholder pending Malachi's list* |

Buildings Malachi did not specify follow the Zero Hour USA equivalents (role only, original names
and models) and are marked "placeholder pending Malachi's list" in-game and here.

## General powers
UAV Recon (rank 1), Paradrop (rank 2, 5 Grunts), Precision Strike (rank 3, 350 dmg),
Field Repair (rank 4).

## AI
AIUs (ai/ai_us.gd) on the shared role planner: builds the airfield, respects slots, sends jet
sorties at enemy bases/armies, caps JTAC/sniper counts, uses US powers. EU AI adds AA once enemy
aircraft are seen.

## Stubs
Lynx fire-from-inside (passengers do not shoot out yet); no US superweapon.
