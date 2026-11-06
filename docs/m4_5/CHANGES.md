# M4.5 — US 0.4.4 mesh detail, and Sub Stations stay online

No version bump. Gameplay stats, costs and footprints are unchanged.

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

## Power

Nuclear Research only unlocks the Nuclear Power Plant. Sub Stations keep producing their +12, and a new one can still be started. The US AI still prefers the plant for *new* power buildings once the research is done; yards already built stay on the grid.

The 0.4.4 note that Sub Stations drop to zero power is superseded by this.
