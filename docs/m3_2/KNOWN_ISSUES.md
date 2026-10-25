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
- **The graphics pass is a shader/grade/scatter/VFX pass, not new high-res textures or models.**
  Zero Hour parity in texture detail would need a texture repaint.
- **Bridges are generated per tile from the map**, so jagged map bridge outlines show as
  stepped ends. The top-down RTS camera shows the deck more than the truss and piers.
- **Drone operator drones use the helicopter layer.** Bomb drones follow normal attack orders.
  There is no loiter AI for player-launched bomb drones.
- **Previews were rendered with the compatibility renderer** under xvfb. The phone uses the
  Mobile renderer, so glow and shadow look may differ slightly.
- **Stash test now measures depletion time, not match length** (Malachi's rule: stashes last about 17 min of mining; matches may end sooner). If a match ends first, the test extrapolates the empty time from the last 3 min of drain. Measured median: 18.6 min (target 15-19). Iran empties at about 12 min.
