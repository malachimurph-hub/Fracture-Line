# ZH_REFERENCE: Zero Hour systems vs FRACTURE LINE

This compares how Zero Hour does each system with how FRACTURE LINE does it today.

**Reference.** The study source is EA's GPL-3.0 release of *C&C Generals / Zero Hour*:
- shallow clone at `/workspace/reference/cnc-zh`, commit `0a05454`, outside the project;
- paths below are relative to `GeneralsMD/Code/GameEngine/`.

**Rules for using it.**
- The code is studied only. Nothing is copied into FRACTURE LINE; every change is our own GDScript, in fixed-point integers so the simulation stays deterministic.
- The release contains **no game INI data** (only engine code; the one `.ini` file is a WW3D `Dazzle.INI`). So **no ZH unit/weapon numbers are known here**, and none of our numbers are claimed to be "official".
- Below, "ZH" means *behaviour and structure visible in the released engine code*.

**Our code.** "Ours" refers to `/workspace/mobile-rts/project` at 88ddc51 (M2.2).

**Gap ranking.** Gaps are ranked by **gameplay-feel impact**:
- **H**: changes how every fight or move feels;
- **M**: noticeable in specific situations;
- **L**: polish, or already close.

---

## 1. Logic tick rate and update order
- **ZH**
  - Rate: `LOGICFRAMES_PER_SECOND = 30` (`Include/Common/GameCommon.h:72`).
  - Order in `GameLogic::update()` (`Source/GameLogic/System/GameLogic.cpp:3572`):
    1. ScriptEngine, then TerrainLogic;
    2. CRC (every N frames in MP);
    3. `processCommandList`;
    4. every object's update modules (normal, then the "sleepy" priority queue, so modules can sleep for many frames);
    5. `TheAI->UPDATE()` (pathfinder queue, AI players);
    6. `ThePartitionManager->UPDATE()` (spatial grid and shroud);
    7. WeaponStore (delayed damage);
    8. Victory conditions.
  - Each unit is mostly simulated inside its own update modules (AIUpdate state machine, PhysicsBehavior, weapons, body).
- **Ours**
  - 20 Hz, systems-ordered in `sim_world.step()`: commands → orders and target acquisition → path budget (24/tick) → movement and separation → combat → reap → economy → production → power → TPLA → fog → hash.
- **Gap: L.** 20 Hz with view interpolation is fine on mobile. Being system-ordered rather than per-object costs nothing for the feel. Keep it.

## 2. Pathfinding and locomotors (movement feel)
- **ZH pathfinding**
  - A* on a cell grid (`AI/AIPathfind.cpp`, 11k lines). Layered cells (ground, bridges), zone pre-classification for fast "unreachable" tests, path optimisation (string pulling).
  - `adjustDestination()` spreads group goals to free cells, and `moveAlliesAwayFromDestination` makes idle allies step aside.
- **ZH locomotors** (`Object/Locomotor.cpp`)
  - Every unit has a locomotor with `Speed`, `SpeedDamaged`, `TurnRate`, `TurnRateDamaged`, `Acceleration`, `Braking`, `MinTurnSpeed`, `CanMoveBackwards` and an Appearance (TREADS/WHEELS/LEGS/HOVER/WINGS/THRUST), all driving a physics behaviour with mass and forces.
  - **Treads** (`moveTowardsPositionTreads`, l.1168):
    - rotate toward the goal at `TurnRate`;
    - goal speed = `(1 - |relAngle|/45°) × desired`, so a tank turning more than 45° pivots almost in place;
    - accelerate at `Acceleration`, brake at `Braking`;
    - start braking within `slowDownDist = v/1.5 × v/braking` of the goal.
  - **Wheels** (`moveTowardsPositionWheels`, l.1282):
    - can only turn while moving;
    - clamp speed to `MinTurnSpeed` (at least `maxSpeed/4`) when the turn is over 9°;
    - may reverse or do 3-point turns if `CanMoveBackwards`.
  - **Legs** (l.1618): same 45° speed modulation, with high turn rates in practice, so infantry are nimble; optional wander.
  - **Damaged state.** The `*Damaged` values apply when the body is DAMAGED or REALLYDAMAGED (`getMaxSpeedForCondition`, l.792).
- **Ours**
  - `MoveSys`: AStarGrid2D (jump point) per layer, then tile-centre waypoints. Units move at **full speed from the first tick and change direction instantly**: no turn rate, acceleration or braking, and no difference between treads, wheels and legs.
  - Separation is a push-apart pass. Group moves spread goals to a ring of free tiles (`formation_slots`).
  - Veterancy rank 2+ gives +10% speed.
- **Gap: H (#1).** Instant pivot and full speed is the most visible "not ZH" feel: tanks slide sideways and reverse direction instantly. Needed:
  - per-unit locomotor class (treads / wheels / legs);
  - fixed-point heading, turn rate, accel/brake;
  - treads slow down with the turn angle, wheels clamp to a turn speed, legs are fast-turning;
  - damaged speed.

## 3. Unit formation and crowding
- **ZH**
  - `AIGroup::groupMoveToPosition` (`AI/AIGroup.cpp:1552`) keeps formation offsets for formation groups. Otherwise it computes per-unit destinations with `adjustDestination`.
  - The group speed is the **slowest member's** speed (`AIGroup::getSpeed`, l.143 and l.399), so mixed groups arrive together.
  - The pathfinder reserves goal cells, and units yield to movers.
- **Ours:** `formation_slots` ring around the click, plus separation pushes. Every unit moves at its own speed, so fast units arrive first and fight alone.
- **Gap: M (#5).** Group speed matching on a group move or attack-move is cheap and ZH-like.

## 4. Attack, targeting and weapon timing
- **ZH** (`Object/Weapon.cpp`, `Object/WeaponSet.cpp`, `AI/TurretAI.cpp`)
  - **Status machine.** Each weapon is `READY_TO_FIRE / PRE_ATTACK / BETWEEN_FIRING_SHOTS / RELOADING_CLIP / OUT_OF_AMMO`, with `m_whenWeCanFireAgain`.
  - **`PreAttackDelay`** applies `PER_SHOT`, `PER_ATTACK` (first shot at a new target only) or `PER_CLIP` (`Weapon::getPreAttackDelay`, l.2844).
  - **Rate of fire.**
    - `DelayBetweenShots` (min/max; random in range) between shots of a clip.
    - `ClipSize` + `ClipReloadTime` + `AutoReloadsClip`, plus `AutoReloadWhenIdle`.
    - `ContinuousFireOne/Two` + `ContinuousFireCoast` speed up rate of fire for sustained fire.
  - **Aiming.** Turreted units must slew the turret at `TurretTurnRate` (TurretAI l.240, l.399) until within `AcceptableAimDelta` before firing, unless `FiresWhileTurning`. Hull-mounted weapons need the body to turn. A turret recentres after `RecenterTime`.
  - **Range.** `AttackRange` / `MinimumAttackRange` are checked with a ¼-cell slack (l.2298). `ContinueAttackRange` exists.
  - **Accuracy.**
    - `ScatterRadius`, plus `ScatterRadiusVsInfantry` added when the victim is INFANTRY (l.977–1010): the shot lands at a random point inside that radius. If it misses by more than the damage radius, it hurts nothing at the intended spot.
    - So tank shells and artillery often miss infantry.
  - **Projectiles.** Projectile weapons have travel time (`WeaponSpeed`); hitscan/laser weapons are instant.
- **Ours** (`CombatSys`)
  - one cooldown per weapon (`cooldown_ms`), hitscan, fires the instant it is in range;
  - no aim/turn requirement, no pre-attack delay, no clips or reloads, no scatter, so it **never misses**;
  - target acquisition every 5 ticks, preferring the nearest armed unit, then unarmed units, then structures.
- **Gap: H (#2 timing/aim, #3 scatter).** ZH fights have visible rhythm: tanks traverse the turret, then fire; RPG teams pause to aim; MGs fire bursts and reload. ZH also has a strong rock-paper-scissors in accuracy: cannons are bad at hitting infantry.

## 5. Damage types vs armour
- **ZH**
  - `DamageType` per weapon. Each `ArmorTemplate` holds a % coefficient per damage type, with "Default" applying to all (`Object/Armor.cpp:66`, `parseArmorCoefficients` l.81). `UNRESISTABLE` bypasses armour.
  - Splash: `PrimaryDamage` within `PrimaryDamageRadius` plus `SecondaryDamage` within `SecondaryDamageRadius` (flat inner/outer rings, not a linear falloff). `RadiusDamageAffects` masks allies, self and neutrals.
  - Armour can change with upgrades (ArmorSet conditions).
- **Ours**
  - `data/combat_table.tres`: a damage-type × armour-type % table (the same idea).
  - Splash falls off linearly from 100% to 50% at the edge; enemies only.
- **Gap: L–M (#4).** The model already matches. ZH's two-ring splash would only change edge numbers. Deferred unless cheap.

## 6. Veterancy
- **ZH**
  - `ExperienceTracker.cpp`: XP comes from the victim's per-level `ExperienceValue`; levels need `ExperienceRequired[level]` (`Common/Thing/ThingTemplate.cpp:134`).
  - Bonuses per rank (damage, rate of fire, armour, heal) are data-driven `WeaponBonus` / `ArmorSet` entries in INI. The INI is not in the release, so the amounts are unknown.
  - Heroic units self-heal.
- **Ours:** XP equals the victim's cost; ranks at 1×, 2× and 4× own cost. Ranks give +10/20/30% damage and HP, rank 2+ gives −10% cooldown and +10% speed, and heroic units heal 1%/s.
- **Gap: L.** Structurally the same.

## 7. Construction, dozer behaviour and repair
- **ZH:** `Object/Update/AIUpdate/DozerAIUpdate.cpp`.
  - The dozer must stay at the site; construction pauses if it leaves, and any dozer can resume.
  - Dozers repair structures at `RepairHealthPercentPerSecond`.
  - Idle dozers auto-repair or clear mines within `BoredRange` after `BoredTime`.
  - GLA workers use the same module (`WorkerAIUpdate.cpp`).
- **Ours:** the Crawler/Laborer build sites; a scaffold stays if the builder leaves and is resumed by any builder (TPLA multi-builder at one builder's speed). Base field-repair zone. Builder repair: see `command_sys` repair order.
- **Gap: L–M.** Missing "bored" auto-repair. Deferred.

## 8. Supply gathering
- **ZH:** `SupplyTruckAIUpdate`, `SupplyWarehouseDockUpdate` (`StartingBoxes`), `SupplyCenterDockUpdate`.
  - Trucks take boxes (a value per box), with action delays at the warehouse and centre.
  - The number of gatherers wanted depends on AI difficulty (`AIPlayer::checkForSupplyCenter`, l.199: easy/normal/hard counts from AIData).
- **Ours:** harvesters load 400 in about 5 s and unload in 2 s (Laborers 0.5 s). Resource nodes deplete. AI wants 2/2/3 harvesters per hub on easy/medium/hard.
- **Gap: L.** Same loop; per-difficulty gatherer counts already exist.

## 9. Power
- **ZH:** player energy production vs consumption. Underpowered players lose powered features: base defences, radar and other `KINDOF_POWERED` objects are disabled.
- **Ours:** grid supply vs demand; under low power, defences with `needs_power_to_fire` stop and production is held.
- **Gap: L.**

## 10. Garrison
- **ZH:** `Object/Contain/GarrisonContain.cpp`. Infantry fire from fire points, up to `ContainMax`. Garrisoned units get weapon bonuses, and the building takes the damage.
- **Ours:** neutral buildings hold infantry that fire with +2 tiles range; the building is hit first.
- **Gap: L.**

## 11. Stealth and detection
- **ZH**
  - `StealthUpdate.cpp`: `StealthDelay` re-stealths after firing or moving; `InnateStealth`; conditions such as "stealthed while not attacking".
  - `StealthDetectorUpdate.cpp`: `DetectionRange` scanned every `DetectionRate`.
- **Ours:** TPLA Camo Net and Demo Trap hide structures; detection is by team mask.
- **Gap: L–M.** No stealth units yet.

## 12. Skirmish AI: build, attack and difficulty
- **ZH** (`AI/AISkirmishPlayer.cpp`, `AI/AIPlayer.cpp`, `AI/AIStates.cpp`)
  - Data-driven build lists (SkirmishBuildList INI) and team prototypes with priorities.
  - Team building, recruiting and "ready" checks, then attack via scripts. Base defences on flanks (`buildAIBaseDefense(Bool flank)`).
  - Difficulty affects:
    - gatherer counts (above);
    - **victim selection inside a target squad** (`AIStates.cpp:5960–6020`): **Easy picks a random unit, Normal picks the closest, Hard has everyone pick the same unit** (focus fire). A human-issued command always gets the Hard behaviour.
- **Ours** (`ai/ai_player.gd`, `ai_tpla.gd`)
  - Opening build list, then dynamic builds; proportional base defence; waves with thresholds; per-unit and whole-wave retreat; scouting, capture and powers.
  - Difficulty changes think rate, first-wave time, wave size, bunkers, retreat and expansion.
  - Targeting is per unit (nearest armed enemy) on every difficulty.
- **Gap: M–H (#6).** Hard ZH armies focus fire, which shortens fights and feels deliberate; Easy armies spread fire. This is cheap to add on our side: an attack-move wave picks a shared victim for Hard and a random one for Easy.

## 13. Fog and shroud
- **ZH:** the partition manager tracks per-player looker counts per cell: shrouded (never seen), fogged (seen before) and visible. Ghost objects (`Object/GhostObject.cpp`) remember structures under fog.
- **Ours:** `SimFog` has shroud, fog and visible states plus fog memory of structures (ghosts in the view).
- **Gap: L.**

---

## Ranked gap list (gameplay feel)

| # | Gap | Impact | Plan |
|---|---|---|---|
| 1 | Locomotors: heading, turn rate, accel/brake; treads slow with turn angle, wheels clamp to turn speed, legs nimble; damaged speed | H | DONE a6352d3 |
| 2 | Weapon timing: pre-attack delay (per shot / attack / clip), clip + reload, turret/hull aim with turn rate before firing | H | DONE 9f9d09d |
| 3 | Accuracy: scatter radius, extra scatter vs infantry (cannons and artillery miss infantry) | H | DONE 75d6d83 |
| 4 | AI difficulty victim selection (Easy random / Medium nearest / Hard focus fire) | M–H | DONE e5abd48 |
| 5 | Group move at the slowest member's speed | M | DONE 0231771 |
| 6 | Damaged-state movement penalty (SpeedDamaged) | M | DONE a6352d3 (with #1) |
| 7 | Two-ring primary/secondary splash | L–M | deferred |
| 8 | Idle builder auto-repair ("bored" dozer) | L–M | deferred |
| 9 | Projectile travel time | L–M | deferred (keeps hitscan determinism simple) |
| 10 | Continuous-fire rate-of-fire ramp | L | deferred |
| 11 | Logic rate (30 Hz) | L | keep 20 Hz |
| 12 | Stealth delay / detectors for stealth units | L | deferred: no stealth units yet |

All numbers we add (turn rates, delays, clip sizes, scatter) are **our own tuning values**, chosen to give ZH-like behaviour. They are not ZH data.


## M2.3 implementation status
Gaps 1-6 are implemented in our own GDScript (no EA code in the project); every number used
(turn rates, acceleration, clip sizes, reload / pre-attack times, scatter radii, damaged-speed
penalty) is FRACTURE LINE tuning chosen to reproduce the *feel*, not data from Zero Hour (the
INI data is not in the released repository). Tests: `test_runner.tscn -- zh`.
Gaps 7+ remain deferred as listed above.
