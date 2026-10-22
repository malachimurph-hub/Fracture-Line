# M2.6 licence review: TPLA voice prompt models

Checked on 22 Oct 2026 against the model cards that ship with each voice and the upstream
licence pages.

## Persian Piper voices used for TPLA prompts in M2.5

| Piper voice | Dataset licence (model card) | Base weights |
|---|---|---|
| fa_IR-amir-medium | CC0 (datacula) | **Fine-tuned from en_US-lessac-medium** |
| fa_IR-reza_ibrahim-medium | CC0 (Hedayatfar / Ibrahim Walk Quran audio) | **Fine-tuned from en_US-lessac-medium** |
| fa_IR-ganji-medium | CC0 (datacula) | Fine-tuned from fa_IR-amir, so **also lessac-derived** |
| (unused) ar_JO-kareem-medium | "See URL" | Fine-tuned from lessac |
| (unused) fa_IR-gyro-medium | "See URL" | Unclear |

## The lessac base

- en_US-lessac was trained on the **Lessac Technologies Blizzard 2013** corpus.
- That corpus licence grants use "exclusively for Research Purposes only".
  - It forbids commercial use.
  - It forbids passing the materials to third parties.
  - Source: <https://www.cstr.ed.ac.uk/projects/blizzard/2013/lessac_blizzard2013/license.html>
- The Piper maintainers say the model card only records the training dataset's licence. They
  leave open whether fine-tuned weights are derivative works, and they are retraining voices on
  libritts_r to avoid the question.
  - Source: <https://huggingface.co/rhasspy/piper-voices/discussions/105>

## Finding

The datasets of the three voices are CC0, but all three voices inherit lessac weights. The
lessac licence is research-only, and whether it carries over to fine-tuned weights is
explicitly unresolved upstream. A personal game is not clearly "research". So this is
**not clearly permissive for personal use**.

The TPLA lines should therefore be regenerated without these voices.

## Handoff (M2.6 scope change)

Voice production now belongs to the asset worker (branch `assets-m26`). This code track
stopped before regenerating any audio; audio/voice_ai is untouched here.

Ready for the asset worker on master (commit 06499e2):
- **`tools/accent_tts.py` `synth_kokoro()`** renders a licence-clean accented prompt speaker.
  - It uses Kokoro-82M male voice styles (Apache-2.0 weights, already used for EU and US).
  - They are driven directly with the Arabic-accent phoneme rules.
  - Glottal-stop onsets are added; ˤ is dropped because Kokoro has no symbol for it.
  - Use it in place of the Piper prompts in `gen_ai_voices_me.prompt_for`.
- **`tools/voice_cast_search.py`** scores candidate prompt voices against the shipped Militia
  takes (Malachi's reference). It reports speaker-embedding similarity, Whisper word match and
  median pitch.
  - Its first run was stopped by the scope change; no results were recorded.
- **Baseline Whisper QA of the shipped TPLA lines** (score only, no re-takes) was stopped
  part-way by the scope change.
  - Partial log: /tmp/qa_before.log on the box (militia → hailstorm).

**Until the asset worker lands licence-clean TPLA voices, the shipped TPLA lines still come from
lessac-derived prompts.** This is listed in KNOWN_ISSUES.
