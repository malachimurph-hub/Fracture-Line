# 0.4.5 (versionCode 29) — US mesh detail, Sub Station power, US voices

Shipped for phone testing as a sideload APK (com.malachimurphy.fractureline). The APK itself is built outside this change.

Gameplay stats, costs and footprints are unchanged.

## Models

`tools/m44/models_m44.gd` rebuilt the 0.4.4 US views on the same kit as the M1A3, Black Hawk and barracks (lofted hulls, glazing, tracks, fittings, faction camo, baked AO, LODs). The flat box pass is gone.

Vehicles: AH-6 Little Bird, AH-64, Reaper (pusher prop spins on the local forward axis), F-16, YF-22, F-35, B-1, Ripsaw.

Buildings: Sub Station, Nuclear plant (4×4, two cooling towers, `Stack0` / `Stack1` kept), DARPA, SOCOM, Robotics Plant, Zeus Launch Station, Zeus Pylon. Research tokens (`up_aero`, `up_robotics`, `up_nuclear`, `up_zeus`) were filled out the same way.

Jets and the Reaper keep grey paint (camo pattern 0, same as the older fighters). Ground vehicles and helicopters take the US tan pass.

HUD icons for these views were re-rendered from the new meshes.

## Infantry

Green Beret, SEAL and the MK 23 team no longer reuse the breacher, rifleman and grenadier bakes.

- Green Beret — green beret, radio, binoculars, carbine.
- SEAL — dark kit, balaclava, suppressed carbine, demo charges.
- MK 23 — gunner with a revolver grenade launcher (kneels to fire); assistant with a pistol and a 40 mm bandolier.

## Voices

Crewed new US units use US male AI banks under `audio/voice_ai/us/`, listed in `data/audio/voice_manifest.json`. The lines are role-matched takes from the existing US cast (attack-helicopter, fighter, bomber, rifleman, sniper, observer). Lines that name a retired unit or another job were left out. Where two units would otherwise be the same speaker, the copy is pitch-shifted so they are not identical.

| Unit | Folder | Source cast |
|---|---|---|
| AH-64 | `ah64` | Harrier gunship (includes the Hellfire call) |
| AH-6 Little Bird | `littlebird` | same pilot, higher, no Hellfire line |
| YF-22 | `yf22` | Wraith fighter, callsign lines dropped |
| F-16 | `f16` | same fighter, higher |
| F-35 | `f35` | same fighter, lower |
| B-1 | `b1` | Thunderlance bomber, callsign lines dropped |
| Green Beret | `green_beret` | rifleman, higher; no "Marine" / "Oorah" lines |
| SEAL | `seal` | sniper, lower; no "sniper" callsign |
| MK 23 | `mk23` | rifleman, lower |
| Drone Operator | `drone_operator` | observer, higher; no "JTAC" callsign |

The Ripsaw stays silent (`robot` tag, no bank). The Reaper is a drone: `AudioDirector.is_drone` now also matches the `drone` tag, so it gets the motor rev and the hum loop and no speech. It does not also play the helicopter engine loop. JTAC and Scout Sniper are unchanged.

## Power

Nuclear Research only unlocks the Nuclear Power Plant. Sub Stations keep producing their +12, and a new one can still be started. The US AI still prefers the plant for *new* power buildings once the research is done; yards already built stay on the grid.

The 0.4.4 note that Sub Stations drop to zero power is superseded by this.

## Ship
- versionName 0.4.5 / versionCode 29
- project.godot `config/version` 0.4.5
- sideload APK preset: package com.malachimurphy.fractureline, export `FractureLine-0.4.5.apk`, signed with the Android debug keystore at `/workspace/tools/android/keystore/debug.keystore`
- Play AAB preset: versionCode 29 / versionName 0.4.5 (package unchanged; AAB not built for this phone test)
