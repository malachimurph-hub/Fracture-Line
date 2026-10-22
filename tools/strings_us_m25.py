#!/usr/bin/env python3
"""M2.5: upserts the United States strings into locale/strings.csv (the CSV is the source of truth
since M2.3; gen_strings.py only holds the M1 base set). Names are original "inspired" names;
buildings Malachi has not specified yet are ZH-USA-equivalent placeholders (see docs/US_FACTION_M25.md)."""
import csv, os
S = {
"FACTION_US": "United States",
"AI_VANGUARD": "Vanguard",
"REASON_AIRFIELD_FULL": "Airfield full: no free parking slots",
"ROLE_SNIPER": "Sniper", "ROLE_FIGHTER": "Fighter",
"UNIT_US_DOZER": "Dozer", "UNIT_US_DOZER_DESC": "Armoured bulldozer. Builds and repairs base structures.",
"UNIT_US_SUPPLY_TRUCK": "Supply Truck", "UNIT_US_SUPPLY_TRUCK_DESC": "Hauls supplies from piles and derricks to a Supply Center.",
"UNIT_US_GRUNT": "Marine Grunt", "UNIT_US_GRUNT_DESC": "One Marine with a service rifle. Cheap, flexible, can garrison buildings.",
"UNIT_US_JAVELIN": "Javelin Team", "UNIT_US_JAVELIN_DESC": "Two-man anti-armour team. Fire-and-forget missiles lock on, then hit vehicles and helicopters hard.",
"UNIT_US_JTAC": "JTAC Observer", "UNIT_US_JTAC_DESC": "Forward air controller with a carbine: wide sight, 35% stronger than a Grunt. Sends idle aircraft at his target and boosts artillery and air strikes near him (+25% damage, tighter spread).",
"UNIT_US_SNIPER": "Scout Sniper", "UNIT_US_SNIPER_DESC": "Invisible while standing still. Kills infantry with one shot; useless against vehicles. Needs a Strategy Center.",
"UNIT_US_HALBERD": "Halberd MBT", "UNIT_US_HALBERD_DESC": "Main battle tank with a heavy smoothbore gun. Fast for its weight, very well armoured.",
"UNIT_US_LYNX": "Lynx JLTV", "UNIT_US_LYNX_DESC": "Fast light tactical vehicle with a roof machine gun. Carries five infantry.",
"UNIT_US_PICKET": "Picket SHORAD", "UNIT_US_PICKET_DESC": "Short-range air defence: launcher pods for aircraft plus a machine gun for light ground targets.",
"UNIT_US_LONGREACH": "Longreach Howitzer", "UNIT_US_LONGREACH_DESC": "Long-range towed howitzer. Slow to set up, cannot hit close targets. Needs a Strategy Center.",
"UNIT_US_HARRIER": "Harrier Gunship", "UNIT_US_HARRIER_DESC": "Attack helicopter: missiles against vehicles, chin cannon against infantry and light vehicles. Reloads in the air, needs no airfield slot.",
"UNIT_US_WRAITH": "Wraith Fighter", "UNIT_US_WRAITH_DESC": "Air-superiority fighter: the best anti-air in the game, one light bomb for ground targets. Short rearm. Uses 2 airfield slots.",
"UNIT_US_THUNDERLANCE": "Thunderlance Bomber", "UNIT_US_THUNDERLANCE_DESC": "Heavy bomber: one devastating strike, then it lands and rearms (45 s). Uses 4 airfield slots. Needs a Strategy Center.",
"BLD_US_COMMAND": "Command Center", "BLD_US_COMMAND_DESC": "US headquarters. Builds Dozers.",
"BLD_US_REACTOR": "Fusion Plant", "BLD_US_REACTOR_DESC": "Power plant (placeholder pending Malachi's list).",
"BLD_US_SUPPLY_CENTER": "Supply Center", "BLD_US_SUPPLY_CENTER_DESC": "Supply drop-off. Comes with a Supply Truck.",
"BLD_US_BARRACKS": "Barracks", "BLD_US_BARRACKS_DESC": "Trains Marine infantry.",
"BLD_US_GARAGE": "Garage", "BLD_US_GARAGE_DESC": "Builds US vehicles.",
"BLD_US_AIRFIELD": "Airfield", "BLD_US_AIRFIELD_DESC": "Builds aircraft. 6 parking slots: bomber 4, fighter 2, gunship 0. Jets land here to rearm.",
"BLD_US_STRATEGY": "Strategy Center", "BLD_US_STRATEGY_DESC": "Tech centre: unlocks the Scout Sniper, Longreach Howitzer, Thunderlance Bomber and Drop Zone (placeholder pending Malachi's list).",
"BLD_US_PATRIOT": "Bulwark SAM Battery", "BLD_US_PATRIOT_DESC": "Missile battery, strong against aircraft, weak against ground targets. Needs power (placeholder pending Malachi's list).",
"BLD_US_FIREBASE": "Fire Base", "BLD_US_FIREBASE_DESC": "Artillery bunker that shells ground targets at long range. Needs power (placeholder pending Malachi's list).",
"BLD_US_DROP_ZONE": "Supply Drop Zone", "BLD_US_DROP_ZONE_DESC": "Receives regular supply drops: passive income (placeholder pending Malachi's list).",
"POWER_US_UAV": "UAV Recon", "POWER_US_UAV_DESC": "A drone reveals a 14-tile area for 20 s.",
"POWER_US_PARADROP": "Paradrop", "POWER_US_PARADROP_DESC": "Five Marine Grunts parachute onto the target.",
"POWER_US_STRIKE": "Precision Strike", "POWER_US_STRIKE_DESC": "Three heavy bombs on the target area (+25% if a JTAC is near).",
"POWER_US_REPAIR": "Field Repair", "POWER_US_REPAIR_DESC": "Vehicles, aircraft and structures in the area regain half their health.",
"HUD_AIR_REARMING": "Rearming %d s", "HUD_AIR_SLOTS": "Airfield slots %d / %d",
}
p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "locale", "strings.csv")
rows = list(csv.reader(open(p, newline="")))
idx = {r[0]: i for i, r in enumerate(rows)}
for k, v in S.items():
    if k in idx:
        rows[idx[k]][1] = v
    else:
        rows.append([k, v])
with open(p, "w", newline="") as f:
    csv.writer(f, lineterminator="\n").writerows(rows)
print(len(S), "US strings upserted")
