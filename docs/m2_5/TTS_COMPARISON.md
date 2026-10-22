# TPLA voices: free local TTS comparison (M2.5)

Brief: TPLA unit sets and announcer in **English with Middle Eastern (Arabic / Persian) accents**,
orders clearly understandable, a few short in-language shouts allowed, distinct voice per unit,
offline, prefer permissive licences. No real person's voice may be cloned.

Method: same 5 test orders rendered by every candidate; scored offline with faster-whisper
(Whisper small, MIT): **words_ok** = forced-English transcript match (is the order understandable?),
**accent** = 1 − P(language = English) from Whisper's language ID (how non-native it sounds),
plus listening on a phone speaker through the in-game radio filter.

| Candidate | Licence (weights) | Commercial OK? | Accent | Intelligibility | Naturalness | Verdict |
|---|---|---|---|---|---|---|
| **Chatterbox Multilingual** (Resemble AI), lang "ar", prompted by synthetic accented speakers | **MIT** (Perth watermark in output) | **yes** | strong, natural Arabic/Persian-flavoured English | good after QA re-takes (see below) | **most natural / human of all tested**, real emotion control | **CHOSEN** |
| Kokoro-82M voice blends (en voices + hi/other) | Apache-2.0 | yes | weak; reads as neutral US/UK with odd vowels | very good | good | rejected: accent not convincing |
| Piper fa_IR / ar_JO voices reading English (cross-lingual phonemes, `tools/accent_tts.py`) | voices: CC0 datasets (some fine-tuned from "lessac"); piper-tts GPL-3.0 tool | yes (audio) | strong | poor–fair: words_ok 0.14–0.75 (e.g. "seduct a tank in Holiday State") | robotic, flat | rejected as final voice; **used to create Chatterbox prompts** |
| Meta MMS-TTS (eng / ara / fas) | **CC-BY-NC 4.0** | **no (non-commercial)** | — | — | flat | rejected (licence) |
| Coqui XTTS-v2 | **Coqui Public Model License** | **no (non-commercial)** | good with an accented reference | good | good | rejected (licence; also needs a real-voice reference) |
| F5-TTS | code MIT, **weights CC-BY-NC** | **no** | good with reference | good | good | rejected (licence) |

Why Chatterbox: the only permissively licensed model that produced convincingly accented,
emotional, human-sounding English. Using the language token "ar" pulls pronunciation toward an
Arabic accent; the voice prompts are *synthetic* (Piper Persian voices speaking English through
accent phoneme rules, then pitch/formant-shifted), so no real person is cloned. Each TPLA unit has
its own prompt/shift/emotion setting (VOICE_CAST in `tools/voice_manifest_src.py`), the same TPLA
walkie-talkie filter, and −16 LUFS loudness matching.

Shouts used: "Yalla!" (come on / let's go), "Khalas" (enough / done), "Boro!" (Persian: go!).
Everything else is plain English.

Pipeline: `tools/gen_ai_voices_me.py` (render) → `tools/voice_qa_me.py` (Whisper check,
re-render any line under 0.7 word match with new seeds, keep the best take) → `tools/import_voice.py`
(trim, radio, loudness). Samples: `builds/m2_5/voice_samples/*.mp3`.
