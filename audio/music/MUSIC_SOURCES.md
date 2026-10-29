# Music sources and licences

All music in this folder is ORIGINAL, composed and rendered for Fracture Line: Global Conflict by the
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
