# M2.5 known issues

- **US is strong against the AI.** In hard-vs-hard AI soaks the US wins most 1v1s against both
  the EU and the TPLA (numbers in SOAK.md, reported as-is; no balance pass was done). Likely
  causes: aircraft vs AIs that only start building AA after they see aircraft, and the JTAC
  call-in. Balance pass pending Malachi's US building list.
- **Doubling supplies lengthens games.** In the supply soak one hard-vs-hard match ran to the
  40:00 cap without a winner (stalemate). Others ended normally.
- **TPLA voice quality is not perfect (v2 retune).** Chatterbox sometimes swallows or bends a word: the
  accent is deliberate, but a few takes are still under the 0.7 Whisper word-match threshold
  after the re-render pass (see voice QA in SOAK.md / builds/m2_5/voice_qa.json). Short unit
  names ("Rattler", "Scrapback") are heard by Whisper as "Radcliffe" / "Skrubback", but are
  intelligible in context.
- **TPLA voice watermark.** Chatterbox embeds Resemble AI's imperceptible Perth watermark in
  every TPLA line. This is harmless, but it identifies the audio as AI-generated.
- **Piper base voice licence (prompts only).** The Piper Persian voices amir and reza_ibrahim
  were fine-tuned from Piper's "lessac" English voice, whose dataset has research-oriented terms.
  - They are used only to make synthetic reference prompts and are not shipped.
  - Get a licence review before any commercial release, or re-prompt Chatterbox from a voice
    with a fully permissive lineage.
- **Air layer is new.**
  - Jets land by gliding straight down onto their parking spot. There is no runway taxi or
    take-off roll.
  - Aircraft fly over everything and ignore terrain height.
  - Helicopter and jet altitude is view-only (the sim is 2D).
- **US placeholder buildings** (Fusion Plant, Strategy Center, Bulwark SAM, Fire Base, Drop Zone)
  are marked "placeholder pending Malachi's list" and may change.
- **Lynx passengers can't fire from inside** ([STUB]).
- **Software-renderer screenshots.** builds/m2_5/screens are rendered with llvmpipe (OpenGL
  fallback). Infantry looks darker there than on the phone's Vulkan renderer, and the showcase
  inflates HP and slows time during fights (test harness only).
- **Phone performance not measured** for the new maps and aircraft. The M2.4 shadow
  draw-call budget issue still applies.
- All M2.4 known issues still apply (damage applied on fire, shader instance-variable cap on
  GL, generic construction rigs, debug-key signature, arm64-only).
