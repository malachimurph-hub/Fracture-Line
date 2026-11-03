# M4.2 batch (branch m42, not shipped; version unchanged)

Gameplay: rounds deal damage on impact (in-flight records, saved); transport helicopters land before troops
board (unloading in the air still allowed); "Unload All" with several transports selected; smart targeting
(weapon-vs-armour effectiveness weights target choice); rally points only on producers / garrisonable
structures; players can build next to Supply Stashes (AI keeps its old spacing to protect the stash economy);
anti-tank mines / demo traps removed for every faction; "veridite seam" renamed Supply Stash.
UI: pause menu Options (master / music / effects / voice / interface volume); Map Builder "Coming soon";
First Battle (narrated tutorial, US vs easy Iran) beside Skirmish until played or skipped.
Content: Sayad-3 SAM Site (Iran, long-range air defence); 4-hangar 10x8 airfields for all factions; Javelin
Foxhole crews are animated barracks infantry at full scale; town streets / pavements around civilian blocks.
Look: US aircraft + dozer grey, Black Hawk black, Iran vehicles cleaned up with modern desert khaki paint.
Voices: tools/m42/gen_voices_m42.py (Chatterbox Multilingual MIT + project Kokoro-82M Apache-2.0 / Piper
references, pitch-shifted to new male speakers; announcer for tutorial). QA in tools/m42/voice_qa_m42.json.
Drones: no voice; drone_ack.ogg (rev) + drone_hum_loop.ogg (looping 3D hum) synthesised from sine harmonics with ffmpeg aevalsrc for this project - original, no third-party audio.
