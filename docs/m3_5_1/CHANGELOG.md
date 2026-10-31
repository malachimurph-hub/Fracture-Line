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
