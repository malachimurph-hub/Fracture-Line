# M3.2 known issues / unverified (Russia part)

- **Russia is still locked** ("Coming soon") and will stay that way until Malachi approves the
  release.
- **No APK built yet.** M3.2 will ship as one combined release.
- **Russia's economy trails Iran in AI-vs-AI.** Harvest at 10 min is about 54k vs 87k. This was
  not changed in M3.2: harvester count and depot logic are the same as before. Matches still
  finish, with no stall.
- **The Tu-160 swing wing is fixed at mid sweep.** There is no sweep animation.
- **The Ka-52 cannon uses a small turret pivot on the starboard side.** Its traverse is
  wider than the real limited mount.
- **The Kremlin star on each hangar front sits behind the lintel** and is barely visible from
  the default camera.
- **Not checked on a phone.** Previews were rendered with the compatibility renderer under xvfb.

## M3.2 part 2 (new items)
- **Manned barricades fully shield their troops** (garrison model). The troops can't be hit
  until the barricade falls. It is not partial cover.
- **The Insurgent captures while always-stealthed.** Strong; it may need a reveal while
  capturing.
- **Captured airfields keep any parked enemy jets' home links.** That edge case was not
  exercised.
- **Captured buildings' units still need the captor to meet their prerequisites.** Units whose
  only prerequisite is the captured building work, others stay locked.
- **One battle track for Russia, Germany and Iran each** (about 100-120 s, repeats). US has 4.
  The music was checked by level and spectrum only, not listened to on a phone.
- **Item 14 textures are baked at 512 px per building and 256 px per unit**, in one 65-layer
  ETC2 array (about 11 MB), plus procedural triplanar detail. Per-asset 2048 px textures for
  every unit and building would not fit the 100 MB APK budget. Estimated APK size after item
  14: about 80 MB (terrain NRAO halved, -29 MB; bake atlas and detail meshes, about +15 MB).
  This is not measured, because no APK has been built.
- **Camera pitch is now 40 degrees (was 55).** At the far zoom, the top of the screen shows
  about 73 m of ground. Shadows are drawn to 82 m and scatter fades out at 64-74 m.
  Fog was left as it was.
- **Some maps have no village houses.** Ochre Wells (arid) and Crescent City (desert) get
  none, because European houses don't fit there. Crescent City gets dry yards and sidewalks
  instead.
- **Chimney positions are guessed from the building mesh** (sharp height peaks on the roof).
  A building with a tall antenna may smoke from the antenna.
- **Pre-existing touch-test failure:** "HUD buttons >= 44 dp" fails on 6 control-group
  buttons at 37 px. It already failed in the M3.1 run (Oct 24). Not changed here.
- **Cloud shadows drift on the ground only.** Units and buildings are not darkened by them.
- **Bridges are generated per tile from the map**, so jagged map bridge outlines show as
  stepped ends. The top-down RTS camera shows the deck more than the truss and piers.
- **Drone operator drones use the helicopter layer.** Bomb drones follow normal attack orders.
  There is no loiter AI for player-launched bomb drones.
- **Previews were rendered with the compatibility renderer** under xvfb. The phone uses the
  Mobile renderer, so glow and shadow look may differ slightly.
- **Stash test now measures depletion time, not match length** (Malachi's rule: stashes last about 17 min of mining; matches may end sooner). If a match ends first, the test extrapolates the empty time from the last 3 min of drain. Measured median: 18.6 min (target 15-19). Iran empties at about 12 min.
