# FRACTURE LINE M2.3 (0.2.3, versionCode 7) - "Zero Hour feel"

Built from a study of EA's GPL-3.0 C&C Generals / Zero Hour source release, used as a
**reference only** (see docs/ZH_REFERENCE.md). All code is our own GDScript; no EA code, art,
audio or names. Unit stat numbers are not in the released repository (INI data is absent), so
every number below is FRACTURE LINE tuning, not "official" data.

## Movement (gap 1 + 6)
- Units now have a real heading, turn rate, acceleration and braking (fixed-point, deterministic).
- Tracked vehicles (tanks, Crawler, Aegis) pivot: forward speed falls with heading error, zero at 45 deg+.
- Wheeled vehicles can't pivot: they slow to a turning speed above 9 deg of heading error.
- Infantry (legs) turn almost on the spot and reach speed almost instantly.
- Units brake into their destination and cut corners smoothly between path waypoints.
- Vehicles below 35 % HP move at 80 % speed.

## Weapons (gap 2 + 3)
- Units must face their target to fire: turreted vehicles traverse the turret at a per-unit rate
  (the turret view now follows the sim); hull-mounted units turn the whole unit.
- Pre-attack delays (Lancer missile lock-on, RPG, grenade, rust-shell artillery set-up), per shot,
  per new target or per clip.
- Clips and reloads: autocannon, flak, HMG, quad guns, scrap rockets and buggy rocket salvos fire
  bursts, then reload; idle units top up partly used clips.
- Scatter: artillery and lobbed weapons land around the aim point; cannons and rockets get extra
  scatter against infantry. A miss does no direct damage; splash still applies at the impact point.
  Tracers/shells fly to the real impact point.

## Skirmish AI (gap 4)
- Victim selection differs by difficulty: Easy spreads fire over random visible enemies, Medium
  fights the nearest enemy, Hard focus-fires the whole engaged group on the weakest armed enemy.

## Groups (gap 5)
- A group move/attack-move travels at the speed of its slowest member so mixed armies arrive
  together; stragglers further than 10 tiles from the group are not slowed.

## Balance
- Retuned after the mechanics changes (TPLA wheeled raiders accelerate/turn faster, shorter RPG and
  artillery set-up, less cannon scatter vs infantry, carbine 10->11, RPG 62->66; Leopold turret 75 deg/s).

## Tests
- New `zh` test suite (locomotors, turret/hull aim, pre-attack, clips, scatter rates, AI victim
  selection per difficulty, group speed). Full existing suite still passes; save/load and replay
  determinism unchanged (new state is saved).
