# Credits — FRACTURE LINE (Milestone 1, build 0.1.2-m1.2)

- **Game design, code, data, UI and text:** original work made for Malachi Murphy, built with Grok Bot.
- **3D models:** original. They are built procedurally in code (`tools/gen_views.gd`, `view/props/prop_meshes.gd`) from low-poly primitives and merged into multi-surface meshes. No imported or third-party models are used.
- **Terrain, map (Varno Crossing v2), factions and unit names:** original.
- **Textures:** all from **ambientCG** (https://ambientcg.com), licensed **CC0 1.0 Universal (public domain)**. The 1K colour maps were downscaled to 512 px and ship ETC2/ASTC compressed. No attribution is required; it is given here anyway.

  | Used as | ambientCG asset | Changes |
  |---|---|---|
  | Desert sand | Ground097 | resized |
  | Dirt | Ground109 | resized |
  | Dry scrub / green grass | Grass004 | resized, tinted in shader |
  | Rock / cliffs | Rock063 | resized, recoloured to warm grey-brown |
  | Asphalt roads | Asphalt033 | resized |
  | Riverbed | Gravel035 | resized |
  | Concrete (buildings, pads, bridges) | Concrete034 | resized |
  | Corrugated metal (hangars, sheds) | CorrugatedSteel005 | resized |

- **Shaders and effects:** original. These are the terrain splat, water, prop, particle puff and decal shaders, and the CPU particle system.
- **Sound effects, UI sounds and ambience:** original. They are synthesized from scratch with numpy DSP in `tools/gen_audio.py`; no samples or sound libraries are used.
- **Music:** original compositions, synthesized in `tools/gen_music.py`: "Dust Over Varno" (menu) and "Steel Rain" (battle).
- **Voices:** every unit and announcer line is meant to be recorded by **Malachi Murphy** (see VOICE_SCRIPT.md). Until a line is recorded, the game plays a clearly labelled **placeholder** made with the **eSpeak NG** text-to-speech program (https://github.com/espeak-ng/espeak-ng, GPL-3.0; only its generated audio ships, not the program) and processed with FFmpeg. All line wording is original.
- **Tools used offline (not shipped):** FFmpeg (LGPL/GPL) for audio encoding, Python with NumPy (BSD), and Pillow (HPND) for texture resizing.
- **Font:** Godot Engine's built-in default font (bundled with the engine, under the same MIT/OFL terms as the engine distribution).
- **Engine:** Godot Engine 4.7.2. Copyright (c) 2014-present Godot Engine contributors; (c) 2007-2014 Juan Linietsky, Ariel Manzur. MIT License.
  The full license text is shown in-game under **Credits / About**.
  The Android build uses a size-optimized custom build of the same 4.7.2-stable source. Unused modules are disabled, but the code is otherwise unmodified.
- **Inspiration:** the classic base-building RTS genre, especially Generals/Zero Hour-style play and look.
  No names, art, textures, models, audio, text or other assets from any EA or other commercial game are used, extracted or traced.
