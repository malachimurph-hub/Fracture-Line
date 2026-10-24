# Rules of Engagement M3.0.1 (version 0.3.1, versionCode 15, 24 Oct 2026)

Hotfix for M3.0. Malachi reported that the game seemed to lock up, with **Back** (worst when leaving
Settings) and **Start battle** taking a long time to respond.

## Menus respond at once
- **Back to the main menu is instant.** The live battle behind the main menu used to be rebuilt from
  scratch every time the menu opened: a whole 256 x 256 map, bases and armies, all at once on the
  main thread. Now it is paused and kept while Settings, the Skirmish lobby, Credits or the Map Builder
  is open, and the menu reuses it. It is freed when a battle starts.
- **No more freezes while the menu sits open.** The menu battle used to rebuild on a new map every
  150 seconds. It now keeps going on the same map and only changes the camera shot. A new map is still
  picked each time the menu battle is created.
- **A new menu battle (at start-up and after a match) is built in steps over several frames,** after
  the menu has appeared, and fades in. The buttons show and respond straight away.
- **Start battle shows "Loading battle…" straight away** and ignores extra taps, so a second tap can
  no longer start a second load. The same applies to Continue on the main menu.
- **Maps load faster.** The smooth shoreline field (water edges and foam) was computed for the whole
  map in script. Now only the area around the water is computed, and the result is cached per map
  layout, in memory and on the phone. Maps with water load about 1.3–1.8 s faster on the test box
  the first time, and about 1.6 s faster after that. The shoreline looks exactly the same
  (byte-identical).

## US buildings
- **New US Headquarters: a military command compound.** It is a low, hardened desert-tan concrete
  building with sloped walls and slit windows. It has a lattice comms mast, whip antennas, a satcom dish,
  a flag, blast walls, and a large vehicle bay with an open door and hazard-striped jambs. The bay lines up
  with the spot where new dozers appear, so they drive out of it. Rooftop beacons are kept. The footprint
  and gameplay are unchanged.
- **The Pentagon-style model moved to the Strategic Center.** It is the US intelligence and tech
  building; there is no separate intel building. It is scaled to fit the 3 x 3 pad and has the same
  rooftop beacons.
- Preview: `builds/m3_0_1/preview/us_hq_strategic.png`.
