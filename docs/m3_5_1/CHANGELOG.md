# 0.4.1 (versionCode 25) - Malachi's helicopter / Germany defence / effects update

## New units: transport helicopters (built at the Airfield)
- **UH-60 Black Hawk** (USA): $1,300, 13 s, 720 HP, 6 seats (two Combat Squads), two M134 door
  miniguns (5 dmg every 70 ms, heavy-MG class, 5.5 tiles). Speed 4,460 mt/s.
- **Mi-24 Hind** (Russia): $1,450, 14 s, 880 HP, 6 seats, one 20 mm nose cannon in a chin turret
  (18 dmg every 260 ms, autocannon, 6 tiles). Speed 4,180 mt/s. Toughest, slowest.
- **H145M** (Germany): $1,150, 12 s, 620 HP, 6 seats, two light door MGs (7 dmg every 110 ms,
  small arms, 5 tiles). Speed 4,720 mt/s. Fastest, cheapest, lightest guns.
- Board with infantry like any transport, fly, Unload anywhere. Shot down = everyone aboard is lost.
- AIs build one or two from their airfields (they fight with their guns; the AI does not air-drop).
- Iran has no transport helicopter (as asked).

## New Germany defences
- **Guard Tower**: $700, 9 s, 1,100 HP, -2 power, steel tower with a sandbagged cabin, a .50 cal
  (19 dmg every 200 ms, heavy MG, 6.5 tiles) and a searchlight that turns with the gun.
- **Javelin Foxhole**: $1,100, 12 s, 1,300 HP, -2 power, sandbag ring with two kneeling Javelin
  teams; 136 dmg anti-tank every 1.5 s at 9 tiles (longest-range ground defence), no air.
- **MANTIS AA Turret**: $1,200, 12 s, 1,200 HP, -4 power (needs a Motor Pool), single-barrel 35 mm
  revolver cannon: vs air 26 dmg every 110 ms at 9 tiles; vs ground aa_ground 14 every 110 ms
  at 7.5 tiles (180 % vs light, 160 % vs heavy vehicles).
- The German AI adds one of each as the match goes on (normal/hard).

## Changes
- All aircraft (helicopters and jets) +35 % speed (e.g. Harrier/Tiger/Ka-52 3,200 -> 4,320;
  fighters 5,600 -> 7,560; Su-57/MiG-29 5,800 -> 7,830). Drones unchanged.
- Crude Oil Reserves (the supply stashes) redesigned and about twice the size: three storage tanks
  in a bund wall, pump house, manifold, loading gantry, drums on pallets (2.5 x 2.1 tiles, was
  1.1 x 0.9); sim radius 900 -> 1300.
- Power plants (all factions) vent less: one puff every 0.8 s (was 0.32 s) at 60 % size/opacity.
- Building floodlights dialled back (smaller, dimmer flares, pools and shafts) and now sit on the
  model's walls instead of floating at the footprint edge.
- Helicopters no longer leave a trail; jets keep theirs.
- Sound: new heavy .50 cal / 12.7 mm sound (slow, deep thump) for every heavy MG; rifle-calibre
  MGs use the lighter MG burst; door miniguns get a ~3,000 rpm buzz with a ringing whine;
  explosions and howitzer shots have a synthesized outdoor reverb tail. All original (numpy synth,
  tools/m41/gen_audio_m41.py).
- Size: two unused infantry models (Russian placeholder rifleman, Iranian laborer, 1.4 MB) left
  out of the APK (assets/models/infantry/superseded/).
- Tests: new m41 suite.

# Music update (0.4.0, versionCode 24)

The Russia and Iran music held back from 0.3.7-0.3.9, re-encoded to fit the 100 MB delivery limit: all 20 tracks OGG Vorbis mono, 16 kHz, 17 kbps nominal (~20 kbps actual).

## Russia and Iran music (Malachi's tracks)
- Malachi's "Russia music" and "Iran Music" Drive uploads (2026-10-31), MP3 48 kHz stereo,
  converted to OGG Vorbis 56 kbps 44.1 kHz like the M3.4 US tracks (`audio/music/ru_*`, `ir_*`).
- Russia (7): Steppe March (kept), Red Banner March, Forward Comrades, Iron Rhythm (Железный ритм),
  Moscow Techno (1), Moscow Techno (2), Desionaries. The synthesized hard bass "Red Bounce" is
  superseded by Moscow Techno and moved to `audio/music/superseded/` (not packaged).
- Iran (8): Defend the Holy Land, Iran Victory, Triumph of the Dunes, Descent into Dust, Dusty Loop,
  Setar's Waiting Riff, Iron and Flower (آهن و گل), plus Zagros (kept).
- With 3+ tracks each, Russia and Iran no longer borrow other factions' music; only Germany does.
- Credits list the new titles as original music by Malachi Murphy; MUSIC_SOURCES.md updated.
- Size: at 56 kbps the full soundtrack made the APK 111.4 MB; mono 16 kHz brings the music from 21.3 MB to 8.8 MB and the APK to 98,935,815 bytes.
- Tests: m35 adds a Russia/Iran own-playlist check. All suites, board, m34 and m35 pass.

## No income cap (M3.7.1, Malachi: "each passive income structure should not have a cap")
- Every copy of a passive income structure now pays (EU Hub and other `passive_income`
  buildings, and the `income_amount` earners such as Iran's Oil Derrick). Before, only the first
  4 copies of each type counted. Income popups and the info card ("each one pays") follow.

## Build info (0.4.1)
- Release APK: `export_build/FractureLine-0.4.1.apk`, 97,943,532 bytes (after tools/apk_recompress.sh),
  SHA-256 be7d3c734fa90057967c253b80b4fdcf66e32180b5256296338ed3d5c778e724, versionCode 25,
  signer cert SHA-256 7e96c70a…ce54 (same key, installs over 0.4.0). Uploaded to Drive root.
- Play AAB rebuilt at `builds/play/FractureLine.aab` (not uploaded).
- Superseded assets deleted (about 9.5 MB of source).
