# 0.4.7 (versionCode 31) — Russia, and the US fixes

Shipped for phone testing as a sideload APK (`com.malachimurphy.fractureline`). The APK and the Play AAB are not built in this change.

Russia is playable from the Kremlin through the Ministry, the same way the other factions are. Germany and Iran keep their rosters. The US roster is the same list of units, with the behaviour and look fixes below.

## Russia

Kremlin, Combined-Cycle Gas Plant, Barracks, Supply Depot, Vehicle Factory, Airfield, Ministry of Defense, FSB GRU, and the Black Market.

- Barracks trains Conscript squads. The Drone Operator needs the Ministry.
- The factory builds the Tiger-M, BTR, Typhoon, BMP-3, T-90M, Shilka, 2S Msta, TOS-1A, BMPT, Iskander, Pantsir, the T-26 (the late tank; the unit id is still `ecc_t14`), the Grim Reaper, the Engineer, and the MZKT-7930.
- The Airfield builds the Su-57, Ka-52, Mi-24, Mi-8, and the Tu-160.
- The Ministry researches the towers, Red Dawn, and the Grim Reaper. Pantsir, the T-26, and the Tu-160 need the Ministry.
- FSB GRU trains FSB Alfa, Spetsnaz, and VDV Spetsnaz. They stay hidden until they fight.
- The Black Market sells four hacks: grid shutdown, radar blackout, funds siphon, and unit hijack.

The MZKT-7930 leaves the factory as a bare truck. Pick one module. The choice is permanent, and there is no repair module.

| Module | Fit cost | What it does |
|---|---:|---|
| Anti-air | $800 | Long-range anti-air. Needs the Ministry. Outriggers plant for 8 seconds before it can fire, and it only shoots aircraft. |
| Radar | $1600 | Wide sight. Reveals hidden units. Friendly artillery within 12 tiles gains 25 percent range while the truck is halted. The bonus does not stack. |
| Cruise missile | $1100 | Long-range ground missile. Outriggers plant and the canisters rise for 8 seconds before it can fire. |

A move order packs the anti-air and the cruise missile before the truck rolls. The radar does not deploy. Iskander and Pantsir stay in the factory as their own vehicles.

## United States

- The Reaper flies a continuous circle while it is idle, moving, or attacking. It does not hover. The model is a pusher drone: long fuselage, straight wings, inverted-Y tail, spinning rear propeller, and a sensor ball under the nose. It still uses only the drone hum. Only base defences can detect it.
- ZEUS missiles deal their damage when the round arrives, with the explosion at that moment. They no longer hurt the target while the missile is still in the air.
- Rockets and missiles play a launch swoosh, with a little pitch variation so a salvo is not one repeated take. A heavy missile impact is a deep boom with a debris tail. Both sounds are original synthesis, not sampled recordings.
- The MK 23 Grenade Launcher Team plants a tripod and mounts the launcher before it can fire. A move order folds the tripod back up.

## Uniforms

Cloth is painted in the existing soldier shader. No new texture, and the draw count is unchanged.

- United States: MultiCam blotches, coyote plate carrier and pouches.
- Germany: Flecktarn dots, olive vest.
- Russia: regular infantry, Spetsnaz, and VDV use EMR digital green-brown. Conscripts keep the mixed Flora, EMR, olive, and woodland clothes.
- Iran: army infantry use a woodland pattern, because those units are olive rather than desert tan. The insurgent and the laborer stay in civilian clothes.
- The SEAL and the FSB infiltrator stay solid black. The blue marks are the existing team colour.

## Tests

Headless on Godot 4.7.2: `m47` (Russia, including the MZKT), `m44` (Reaper orbit, ZEUS impact, MK 23 tripod, missile sounds), `m42` (damage on impact), `content`, `zeus_silo`, `gfx_review`, `m34`.

## Ship

- versionName 0.4.7 / versionCode 31
- project.godot `config/version` 0.4.7
- Sideload APK preset: package `com.malachimurphy.fractureline` (unchanged), export `FractureLine-0.4.7.apk`. Signing settings were not changed.
- Play AAB preset: versionCode 31 / versionName 0.4.7, package `com.fracturline.modernconflict` (unchanged). Signing settings were not changed.
- This branch already contains `master` (0.4.6). Merging it into `master` is a fast-forward.
- The APK and the AAB were not exported or uploaded in this change.
