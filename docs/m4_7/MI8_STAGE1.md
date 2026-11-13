# Mi-8 Stage 1 audit

Audit only. No mesh was built. The three attached drawings are not one aircraft, so Stage 2 does not start until Malachi picks which drawing to trace.

## Which aircraft the drawings are

The colour three-view is labelled **Mil Mi-17 Hip H**, Kyrgyzstan Air Force, Batken 1999. Hip H is the Mi-8MT / Mi-17: TV3-117 engines, dust-filter intakes, and the tail rotor moved to the **port (left)** side. The plate shows a round glazed nose, a long cabin, clamshell rear doors, tricycle gear, five main blades and three tail blades. It does not show pylons, rocket pods, external tanks or a ramp.

The Russian line drawing is a different, armed transport: round windows, rocket pods and stores along the cabin. That is the older **Mi-8T** family (TV2-117, tail rotor on the **starboard** side in the published descriptions). It is not the colour plate.

The third sheet is a catalogue. It includes Mi-8T, Mi-8P, Mi-8MT, Mi-8MTV and the armed Mi-8AMTSh, which has a rear ramp, sensors and weapons. It is not a single aircraft.

Recommendation, not yet applied: trace the colour Mi-17 Hip H plate only. Do not copy pods from the Russian drawing or the ramp from the AMTSh row.

## Conflicts to resolve before modelling

1. **Which drawing is the source of truth.** The colour plate, the armed Russian drawing, and the multi-variant sheet disagree. They must not be combined.
2. **Tail-rotor side.** Hip H is port (left, -X with +Z forward). Classic Mi-8T is starboard (+X). The live `mi8.tscn` puts `TailRotor` at x = -0.12, so it already matches Hip H, not Mi-8T.
3. **Rear closure.** Hip H and Mi-8T use clamshell doors. Mi-8AMTSh and Mi-17V-5 use a ramp. The colour plate is clamshells.
4. **Cabin windows.** The colour plate reads as round portholes. Many Hip H airframes have rectangular cabin windows. Trace the plate if that plate is chosen, and do not "correct" it toward the other type.
5. **Door gun.** One reading of the colour plate shows a gun in the starboard doorway. That is not confirmed. Do not model a gun, pylon or tank unless Malachi says the chosen plate shows it. The unit already fires `ecc_mi8_mg` with no muzzle marker; that weapon stays a gameplay stat either way.
6. **Older repo photo.** `docs/m4_7/refs/mi8_side.jpg` is an armed round-window Mi-8 with rocket pods. It matches the Russian drawing, not the clean colour plate. It is not the source of truth for this pass.
7. **Published height.** Sources do not agree: about 4.38 m, 4.75 m and 5.54 m, and they do not say whether that is the fin, the hub or the mast. The drawings have no scale bar, so height cannot be traced off them. Proposed below as 4.75 m to the rotor hub, from the Czech MoD Mi-17 card, and flagged.
8. **Scale family.** The tanks and the BMP-3 are at about 0.311 units per metre. The helicopters already in the game are at about 0.15 to 0.19. One number cannot match both. See the table.

## Published size used for the proposal

Mi-17 Hip H, Czech Ministry of Defence card, except where noted.

| Measure | What it includes | Metres | At 0.311 u/m |
|---|---|---:|---:|
| Fuselage length | Nose to tail cone. No rotors. | 18.22 | 5.67 u |
| Overall length, rotors turning | One main blade forward and one aft, along the fuselage. Czech figure 25.35 m. | 25.35 | 7.88 u |
| Main-rotor diameter | Five blades, disc. | 21.29 | 6.62 u |
| Tail-rotor diameter | Three blades. | 3.91 | 1.22 u |
| Fuselage width | Cabin, not the wheels and not stores. | 2.50 | 0.78 u |
| Cabin interior | Length, width, height. Not an exterior measure. | 5.34 x 2.32 x 1.80 | 1.66 x 0.72 x 0.56 u |
| Height | Taken as ground to the main-rotor hub. Sources disagree. | 4.75 | 1.48 u |

Gear track is not on the drawings. Published Mi-8 figures are often a main-wheel track near 4.5 m and a wheelbase near 4.3 m. Stage 2 should place the wheels by tracing the colour plate, then check that track rather than invent it.

No logos, stars, tail numbers or the Kyrgyz roundel. The Humbrol callouts on the plate are paint notes, not markings to model.

## In-game measurements

Godot measured the live scenes. Hull boxes failed to separate because the nodes were not in the tree yet, so the figures below are the whole visible mesh, plus the rotor node and the rotor mesh. Vehicles are not scaled again at spawn.

| Scene | Tris | Whole mesh, units | Rotor disc, units | Implied u/m |
|---|---:|---|---|---|
| Mi-8 live | 2,022 | 3.02 x 1.59 x 3.85 | 3.17 across | 0.15 on a 21.29 m disc, 0.19 if the 3.5 u fuselage is 18.2 m |
| Black Hawk | 1,728 | 2.72 x 1.20 x 2.90 | 2.72 | 0.17 on a 16.36 m disc |
| Hind | 1,792 | 2.48 x 1.19 x 2.90 | 2.48 | 0.14 on a 17.3 m disc |
| Ka-52 | 1,890 | 1.81 x 1.02 x 2.35 | 1.81, coaxial | 0.13 on a 14.5 m disc |
| H145M | 844 | 2.30 x 0.92 x 2.57 | 2.30 | 0.21 on a 10.8 m disc |
| T-90 | 4,544 | 1.45 wide, 2.34 long with the gun | | 0.31 on the 6.86 m hull (2.13 u) |
| BMP-3 v2 | 7,372 | 1.02 wide, 2.22 long | | 0.311 |

**Proposed scale: 0.311 units per metre**, the same as the BMP-3 v2 and the T-90's measured hull. A real Mi-8 fuselage is 2.55 times a BMP-3 hull (18.22 / 7.14). At 0.311 that is 5.67 u against the BMP-3's 2.22 u.

That Mi-8 will not sit with the helicopters already in the game. Their meshes are about half that scale, so this aircraft would be roughly 2.7 times the Black Hawk's in-game length, while the real machines are only about 1.3 times apart on overall length. Matching the Black Hawk's 0.17 u/m instead would make the Mi-8 only about 1.6 times the BMP-3, against a real 2.55. Those two aims conflict. The recommendation is 0.311, and it needs a yes before Stage 2.

Hover height is a shared view constant, `HELI_ALT = 4.0` units, for every helicopter. At 0.311 the hub is about 1.5 u tall, so the same hover still clears the rotor, but the aircraft will look lower for its size than the current small Mi-8. Do not change `HELI_ALT` in the art pass. It would move every helicopter.

## What the live unit already is

`ecc_mi8` points at `view/units/ecc/mi8.tscn`. `mi8_legacy.tscn`, `mi8_blender.tscn` and `assets/models/ecc/mi8.glb` are unused. The live scene is the procedural kit in `tools/m47/ru_hulls.gd`, not the Blender file. `docs/m4_7/RUSSIA_TREE.md` still describes the Blender mesh and the rocket pods. That note is out of date.

Kept as they are through the art pass: unit id, `ecc_mi8_mg`, cost, hit points, speed, `transport_capacity` 8, `radius_mt` 760, `loco = heli`. Boarding is in `AirSys`: the helicopter lands, then infantry steps aboard. Unload uses one-tile steps, not a point on the mesh. Neither offset is derived from the model, so they stay.

Nodes the view code already requires:

- `Rotor` and `TailRotor`, not themselves meshes. `WorldView` spins every non-mesh node whose name contains `Rotor`.
- `rotor_axis` meta: `y` on the main rotor, `x` on the tail rotor. The tail rotor spins on its local X.
- `Hull`, `HealthBarAnchor`, and the `VehicleView` script on the root.
- `m47` checks that `mi8.tscn` has both rotor nodes and at least 900 triangles.

Selection and the health bar today: radius 1.35, bar and anchor at 1.45. There is no exhaust marker, no rotor-wash marker, no squad-exit marker, and the doors are painted into the hull.

## Stage 2 shape, if the colour plate and 0.311 are approved

Root on the ground, under the fuselage centre, wheels on y = 0. +Z is the nose.

```
View (VehicleView)
  Model
    Hull
    DoorPort
    ClamshellL
    ClamshellR
    Rotor                 hub, rotor_axis = y
      RotorMesh
    TailRotor             port side, rotor_axis = x
      RotorMesh
    ExhaustL
    ExhaustR
    RotorWash
    SquadExit             port door, just outboard of the sill
  HealthBarAnchor
```

`DoorPort` and the clamshells stay shut in Stage 2. They are separate so a later stage can open them. `SquadExit` is the embark point. It does not change the sim radius.

Blockout only: one fuselage loft, a glazed nose of a few panes, two engine cowlings and their intake mouths, the mast, a tapered tail boom, fin, tailplane, left tail-rotor hub, tricycle gear, five main blades and three tail blades. No pods, tanks, antennas, sensors or text. Flat surfaces get panel breaks, hatches and a grille only where the colour plate shows them.

Selection radius about 2.4 and the health anchor near the hub, about 1.5, to be checked in Stage 4. The ring should read around the cabin, not the whole rotor disc.

Triangle budget: Stage 2 under about 1,800. Finished model about 4,500 to 5,500. That is near the T-90 at 4,544 and under the BMP-3 v2 at 7,372. Blades are flat cards. Do not spend the budget on the interior.

Build it as `mi8_v2`, the same way as `bmp3_v2`, and leave `ecc_mi8` on `mi8.tscn` until Stage 4. `mi8.tscn` stays in the repo as the fallback.

Materials, when that stage comes: one `m3.tres`, vertex classes, and a cell on the shared bake atlas. No new standalone texture. The brief was cut off at "Do not use textur…". This audit assumes that meant no new texture files beyond the shared bake atlas.

## What Stage 2 must not do

Do not mix the three drawings. Do not add the rocket pods from the Russian drawing or the repo photo. Do not add a ramp. Do not move the tail rotor to the right unless the chosen drawing is the Mi-8T. Do not change hover height, transport capacity, the weapon, or any other helicopter.
