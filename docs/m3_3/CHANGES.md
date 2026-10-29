# M3.3 Phase 1 (branch m33)

| Commit | Change |
|---|---|
| 68be316 | Balance/economy: fixed-turret SPGs, splash + infantry vulnerability, light-aircraft buff, start cash <= $50k, cap $9,999,999, income structures (Data Center, Oil Derrick, Automotive Plant, Minerals Mining), US Nuclear Power +30%, Germany renames (Infanterie, Panzerfaust), heavy tank retired |
| ff518b7 | Test expectations for the new balance; m33 test in the suite |
| 3cc5e7a | Generals hidden (Content.GENERALS_ENABLED=false); AI skips powers; replays that bought powers still play |
| 92c45fb | Sell finished buildings for 70% (not the HQ); queue refunded, garrison ejected |
| 90aea6d | Dozer pathing: tries several approach tiles, works from near when stuck |
| 809ab2d | Construction clears trees/rocks/scatter under the footprint (view only) |
| 5932cdd | firing_tick saved (fixes a post-load desync); old saves still load |
| 0b5eceb | Technical white; quadcopter drones with red/green lamps; bomb drone dives; no air dust trail |
| 44a6b65 | 8 manual save slots with date/time, Load screen |
| 8feb6dc | HUD: top-centre money + 40-segment power bar, 8-slot queue, flag in bar, text-only alerts, pause menu fits, zoom out 20% |

Known: the drones lost their M3.2 tex14 bake (the baker's embreex dependency is not installed); queue slots show short captions until unit icons land (Phase 4).
