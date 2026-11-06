# Faction music, helicopter unload, US power, ambience, squad icons, icon-only menus

No version bump and no export. Gameplay numbers below are the ones that changed.

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

## Tests

Headless: `audio`, `m35` (faction playlists, no borrowing), `m42` (land, then unload; no rope in the view), `m33` (Nuclear Power Station name), `m44` (Power Substation $750 / +11, and it still feeds the base after Nuclear Research), `content` (CSV matches the building resource).
