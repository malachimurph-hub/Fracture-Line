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
In progress (generation still running in the background; re-run the generator to resume): 258/520 lines regenerated (EU 32/135, US 65/224, TPLA 161/161). Mean Whisper word-match 0.76; 93 line(s) still under 0.8 after all retakes:

- `audio/voice_ai/eu/aegis/select_1.ogg` "Aegis online.": QA 0.00, heard ""
- `audio/voice_ai/eu/aegis/select_3.ogg` "Grid link stable.": QA 0.00, heard ""
- `audio/voice_ai/eu/aegis/select_4.ogg` "Projector standing by.": QA 0.00, heard "I'm sorry, but I  I'm sorry, but I'm sorry, but I  I'm sorry, but I am"
- `audio/voice_ai/eu/crawler/select_1.ogg` "Crawler here.": QA 0.50, heard "Call her here!"
- `audio/voice_ai/eu/flakwerk/select_1.ogg` "Flakwerk.": QA 0.00, heard ""
- `audio/voice_ai/eu/flakwerk/select_4.ogg` "Radar's clean.": QA 0.50, heard "Radosk.  Clean."
- `audio/voice_ai/eu/grenadier/select_1.ogg` "Squad ready.": QA 0.00, heard ""
- `audio/voice_ai/eu/grenadier/select_2.ogg` "Grenadiers.": QA 0.00, heard "G'hainna Diaz"
- `audio/voice_ai/eu/harvester/select_1.ogg` "Hauler here.": QA 0.50, heard "here."
- `audio/voice_ai/eu/harvester/select_2.ogg` "Supply run?": QA 0.00, heard ""
- `audio/voice_ai/eu/lancer/select_2.ogg` "Tube's loaded.": QA 0.50, heard "to you, too-  to you loaded"
- `audio/voice_ai/eu/lancer/select_3.ogg` "Show me armour.": QA 0.67, heard "Show me."
- `audio/voice_ai/eu/leopold/select_1.ogg` "Leopold.": QA 0.00, heard ""
- `audio/voice_ai/eu/wolfhound/select_1.ogg` "Wolfhound.": QA 0.00, heard ""
- `audio/voice_ai/eu/wolfhound/select_2.ogg` "Recon ready.": QA 0.50, heard "Already"
- `audio/voice_ai/announcer_tpla/base_under_attack_2.ogg` "Our base is under attack!": QA 0.00, heard "in the next video.  Thank you so much for watching."
- `audio/voice_ai/announcer_tpla/battle_start_1.ogg` "The network is live.": QA 0.50, heard "The network T."
- `audio/voice_ai/announcer_tpla/enemy_power_detected_1.ogg` "Enemy strike incoming!": QA 0.67, heard "Let me strike incoming."
- `audio/voice_ai/announcer_tpla/general_promoted_1.ogg` "Commander promoted.": QA 0.00, heard "..."
- `audio/voice_ai/announcer_tpla/hole_rebuild_1.ogg` "Rebuilding from the rubble.": QA 0.25, heard "the"
- `audio/voice_ai/announcer_tpla/player_eliminated_1.ogg` "A player is finished.": QA 0.75, heard "The play are it is finished."
- `audio/voice_ai/announcer_tpla/salvage_upgrade_1.ogg` "Salvage upgrade.": QA 0.00, heard ""
- `audio/voice_ai/announcer_tpla/trap_detonated_1.ogg` "Trap sprung.": QA 0.00, heard "The, is,-,"
- `audio/voice_ai/announcer_tpla/tunnel_lost_1.ogg` "A tunnel has collapsed.": QA 0.50, heard "Donald has collapsed"
- `audio/voice_ai/announcer_tpla/unit_promoted_1.ogg` "A fighter has risen.": QA 0.75, heard "The fighterילו has risen.,"
- `audio/voice_ai/announcer_tpla/unit_ready_1.ogg` "Fighter ready.": QA 0.50, heard "Fight,"
- `audio/voice_ai/announcer_tpla/units_under_attack_1.ogg` "Our fighters are under attack.": QA 0.20, heard "Fighters., fight, fight, fight,, fight, fight,"
- `audio/voice_ai/announcer_tpla/victory_1.ogg` "Victory. The Basin is free.": QA 0.60, heard "the the guitar is and the spears is free.�"
- `audio/voice_ai/tpla/blight/attack_1.ogg` "Rust them.": QA 0.00, heard "3, 4, 3, 2,"
- `audio/voice_ai/tpla/blight/attack_2.ogg` "Canister away!": QA 0.00, heard "I'm..."
- `audio/voice_ai/tpla/blight/created_2.ogg` "Rust artillery online.": QA 0.00, heard "to the world., the world is a place to be.  Let's start with,  this is the same as I did before"
- `audio/voice_ai/tpla/blight/select_2.ogg` "Canisters ready.": QA 0.00, heard ""
- `audio/voice_ai/tpla/blight/under_fire_1.ogg` "Launcher under fire!": QA 0.67, heard "Launcher, Kandar, fire."
- `audio/voice_ai/tpla/blight/veteran_1.ogg` "Thicker rust now.": QA 0.00, heard "a"
- `audio/voice_ai/tpla/hailstorm/attack_3.ogg` "Shred that plane!": QA 0.67, heard "Shred that blame."
- `audio/voice_ai/tpla/hailstorm/created_2.ogg` "Quad gun on the line.": QA 0.60, heard "The Quad-Gantt on the"
- `audio/voice_ai/tpla/hailstorm/select_3.ogg` "Four barrels, ready.": QA 0.00, heard ""
- `audio/voice_ai/tpla/hailstorm/veteran_1.ogg` "Tighter bursts now.": QA 0.33, heard "First, now-"
- `audio/voice_ai/tpla/laborer/build_1.ogg` "We'll knock it together.": QA 0.75, heard "We'll knock it."
- `audio/voice_ai/tpla/laborer/build_2.ogg` "Scrap and sweat, coming up.": QA 0.00, heard ""
- `audio/voice_ai/tpla/laborer/build_3.ogg` "I'll build it.": QA 0.00, heard ""
- `audio/voice_ai/tpla/laborer/created_1.ogg` "Another pair of hands.": QA 0.00, heard ""
- `audio/voice_ai/tpla/laborer/created_2.ogg` "Laborer ready to work.": QA 0.00, heard ""
- `audio/voice_ai/tpla/laborer/harvest_2.ogg` "Back to the pile.": QA 0.75, heard "Back to the ball"
- `audio/voice_ai/tpla/laborer/move_2.ogg` "On my way.": QA 0.67, heard "my way"
- `audio/voice_ai/tpla/laborer/move_3.ogg` "Khalas! Okay, I'm going.": QA 0.00, heard ""
- `audio/voice_ai/tpla/laborer/move_4.ogg` "Heading over.": QA 0.50, heard "Heading to Far."
- `audio/voice_ai/tpla/laborer/select_2.ogg` "Got my shovel.": QA 0.67, heard "Got my shuffle"
- `audio/voice_ai/tpla/laborer/select_3.ogg` "Laborer here.": QA 0.00, heard ""
- `audio/voice_ai/tpla/laborer/under_fire_1.ogg` "They're shooting at the workers!": QA 0.60, heard "They are shooting Tatda workers."
- `audio/voice_ai/tpla/laborer/under_fire_2.ogg` "Cover! We're just diggers!": QA 0.00, heard ""
- `audio/voice_ai/tpla/mule/created_2.ogg` "Demolition truck ready.": QA 0.33, heard "Demilition"
- `audio/voice_ai/tpla/mule/move_4.ogg` "Slow and steady.": QA 0.67, heard "A slow-done study."
- `audio/voice_ai/tpla/mule/select_1.ogg` "Mule.": QA 0.00, heard ""
- `audio/voice_ai/tpla/mule/select_2.ogg` "Careful with the cargo.": QA 0.75, heard "with the cargo"
- `audio/voice_ai/tpla/rattler/attack_1.ogg` "Spray them!": QA 0.00, heard ""
- `audio/voice_ai/tpla/rattler/attack_2.ogg` "Gunner, open up!": QA 0.67, heard "Gunner open ups."
- `audio/voice_ai/tpla/rattler/attack_3.ogg` "Shoot as we pass!": QA 0.00, heard ""
- `audio/voice_ai/tpla/rattler/attack_4.ogg` "Rattle them!": QA 0.50, heard "I told them"
- `audio/voice_ai/tpla/rattler/created_2.ogg` "Fresh truck, fresh gun.": QA 0.25, heard "track,-f"
- `audio/voice_ai/tpla/rattler/move_4.ogg` "Kick up the dust!": QA 0.75, heard "Kick up the it does"
- `audio/voice_ai/tpla/rattler/select_1.ogg` "Rattler here!": QA 0.00, heard ""
- `audio/voice_ai/tpla/rattler/select_2.ogg` "Engine's coughing, but ready.": QA 0.75, heard "She's coughing, but ready."
- `audio/voice_ai/tpla/rattler/select_3.ogg` "Gun's on the back.": QA 0.75, heard "Gents on the back"
- `audio/voice_ai/tpla/rocket_cell/attack_2.ogg` "Hit the armour!": QA 0.67, heard "Hit the, Hit the"
- `audio/voice_ai/tpla/rocket_cell/attack_4.ogg` "Burn that tank!": QA 0.67, heard "Burned that tank"
- `audio/voice_ai/tpla/rocket_cell/created_2.ogg` "Anti-armour team here.": QA 0.75, heard "Anti-Arma team here."
- `audio/voice_ai/tpla/rocket_cell/move_2.ogg` "Keep low, move!": QA 0.67, heard "Keep the love move"
- `audio/voice_ai/tpla/rocket_cell/move_4.ogg` "Going.": QA 0.00, heard ""
- `audio/voice_ai/tpla/rocket_cell/select_1.ogg` "Rocket cell.": QA 0.00, heard ""
- `audio/voice_ai/tpla/rocket_cell/select_3.ogg` "Point us at steel.": QA 0.25, heard "Boy, it has that steel."
- `audio/voice_ai/tpla/rocket_cell/select_4.ogg` "Loaded.": QA 0.00, heard ""
- `audio/voice_ai/tpla/rocket_cell/under_fire_1.ogg` "We're spotted!": QA 0.00, heard ""
- `audio/voice_ai/tpla/rocket_cell/under_fire_2.ogg` "Rocket team pinned down!": QA 0.75, heard "Rocket team pin down."
- `audio/voice_ai/tpla/scrapback/select_1.ogg` "Scrapback.": QA 0.00, heard "Scrubbog"
- `audio/voice_ai/tpla/scrapback/select_2.ogg` "Patched and ready.": QA 0.33, heard "Stand ready."
- `audio/voice_ai/tpla/scrapback/select_3.ogg` "Armour, such as it is.": QA 0.40, heard "or choose, it is."
- `audio/voice_ai/tpla/scrapback/under_fire_2.ogg` "Scrapback taking heavy hits!": QA 0.50, heard "I'm not taking heavy heat."
- `audio/voice_ai/tpla/shrike/select_2.ogg` "Racks loaded.": QA 0.50, heard "Rex loaded"
- `audio/voice_ai/tpla/shrike/select_3.ogg` "Fast and light.": QA 0.33, heard "incident light"
- `audio/voice_ai/tpla/shrike/select_4.ogg` "Ready to sting.": QA 0.00, heard ""
- `audio/voice_ai/tpla/shrike/under_fire_1.ogg` "Shrike's hit!": QA 0.50, heard "Shlikes,"
- `audio/voice_ai/tpla/shrike/under_fire_2.ogg` "Too hot, pulling out!": QA 0.50, heard "To hard pulling out"
- `audio/voice_ai/us/dozer/created_1.ogg` "Dozer ready to work.": QA 0.75, heard "Those are Ready, to Work  Ready,  to work.,"
- `audio/voice_ai/us/dozer/created_2.ogg` "Construction crew on site.": QA 0.75, heard "construction on site"
- `audio/voice_ai/us/dozer/move_4.ogg` "Copy, heading there.": QA 0.33, heard "Copy a"
- `audio/voice_ai/us/dozer/select_1.ogg` "Dozer here.": QA 0.50, heard "Those are here."
- `audio/voice_ai/us/dozer/under_fire_1.ogg` "Dozer taking fire!": QA 0.67, heard "taking fire"
- `audio/voice_ai/us/grunt/select_2.ogg` "Ready to go.": QA 0.67, heard "Ready to"
- `audio/voice_ai/us/javelin/select_4.ogg` "We've got tubes.": QA 0.33, heard "We've"
- `audio/voice_ai/us/lynx/select_1.ogg` "Lynx ready.": QA 0.50, heard "Links ready the"
- `audio/voice_ai/us/sniper/select_3.ogg` "In position.": QA 0.50, heard "in possession"
- `audio/voice_ai/us/supply_truck/select_1.ogg` "Supply truck.": QA 0.00, heard "..."

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
