# Music sources and licences

All music in this folder is ORIGINAL, composed and rendered for Fracture Line: Modern Conflict by the
project's own synthesis scripts (numpy additive/subtractive synthesis + tanh overdrive, no
samples, no loops or recordings from anyone else). No CC0/CC-BY or paid/unlicensed material.
Licence: project-owned original work (same terms as the rest of the game).

| File | Title | Use | Style | Generator |
|---|---|---|---|---|
| menu_breach_point.ogg | Breach Point | Menu (loops) | hard rock "banger", E minor, 150 bpm | tools/gen_music_m29.py (M2.9) |
| battle_iron_convoy.ogg | Iron Convoy | In-match shuffle | driving hard rock, D minor, 132 bpm | tools/gen_music_m29.py (M2.9) |
| battle_dust_devils.ogg | Dust Devils | In-match shuffle | fast punk rock, A minor, 168 bpm | tools/gen_music_m29.py (M2.9) |
| battle_last_light.ogg | Last Light Rising | In-match shuffle | heavy half-time groove, C# minor, 96 bpm | tools/gen_music_m29.py (M2.9) |
| battle_steel_rain.ogg | Steel Rain | In-match shuffle | orchestral-electronic, D minor, 112 bpm | tools/gen_music.py (M1) |

The M1 menu track "Dust Over Varno" was retired in M2.9 (still reproducible with tools/gen_music.py).
Regenerate: `python3 tools/gen_music_m29.py [breach|convoy|devils|last]` (needs numpy + ffmpeg).
In-match playback: autoload/audio_director.gd BATTLE_PLAYLIST, shuffled without repeats.

## M3.2 faction battle music (tools/gen_music_m32.py)

| File | Title | Faction | Style |
|---|---|---|---|
| battle_us_liberty_steel.ogg | Liberty Steel | US (+ the M2.9 rock shuffle) | military rock, E minor, 144 bpm, marching-snare intro |
| battle_ru_red_bounce.ogg | Red Bounce | Russia | hard-bass techno, B (harmonic) minor, 152 bpm |
| battle_de_tiefgarage.ogg | Tiefgarage | Germany | Berlin club techno, A minor, 130 bpm, rumble kick, dub stabs, acid line |
| battle_ir_zagros.ogg | Zagros | Iran | cinematic war drums: daf, tombak, booms; santur tremolo + tar-like plucks, Shur-style mode |

Battle music follows the local player's faction (AudioDirector.FACTION_PLAYLISTS); the menu stays rock.
Regenerate: `python3 tools/gen_music_m32.py [us ru de ir] [--sample OUTDIR]`.

## M3.3 traditional Russian theme (tools/gen_music_m33_ru.py)

| File | Title | Faction | Style |
|---|---|---|---|
| battle_ru_steppe_march.ogg | Steppe March | Russia (opens every Russian match; Red Bounce stays in the shuffle) | traditional-style march, D minor, 108 bpm: male choir, balalaika tremolo and strums, bayan (button accordion) oom-pah, low brass, march snare, bass drum, timpani; accelerating balalaika bridge |

Original composition (melodies and harmony written for this game; no folk tunes, anthems or other
existing works quoted). Pure synthesis, no samples. Regenerate: `python3 tools/gen_music_m33_ru.py [--sample OUTDIR]`.

## M3.4 United States music (Malachi's own tracks)

Supplied by Malachi (his "USA MUSIC" Google Drive folder, made with Suno under his account; used
with his permission as the game's owner). Converted from MP3 to OGG Vorbis 44.1 kHz (first 128 kbps; 56 kbps for the 0.3.6 release so the
APK stays under 100 MB, together with the four Russia/Germany/Iran tracks, re-encoded to 56 kbps).

| File | Title | Use |
|---|---|---|
| us_base_command.ogg | Base Command | Main menu (loops); opens every US match, then in the US shuffle |
| us_defend_the_border.ogg | Defend the Border | US in-match shuffle |
| us_mission_accomplished.ogg | Mission Accomplished | US in-match shuffle |
| us_zero_hour.ogg | Zero Hour Background | US in-match shuffle |

The M2.9 rock tracks (Breach Point, Iron Convoy, Dust Devils, Last Light Rising, Steel Rain) and
M3.2 Liberty Steel are retired to `superseded/` (`.gdignore`, not packaged; still reproducible
with their generators). Other factions' music is unchanged.

## M3.5 Russia and Iran music (Malachi's own tracks)

Supplied by Malachi (his "Russia music" and "Iran Music" Google Drive folders, uploaded 2026-10-31;
used with his permission as the game's owner). Converted from MP3 (48 kHz stereo) to OGG Vorbis
44.1 kHz; see docs/m3_5/CHANGELOG.md for the bitrate used to keep the APK under 100 MB.

| File | Title (Drive file name) | Use |
|---|---|---|
| ru_red_banner_march.ogg | Red Banner March | Russia shuffle |
| ru_forward_comrades.ogg | Forward, Comrades | Russia shuffle |
| ru_iron_rhythm.ogg | Iron Rhythm ("Железный ритм") | Russia shuffle |
| ru_moscow_techno_1.ogg | Moscow Techno (1) | Russia shuffle |
| ru_moscow_techno_2.ogg | Moscow Techno (2) | Russia shuffle |
| ru_desionaries.ogg | Desionaries (title as uploaded) | Russia shuffle |
| ir_defend_the_holy_land.ogg | Defend the Holy Land | Iran shuffle |
| ir_iran_victory.ogg | Iran Victory | Iran shuffle |
| ir_triumph_of_the_dunes.ogg | Triumph of the Dunes | Iran shuffle |
| ir_descent_into_dust.ogg | Descent into Dust | Iran shuffle |
| ir_dusty_loop.ogg | Dusty Loop | Iran shuffle |
| ir_setars_waiting_riff.ogg | Setar's Waiting Riff | Iran shuffle |
| ir_iron_and_flower.ogg | Iron and Flower ("آهن و گل") | Iran shuffle |

Russia keeps the M3.3 "Steppe March"; Iran keeps "Zagros". The synthesized Russian hard bass
"Red Bounce" is superseded by "Moscow Techno" and moved to `superseded/` (not packaged).

## 0.4.0 size fit (Malachi approved lower music quality)
All 20 packaged tracks re-encoded from their best sources (Malachi's original MP3s; the
synthesized Tiefgarage / Zagros / Steppe March from their 128 kbps OGGs) to OGG Vorbis **mono,
16 kHz, 17 kbps nominal** (~20 kbps actual), so the full-soundtrack APK stays under 99 MB
(music 21.3 MB -> 8.8 MB). Stereo at 44.1 kHz cannot go below ~45 kbps in libvorbis, and mono
22 kHz below ~29 kbps; both would not fit.
