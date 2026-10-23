# Rules of Engagement (formerly FRACTURE LINE) 0.2.5 (M2.5) — changelog

APK: FractureLine-M2.5.apk, versionName 0.2.5, versionCode 9 (Android, arm64).

## TPLA voices: English with Middle Eastern accents
- Every TPLA unit voice set and the TPLA announcer were re-voiced in English with Arabic / Persian
  accents. A few short shouts ("Yalla!", "Khalas", "Boro!") are mixed in; every order is plain,
  understandable English.
- Engine: Chatterbox Multilingual (Resemble AI, MIT), local and offline. Each unit type has its own
  synthetic speaker (prompt voice, pitch/formant shift, emotion). All TPLA lines share the TPLA
  walkie-talkie filter and are matched to −16 LUFS.
- New QA pass: Whisper transcribes every TPLA line; lines under 70% word match are re-rendered
  with new seeds and the best take is kept (`tools/voice_qa_me.py`).
- **v2 retune (Malachi: v1 sounded "slightly too Russian"; he loved the Militia):**
  - The announcer and every TPLA unit set except the Militia were regenerated from new prompts.
    The prompts use Arabic accent rules: p→b, v→f, full unreduced vowels, a single tapped r,
    and emphatic t/d/s before back vowels.
  - The old Persian rule w→v, a Slavic-sounding trait, is gone. Prompt pitch shifts are now kept
    within −2…+2 semitones.
  - The Militia keeps its v1 takes as the style reference.
- **Male-only unit voices (Malachi's rule; announcers may be female):**
  - EU Wolfhound, Aegis and Flakwerk, and US Picket and Harrier, were re-voiced with male voices.
  - TPLA Rocket Cell, Shrike and Blight lost their high (+3.5…+5 st) prompt shifts.
  - The voice manifest refuses female unit casts, and the audio test checks every unit line.
- Your own recordings in `res://audio/voice/` still override everything.
- TTS comparison: docs/m2_5/TTS_COMPARISON.md. Samples: builds/m2_5/voice_samples/*.mp3.

## Economy and minimap
- Supply seams and piles hold about 2x as much (derricks unchanged).
- The minimap shows a ZH-style supply icon for every seam and pile from the first second. The
  icons sit above the shroud, show the last-seen fill level, and disappear once a pile is seen
  empty.

## New maps (4 players, all playable by the AI)
- **Kessel Pass** (winter): a frozen river with bridges and ice fords, pine forests, rock
  ridges, and a mountain village.
- **Harrow Junction** (temperate): a canal through a small city with a street grid of
  garrisonable blocks, farmland, hedges and oak woods.
- **Ochre Wells** (arid): a walled market town ringed by a fordable wadi with deep oasis pools,
  mesas and salt flats, under low amber light.
- Each map has its own environment: CC0 terrain texture set, sun, ambient light, haze, colour
  grade, water and props.
- The lobby has a map picker with an environment-coloured preview.

## United States faction (playable and AI, any lobby slot)
- **Infantry:**
  - Marine Grunt.
  - Javelin Team (2 soldiers).
  - JTAC Observer: wide sight, +35% HP, calls in idle aircraft at his target, and gives +25%
    damage and tighter spread to artillery and air strikes near him.
  - Scout Sniper: invisible while still, one-shots infantry.
- **Vehicles:**
  - Halberd MBT (Abrams-inspired).
  - Lynx (JLTV-inspired; transports 5).
  - Picket SHORAD (Avenger-inspired).
  - Longreach howitzer (M777-inspired).
  - Dozer and Supply Truck.
- **Aircraft (new air layer):**
  - Airfield with 6 parking slots. Production holds while it is full.
  - Thunderlance bomber: 4 slots. One huge strike, then it lands and rearms (45 s).
  - Wraith fighter: 2 slots. The best anti-air in the game, a light bomb, and a short rearm.
  - Harrier gunship (Apache-inspired): uses no slot, never lands, and reloads in the air.
  - Jets cannot hover: they circle their target and fly home when they run out of ammo or sit
    idle.
  - Anti-air weapons now target air units properly (targets_air / targets_ground). Parked
    aircraft are ground targets.
- **Buildings:**
  - Command Center, Fusion Plant, Supply Center, Barracks, Garage, Airfield, Strategy Center,
    Bulwark SAM Battery, Fire Base, Supply Drop Zone.
  - Buildings Malachi did not specify follow the ZH USA layout and are marked "placeholder
    pending Malachi's list".
- **General powers:** UAV Recon, Paradrop, Precision Strike, Field Repair.
- **Voices:** modern American soldiers (13 unit sets) and an announcer, on the Kokoro American
  voices, with a US digital-radio filter.
- **Visuals:**
  - Procedural M2.2+-style models.
  - Baked Marine infantry.
  - Aircraft fly at altitude with spinning rotors, a glide path down to the pad and ground shadows.
  - Your own stealthed sniper is drawn translucent.
- **HUD:** airfield slot count, rearm countdown, "Hidden" line for a stealthed sniper, and a JTAC
  air-support alert.
- **AI:**
  - New US personality (Vanguard). It builds the airfield, respects slots, flies sorties, and
    caps JTAC/sniper counts.
  - The EU AI builds AA once it sees enemy aircraft.

## Tests and tools
- New `m25` headless test: 2x supply, 4 maps (4-player US/EU/TPLA/US match on each), minimap
  shroud icons, US content, air layer incl. save/load, sniper, JTAC and paradrop.
- The audio test now also covers US lines and the US announcer.
- The m24 test maps every US weapon to an effect class.
- New `tests/m25_showcase` renders the screenshots.
