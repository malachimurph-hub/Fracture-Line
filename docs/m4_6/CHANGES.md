# 0.4.6 (versionCode 30) — faction polish and ZEUS silo

Includes the pending 0.4.6 polish (faction music, landed helicopter unload, Power Substation, quiet ambience, squad icons, icon-only command buttons) and the ZEUS visual pass. The APK and AAB are not built here.

Gameplay numbers that changed are only the Power Substation cost and output below. ZEUS cost, power, health, footprint, salvo, damage and the 14-tile pylon radius are unchanged.

## 1. Faction battle music

Battle music follows the local player's faction and stays on that faction's own list:

| Faction | Playlist |
|---|---|
| United States (`us`) | The four US tracks, shuffled. The menu track can appear later in the shuffle; it does not open the match. |
| Germany (`eu`) | `battle_de_tiefgarage.ogg` only. It loops. |
| Iran (`tpla`) | The Iran list only (Malachi's tracks plus Zagros). |
| Russia (`ecc`) | The Russia list only (Steppe March plus the Russia tracks). |

Germany used to pad a one-track list with everyone else's battle music, so a German match sounded like another team. Nothing is borrowed across factions anymore. In-faction shuffle is unchanged for the teams that have several tracks of their own.

## 2. Helicopters

Troops do not leave or board a helicopter in the air.

- Boarding was already "land first". That stays.
- Unload while the helicopter is flying or descending orders a landing (`drop`). Passengers step out only once it is parked. A helicopter that is already on the ground unloads on the same order.
- The fast-rope view (the rope mesh and the slide) is gone. Docs that described that rope as current behavior are updated.

A helicopter that is shot down still takes its passengers with it. That is not an unload.

## 3. US power

| Building | Display name | Cost | Power | Unlock |
|---|---|---|---|---|
| `us_substation` | Power Substation | $750 | +11 | Headquarters |
| `us_reactor` | Nuclear Power Station | $5200 | +64 | Nuclear Research (`us_up_nuclear`) |

+11 is the "slightly less" step. The old early plant was about +13. The 0.4.5 Sub Station was +12 at $1000. +11 is one point under that yard and two under the old early plant, and it sits in the +10 to +11 band. The lower price is the $750 retune. +10 would have been a larger cut next to a cheaper building; +11 keeps the early yard only a little weaker.

Nuclear Research still only unlocks the Nuclear Power Station. A Power Substation that is already built keeps its +11, and a new one can still be started. The station's +64 stacks on top. The US AI still prefers the station for new power buildings after the research; yards already up stay on the grid.

## 4. Ambience

Matches no longer start the continuous desert-wind loop. The field stays quiet. Every so often the game plays one short original cue: a bird chirp, a bird squawk, or a light breeze (`audio/ambient/bird_chirp.ogg`, `bird_squawk.ogg`, `breeze.ogg`). About half of the ambience rolls are more silence. None of those cues loop. The old wind file is still in the tree and is not used as a bed.

## 5. Squad icons

Production and selection icons for the four Combat Squads (`us_squad`, `eu_squad`, `tpla_squad`, `ecc_squad`) show six soldiers, using each faction's own trooper pictures (rifles, and the anti-tank soldier; Russia also shows the machine gunner). They were a single trooper before.

The MK 23 icon already shows the gunner and the assistant. Single-soldier units (sniper, rifleman, and the rest) stay one figure, because those units are one soldier.

Regenerate with `python3 tools/m46/squad_icons_m46.py`.

## 6. Selection menus are icons

The command grid (build, train, research, orders), the selection type chips, the production queue, and the resume-build button do not draw a name on the button when they have an icon. Order buttons that had no unit picture use a small original glyph (move, stop, unload, rally, and the rest). The name remains on the tooltip and on the press-and-hold info card. Prices, passenger counts, and queue badges stay on the button; they are not the name caption. The top bar (Build, pause, control groups) is unchanged.

## 7. ZEUS silo

The Zeus Launch Station is a fortified concrete silo block on the same 4×3 pad. Five heavy circular lids sit around one open shaft. A large dark-nosed missile stands in that shaft. Side walls, buttresses, pipe runs and a rear radar bunker carry the site. It is not the mountain complex from the reference.

When the station fires, the lids swing open and the standing round steps aside. Each shot leaves a shaft in turn. The round in the air is a large missile body with a dark nose and fins, climbing out of the silo before it turns onto the target. Launch smoke and the impact are scaled to that body. Damage, splash, the six-missile salvo and the 30 second recharge are the same.

The Zeus Pylon coverage ring uses the pylon's real `aux_radius` (14 tiles), the same disc the launcher aims into.

- Shown on the placement ghost, and it follows the ghost.
- Hidden once placement is cancelled.
- Hidden on a finished pylon that is not selected, including right after construction finishes.
- Shown again while that pylon is selected, and hidden on deselect.
- Removed when the pylon is destroyed.
- Not drawn for other buildings, and not drawn for an enemy pylon.

Build and research icons for the station and the ZEUS research token were rendered from the new meshes.

## Tests

Headless: `audio`, `m35` (faction playlists, no borrowing), `m42` (land, then unload; no rope in the view), `m33` (Nuclear Power Station name), `m44` (Power Substation $750 / +11, and it still feeds the base after Nuclear Research; ZEUS salvo unchanged), `zeus_silo` (silo mesh, heavy missile, pylon ring), `content` (CSV matches the building resource).

## Ship

- versionName 0.4.6 / versionCode 30
- project.godot `config/version` 0.4.6
- Sideload APK preset: package `com.malachimurphy.fractureline` (unchanged), export `FractureLine-0.4.6.apk`
- Play AAB preset: versionCode 30 / versionName 0.4.6, package unchanged
- APK and AAB were not exported or uploaded in this change
