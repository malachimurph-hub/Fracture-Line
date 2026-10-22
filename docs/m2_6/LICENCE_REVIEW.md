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

As instructed, the TPLA voices are regenerated without them.

## M2.6 replacement

- **Prompt speakers:** Kokoro-82M v1.0 male voice styles (Apache-2.0 weights, hexgrad/Kokoro-82M).
  - They are driven directly with the same Arabic-accent phoneme rules (tools/accent_tts.py
    `synth_kokoro`) and pitch-shifted per unit.
  - Kokoro is already used for the EU and US voices.
- **Engine:** Chatterbox Multilingual (MIT), unchanged.
- **Phonemization:** espeak-ng, used as a tool only. Nothing from it ships.
- No Piper voice model is used for any shipped line any more.

The M2.5 Piper prompt WAVs in /workspace/tools/tts/prompts_me stay on the dev box only and do
not ship.
