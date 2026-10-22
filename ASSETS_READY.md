# ASSETS_READY — branch `assets-m26` (M2.6 asset track)

Worktree: `/workspace/mobile-rts/assets-wt`. It branched from master at `9d528cb`. It touches only asset files, asset tools/manifests, two shaders, and one new test scene. No gameplay or UI scripts are changed.

## How to merge

```
git -C /workspace/mobile-rts/project merge assets-m26     # merge-tree check: merges cleanly with master
```

- Open the editor once, or run `godot --headless --path . --import`, so the new `.res` infantry meshes and the regenerated `.tscn` views are imported.
- Regeneration commands, needed only when the generators change:
  - Models: `godot --headless --path . -s res://tools/gen_gfx_m6.gd` (M2.6 core units/buildings + VAT squad scenes).
  - Infantry bake: `godot --headless --path . -s res://tools/bake_infantry.gd`.
  - Voices: `python tools/gen_voices_m26.py [--only eu|us|tpla] [--unit <id>] [--event select] [--retake] --jobs 3`. Use the TTS venv `/workspace/tools/tts/venv`. The run is resumable through `tools/voice_qa_m26.json`.
  - Cast reels: `python tools/make_cast_reels_m26.py`.
  - Manifest + recording script: `python3 tools/voice_manifest_src.py`.
- The code track should update the in-game credits string `CREDITS_BODY` (translations), because it still describes Chatterbox for TPLA. The new text is in `docs/m2_6/CREDITS.md`.

## Task A — voices

- **Cast (`tools/voice_cast_m26.py`).** Every unit is now its own all-male character. Each one has:
  - its own Kokoro-82M male voice blend;
  - its own accent;
  - its own pitch, with formants shifted for "bigger" men or preserved;
  - its own pace and grit profile.
- **Grit** is subtle. It combines:
  - NumPy vocal roughness;
  - per-character FX before the faction radio: saturation, intercom, helmet, oxygen mask, bullhorn, close-mic;
  - per-event pitch, pace and roughness (barked attacks, strained under-fire lines).
- **Examples:**
  - US Halberd: rough Southern veteran tank commander on the intercom.
  - US Sniper: calm, quiet, close-mic.
  - Harrier / Wraith pilots: cocky, on the oxygen mask.
  - **Marine Rifleman:** a squad of three different tough, barking Marines. The unit is named "Marine Rifleman" everywhere and no line says "Grunt". The folder id `grunt` is unchanged, so recordings and code paths still work.
  - TPLA Hailstorm: gruff heavy gunner.
  - TPLA Rocket Cell: wary insurgents.
- **Accents:**
  - EU: European-accented English (German, French, Italian, Polish, Dutch, Swedish, Spanish), using rules in `tools/accent_eu.py`.
  - US: General American, plus Southern for a few old hands; modern tactical-radio filter.
  - TPLA: Arabic and Persian accent rules (`tools/accent_tts.py`) on Kokoro male voices, not Russian-sounding.
- **TPLA Militia is kept unchanged** (Malachi's favourite). **Licence flag:** its prompts came from lessac-derived Piper voices, so it is not clearly permissive (`docs/m2_6/LICENCE_REVIEW.md`). A licence-clean Kokoro candidate can be generated for comparison: `--unit tpla_militia --out assets_src/voice_m26_candidates`.
- **Announcers:**
  - EU and US (female) are unchanged.
  - The TPLA announcer is regenerated with a male Kokoro voice.
- **Pipeline is unchanged:**
  - Drop-in recordings in `res://audio/voice/<faction>/<unit>/<event>_<n>.ogg` still override everything.
  - `tools/import_voice.py` gained optional `pre=` (FX chain) and `lufs=` arguments; defaults are unchanged.
  - The recording script lists the M2.6 cast.
- **QA:**
  - Whisper small (faster-whisper) transcribes every line.
  - Under 0.8 word match → up to 3 retakes: weaker accent → slower → clean/slow.
  - Short barks get a second listen with more padding.
  - Results: `tools/voice_qa_m26.json`; status below.
- **Cast reels:** `builds/m2_6/voice_samples/cast_{eu,us,tpla}.mp3`, one line per unit back to back. The contents are listed in `cast_reels.txt`.

### Voice generation status
VOICE_STATUS_PLACEHOLDER

## Task B — graphics

- **New detailed models** (`tools/gfx_m6/core_m6.gd`, Geo kit, one draw per model, automatic LODs). Tris by model:

  | Model | Tris | Notes |
  |---|---|---|
  | EU Wolfhound | 3968 | 8x8, steering |
  | EU Flakwerk | 3708 | twin-gun SPAAG with radars |
  | EU Aegis | 2696 | projector mast, team lamps |
  | TPLA Scrapback | 3572 | salvage tiers kept |
  | TPLA Hailstorm | 2448 | quad AA truck, tiers |
  | EU HQ | 3460 | |
  | EU Heavy Factory | 2612 | sawtooth glazed roof, gantry |
  | EU Reactor | 2498 | |
  | TPLA Camp | 2340 | |
  | TPLA Den | 2688 | |
  | TPLA Workshop | 1972 | |

  All buildings keep foundation → scaffold → damage states → rubble, plus fire markers.
- **Geo kit** (`tools/gfx_m3/geo.gd`):
  - LODs for every mesh ≥120 tris.
  - New detail helpers: rivets, vents, hatches, jerrycans.
- **Surface shader** (`view/materials/model_m3.gdshaderinc`, applies to every m3-kit model): rain streaks, edge wear, roughness breakup, seam and rivet bump, ground contact AO.
- **Infantry** (Quaternius CC0 VAT):
  - Re-proportioned to be less cartoony (smaller heads, longer limbs and torso).
  - Fabric weave detail; brighter, less saturated albedo.
  - New squads: EU Lancer, TPLA Rocket Cell, TPLA Laborer.
- **Fix:** infantry rendered **black** in the compatibility/mobile fallback renderer (MultiMesh without per-instance colour gives COLOR = 0). Part colour is now packed into UV. The change is in `view/infantry/vat_soldier.gdshader` and `tools/bake_infantry.gd` only; `infantry_view.gd` is untouched.
- **No new textures** were added (detail is procedural), so texture memory is unchanged.

### Screenshots (2340x1080)
- Folder: `builds/m2_6/screens_assets/`.
- `before_*`, `after_*` and side-by-side `compare_*` for `{eu,tpla,us}_{lineup,closeup}`.
- Lineup: 4 main buildings and 8 core units. Closeup: tank plus infantry.

### Perf counters (RenderingServer, mobile → GL compatibility fallback on the box)
| Shot | Before prims / draws | After prims / draws |
|---|---|---|
| EU lineup | 55,630 / 125 | 83,368 / 86 |
| EU closeup | 31,012 / 25 | 31,804 / 22 |
| TPLA lineup | 45,526 / 119 | 56,254 / 86 |
| TPLA closeup | 9,922 / 26 | 22,772 / 21 |
| US lineup | 54,910 / 77 | 54,418 / 77 |
| US closeup | 24,532 / 22 | 24,148 / 22 |

- Detail went up while draw calls went down (single-material Geo models).
- The heaviest new model is about 4k tris, with LODs at distance.
- A large battle (150 units at ~2.5k + 40 buildings at ~2.8k) is about 0.5M tris before LOD. That is within the 600k / 300-draw / 350 MB budget.

## Tests run (worktree)
- `test_runner compile`: PASS (84 scripts).
- `audio`: PASS.
- `content`: PASS.
- `viewcost`: PASS.
- `roster`: PASS.
- `tests/assets_m26_showcase.tscn` renders all three factions without shader errors.

## Licences
See `docs/m2_6/CREDITS.md` (copied to `builds/m2_6/CREDITS.md`).
- Kokoro-82M: Apache-2.0.
- kokoro-onnx / ONNX Runtime / faster-whisper / Whisper weights: MIT.
- Quaternius Toon Shooter: CC0.
- ambientCG: CC0.
- FFmpeg + librubberband: offline tools only, nothing shipped.
- No EA assets. No real person's voice cloned. No paid services.
- Only flag: the TPLA Militia lines (lessac-derived prompts), as above.
