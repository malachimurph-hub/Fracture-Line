# M2.6 balance soaks (hard vs hard AI, 1v1, 4 maps)

Command: FL_MAP=<map> godot --headless ... test_runner.tscn -- soak 2 <off> 1v1 facA,facB hard (offsets 0 and 2, so seeds 1000-1003). Factions alternate sides per seed. Logs: builds/m2_6/soak/<round>/. Tally: builds/m2_6/tally.py.

## Before/after totals

| Matchup | M2.5 baseline (soak/base) | M2.6 r3 (shipped numbers) |
|---|---|---|
| eu-tpla   {'tpla': 4, 'eu': 7, 'draw': 2}  n=13  tpla 31% eu 54% draw 15%|  eu-tpla   {'tpla': 7, 'eu': 4, 'draw': 1}  n=12  tpla 58% eu 33% draw 8% |
| eu-us     {'us': 14, 'draw': 1, 'eu': 1}  n=16  us 88% draw 6% eu 6%|  eu-us     {'us': 7, 'eu': 6, 'draw': 2}  n=15  us 47% eu 40% draw 13% |
| tpla-us   {'us': 15, 'tpla': 1}  n=16  us 94% tpla 6%|  tpla-us   {'us': 14, 'tpla': 2}  n=16  us 88% tpla 12% |

## Per map and seed: baseline
```
harrow_junction    eu-tpla  {'tpla': 2, 'eu': 2}   1000:tpla@14:17 1001:eu@17:35 1002:eu@18:05 1003:tpla@8:59
harrow_junction    eu-us    {'us': 4}   1000:us@20:14 1001:us@18:24 1002:us@33:28 1003:us@18:02
harrow_junction    tpla-us  {'us': 4}   1000:us@11:53 1001:us@13:19 1002:us@12:16 1003:us@11:05
kessel_pass        eu-tpla  {'eu': 3, 'tpla': 1}   1000:eu@26:34 1001:eu@13:39 1002:tpla@14:12 1003:eu@10:55
kessel_pass        eu-us    {'us': 3, 'draw': 1}   1000:us@14:06 1001:draw@40:00 1002:us@13:19 1003:us@17:51
kessel_pass        tpla-us  {'us': 4}   1000:us@11:27 1001:us@12:30 1002:us@18:19 1003:us@12:17
ochre_wells        eu-tpla  {'draw': 1}   1002:draw@40:00
ochre_wells        eu-us    {'us': 4}   1000:us@18:48 1001:us@21:48 1002:us@20:13 1003:us@22:04
ochre_wells        tpla-us  {'us': 4}   1000:us@15:03 1001:us@16:08 1002:us@17:05 1003:us@12:26
varno_crossing     eu-tpla  {'eu': 2, 'tpla': 1, 'draw': 1}   1000:eu@11:53 1001:tpla@10:19 1002:eu@13:52 1003:draw@40:00
varno_crossing     eu-us    {'us': 3, 'eu': 1}   1000:us@13:06 1001:us@11:39 1002:eu@11:33 1003:us@10:52
varno_crossing     tpla-us  {'us': 3, 'tpla': 1}   1000:us@11:27 1001:us@12:55 1002:tpla@11:57 1003:us@10:04
```

## Per map and seed: r3
```
harrow_junction    eu-tpla  {'tpla': 3, 'eu': 1}   1000:tpla@32:53 1001:eu@26:08 1002:tpla@21:06 1003:tpla@31:34
harrow_junction    eu-us    {'us': 4}   1000:us@17:49 1001:us@14:56 1002:us@16:10 1003:us@18:53
harrow_junction    tpla-us  {'us': 4}   1000:us@29:00 1001:us@23:01 1002:us@19:12 1003:us@14:11
kessel_pass        eu-tpla  {'tpla': 1, 'eu': 2}   1000:tpla@35:23 1002:eu@33:32 1003:eu@14:36
kessel_pass        eu-us    {'eu': 3, 'draw': 1}   1000:eu@30:34 1001:draw@40:00 1002:eu@14:23 1003:eu@26:10
kessel_pass        tpla-us  {'us': 4}   1000:us@14:55 1001:us@18:25 1002:us@18:50 1003:us@15:48
ochre_wells        eu-tpla  {'draw': 1}   1000:draw@40:00
ochre_wells        eu-us    {'eu': 1, 'us': 1, 'draw': 1}   1000:eu@24:13 1001:us@25:08 1002:draw@40:00
ochre_wells        tpla-us  {'us': 4}   1000:us@14:36 1001:us@35:28 1002:us@31:45 1003:us@21:52
varno_crossing     eu-tpla  {'eu': 1, 'tpla': 3}   1000:eu@13:38 1001:tpla@11:58 1002:tpla@10:33 1003:tpla@27:08
varno_crossing     eu-us    {'eu': 2, 'us': 2}   1000:eu@13:59 1001:eu@12:11 1002:us@18:15 1003:us@11:41
varno_crossing     tpla-us  {'tpla': 2, 'us': 2}   1000:tpla@28:00 1001:us@16:56 1002:tpla@38:01 1003:us@12:50
```

## Kill value by unit (r3; shows who does the work)
```
tpla [('tpla_rocket_cell', 327850), ('tpla_militia', 303975), ('tpla_scrapback', 283125), ('tpla_rattler', 280450), ('tpla_hailstorm', 213625), ('tpla_tunnel', 96825), ('tpla_jackal', 37500), ('tpla_wasp_nest', 25950), ('tpla_junkhammer', 17550), ('tpla_sprayer', 8025)]
eu [('eu_leopold', 384125), ('eu_grenadier', 296550), ('eu_lancer', 289025), ('eu_flakwerk', 224475), ('eu_wolfhound', 162500), ('eu_hearth', 140100), ('eu_salamander', 63650), ('eu_gun_bunker', 55300), ('eu_thunderhead', 19750)]
us [('us_harrier', 581050), ('us_halberd', 367400), ('us_javelin', 328450), ('us_grunt', 313300), ('us_lynx', 239500), ('us_sniper', 92100), ('us_firebase', 61450), ('us_precision_strike', 60900), ('us_thunderlance', 49050), ('us_jtac', 21200)]
harvest@10min eu avg 60936
harvest@10min tpla avg 53498
harvest@10min us avg 56685
harvest@5min eu avg 17833
harvest@5min tpla avg 16086
harvest@5min us avg 15929
```

r1 and r2 were intermediate rounds (partial; r2 was contaminated by a mid-run data change). r3 is what ships.
