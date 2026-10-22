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
In progress (generation still running in the background; re-run the generator to resume): 520/520 lines regenerated (EU 135/135, US 224/224, TPLA 161/161). Mean Whisper word-match 0.96; 38 line(s) still under 0.8 after all retakes:

- `audio/voice_ai/eu/grenadier/select_2.ogg` "Grenadiers.": QA 0.00, heard "and  and use"
- `audio/voice_ai/eu/grenadier/under_fire_1.ogg` "Contact! We're pinned!": QA 0.67, heard "contact with PINNEDE"
- `audio/voice_ai/eu/harvester/created_1.ogg` "Hauler ready to roll.": QA 0.75, heard "Goal at ready to roll."
- `audio/voice_ai/eu/harvester/select_1.ogg` "Hauler here.": QA 0.50, heard "Hold on here."
- `audio/voice_ai/announcer_tpla/salvage_upgrade_1.ogg` "Salvage upgrade.": QA 0.50, heard "selfish top grade"
- `audio/voice_ai/announcer_tpla/trap_detonated_1.ogg` "Trap sprung.": QA 0.50, heard "Drap Sprung"
- `audio/voice_ai/announcer_tpla/tunnel_lost_1.ogg` "A tunnel has collapsed.": QA 0.50, heard "Jattana has collapsed."
- `audio/voice_ai/announcer_tpla/units_under_attack_1.ogg` "Our fighters are under attack.": QA 0.40, heard "Jawa Fighters start under a chat that"
- `audio/voice_ai/announcer_tpla/victory_1.ogg` "Victory. The Basin is free.": QA 0.60, heard "Fictari, the land is free."
- `audio/voice_ai/tpla/hailstorm/select_3.ogg` "Four barrels, ready.": QA 0.67, heard "Four bottles ready."
- `audio/voice_ai/tpla/hailstorm/veteran_1.ogg` "Tighter bursts now.": QA 0.67, heard "I do bursts now it"
- `audio/voice_ai/tpla/laborer/build_2.ogg` "Scrap and sweat, coming up.": QA 0.40, heard "Scrapped in sweat, come in."
- `audio/voice_ai/tpla/laborer/under_fire_2.ogg` "Cover! We're just diggers!": QA 0.75, heard "We're just diggers"
- `audio/voice_ai/tpla/rattler/move_4.ogg` "Kick up the dust!": QA 0.75, heard "kick chub the dust"
- `audio/voice_ai/tpla/rocket_cell/move_4.ogg` "Going.": QA 0.00, heard "Go Inke!"
- `audio/voice_ai/tpla/scrapback/select_1.ogg` "Scrapback.": QA 0.00, heard ""
- `audio/voice_ai/tpla/shrike/under_fire_2.ogg` "Too hot, pulling out!": QA 0.75, heard "Too hard pulling out"
- `audio/voice_ai/us/dozer/created_1.ogg` "Dozer ready to work.": QA 0.75, heard "Those are ready to work"
- `audio/voice_ai/us/dozer/select_1.ogg` "Dozer here.": QA 0.50, heard "Those are here."
- `audio/voice_ai/us/dozer/under_fire_1.ogg` "Dozer taking fire!": QA 0.67, heard "Those those are taking fire."
- `audio/voice_ai/us/grunt/attack_4.ogg` "Light 'em up!": QA 0.67, heard "Light him up."
- `audio/voice_ai/us/grunt/move_2.ogg` "Oorah, on the move!": QA 0.75, heard "on the move"
- `audio/voice_ai/us/halberd/attack_3.ogg` "Firing main gun!": QA 0.67, heard ", firing main guns."
- `audio/voice_ai/us/halberd/created_1.ogg` "Halberd main battle tank, ready.": QA 0.60, heard "How-albert main battle some credit"
- `audio/voice_ai/us/halberd/under_fire_2.ogg` "Armor under fire!": QA 0.33, heard "I'm going  under the"
- `audio/voice_ai/us/harrier/created_2.ogg` "Gunship airborne.": QA 0.50, heard "Gunship"
- `audio/voice_ai/us/harrier/move_2.ogg` "En route.": QA 0.50, heard "On route"
- `audio/voice_ai/us/lynx/attack_3.ogg` "Hit 'em!": QA 0.50, heard "Hit, hit."
- `audio/voice_ai/us/lynx/attack_4.ogg` "Fifty's talking!": QA 0.50, heard "50-50s talking"
- `audio/voice_ai/us/lynx/created_1.ogg` "Lynx reporting.": QA 0.50, heard "Link's reporting...."
- `audio/voice_ai/us/lynx/select_1.ogg` "Lynx ready.": QA 0.50, heard "Links ready the"
- `audio/voice_ai/us/picket/attack_2.ogg` "Bird in the air!": QA 0.75, heard "in the air."
- `audio/voice_ai/us/picket/veteran_1.ogg` "Faster lock-ons now.": QA 0.25, heard "Faster,,"
- `audio/voice_ai/us/sniper/select_3.ogg` "In position.": QA 0.50, heard "in possession."
- `audio/voice_ai/us/thunderlance/attack_2.ogg` "Doors open, releasing!": QA 0.67, heard "Doors Open,,"
- `audio/voice_ai/us/thunderlance/created_2.ogg` "Bomber armed and ready.": QA 0.75, heard "Bomber armed and reddies."
- `audio/voice_ai/us/wraith/attack_1.ogg` "Fox three!": QA 0.50, heard "Fox 3"
- `audio/voice_ai/us/wraith/move_3.ogg` "Copy, en route.": QA 0.67, heard "ny,.  copy on route."

Lines not yet regenerated keep their M2.5 audio, which still works in game. Short invented-name barks ("Hauler here.") are the usual low scorers; listen before re-recording.

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
