#!/usr/bin/env python3
"""Middle Eastern-accented English with Piper voices trained on Arabic / Persian speech.

How it works (no voice cloning, no real person imitated):
  1. espeak-ng turns the English line into US-English IPA phonemes (what a native speaker says);
  2. accent rules rewrite those phonemes the way Arabic or Persian speakers of English typically
     realise them (only into phonemes the Arabic / Persian voice model was trained on): tapped /
     trilled r and no r-colouring, full vowels instead of schwa, no /ae/-/a/ or tense/lax contrast,
     Persian w -> v and s-cluster epenthesis ("estop"), Arabic p -> b, v -> f, ng -> n+g ...;
  3. a Piper (VITS) voice from rhasspy/piper-voices trained on Arabic or Persian speech renders
     those phonemes with its native voice quality, rhythm and intonation.
Models: Piper voices, ONNX (piper-tts, GPL-3.0 runtime used as a tool only; nothing ships in the
game). Datasets: see tools/../CREDITS. The output is ordinary audio files."""
import os, re
import numpy as np

PIPER_DIR = os.environ.get("FL_PIPER_DIR", "/workspace/tools/tts/piper")
_voices = {}
_ph = None

VOWELS = set("aeiouɑɔəɚɛɪʊʌæ")

def phonemize_en(text):
    global _ph
    from piper.phonemize_espeak import EspeakPhonemizer, ESPEAK_DATA_DIR
    if _ph is None:
        _ph = EspeakPhonemizer(ESPEAK_DATA_DIR)
    return _ph.phonemize("en-us", text)

def _tok(sent):
    """espeak char list -> phone tokens (merge diphthongs / affricates)"""
    s = "".join(sent)
    for k, v in [("aɪ", "AI"), ("aʊ", "AU"), ("eɪ", "EI"), ("oʊ", "OU"), ("ɔɪ", "OI"), ("tʃ", "C"), ("dʒ", "J"), ("ɑːɹ", "AR"), ("ɔːɹ", "OR"), ("ɛɹ", "ER"), ("ɪɹ", "IR"), ("ʊɹ", "UR")]:
        s = s.replace(k, v)
    return s

PERSIAN = [("AI", "ɑj"), ("AU", "ɑw"), ("EI", "ej"), ("OU", "o"), ("OI", "oj"), ("C", "tʃ"), ("J", "dʒ"),
           ("AR", "ɑːr"), ("OR", "oːr"), ("ER", "er"), ("IR", "ir"), ("UR", "ur"),
           ("ɚ", "er"), ("ə", "e"), ("ɪ", "i"), ("ʊ", "u"), ("ʌ", "a"), ("æ", "a"), ("ɛ", "e"), ("ɔ", "o"),
           ("ɹ", "r"), ("ɾ", "t"), ("ŋ", "nɡ"), ("θ", "t"), ("ð", "d"), ("w", "v"), ("ʲ", ""), ("ɐ", "a"), ("ᵻ", "e"), ("ɑ", "ɑ")]
ARABIC = [("AI", "aj"), ("AU", "aw"), ("EI", "eː"), ("OU", "oː"), ("OI", "oj"), ("C", "tʃ"), ("J", "dʒ"),
          ("AR", "aːr"), ("OR", "oːr"), ("ER", "eːr"), ("IR", "iːr"), ("UR", "uːr"),
          ("ɚ", "ar"), ("ə", "a"), ("ɪ", "i"), ("ʊ", "u"), ("ʌ", "a"), ("æ", "a"), ("ɛ", "e"), ("ɔ", "o"), ("ɑ", "a"),
          ("ɹ", "r"), ("ɾ", "t"), ("ŋ", "nɡ"), ("p", "b"), ("v", "f"), ("ʲ", ""), ("ɐ", "a"), ("ᵻ", "i"), ("ʒ", "ʃ")]

ARABIC2 = [(a, {"e": "i", "eː": "iː", "o": "u", "oː": "uː"}.get(b, b)) for a, b in ARABIC] + [("ɛ", "i"), ("ɔ", "u")]

def accent(sent, kind):
    s = _tok(sent)
    if kind == "fa2":
        for a, b in PERSIAN:
            if a != "w":
                s = s.replace(a, b)
        return list(s)
    if kind == "ar2":
        for a, b in ARABIC2:
            s = s.replace(a, b)
        return list(s.replace("e", "i").replace("o", "u"))
    if kind == "me":
        # M2.5 v2 Arabic-flavoured English for Chatterbox prompts (Malachi: v1 sounded "slightly
        # Russian"): Arabic vowel/consonant rules (p->b, v->f, full vowels, w kept), a single tapped
        # r instead of a trill, and emphatic (pharyngealised) t/d/s before back vowels.
        for a, b in ARABIC:
            s = s.replace(a, b)
        s = s.replace("r", "ɾ")
        s = re.sub(r"([tds])(ˈ|ˌ)?([ɑaou])", lambda m: m.group(1) + "ˤ" + (m.group(2) or "") + m.group(3), s)
        return list(s)
    if kind == "fa":
        # s + consonant at the start of a word: Persian speakers add a short e ("estop", "esquad")
        s = re.sub(r"(^|\s)(ˈ?)s([ptkmnlw])", lambda m: m.group(1) + "e" + m.group(2) + "s" + m.group(3), s)
    for a, b in (PERSIAN if kind == "fa" else ARABIC if kind == "ar" else []):
        s = s.replace(a, b)
    return list(s)

def voice(name):
    if name not in _voices:
        from piper import PiperVoice
        _voices[name] = PiperVoice.load(os.path.join(PIPER_DIR, name + ".onnx"))
    return _voices[name]

def synth(text, model, kind, speed=1.0, noise=0.6, noise_w=0.75, raw=False):
    """-> (float32 samples, sample rate). kind: 'fa' | 'ar' | 'none' (unmodified US phonemes)."""
    from piper.config import SynthesisConfig
    v = voice(model)
    cfg = SynthesisConfig(length_scale=1.0 / speed, noise_scale=noise, noise_w_scale=noise_w)
    out = []
    sil = np.zeros(int(v.config.sample_rate * 0.12), dtype=np.float32)
    for sent in phonemize_en(text):
        ph = sent if kind == "none" else accent(sent, kind)
        ids = v.phonemes_to_ids(ph)
        a = v.phoneme_ids_to_audio(ids, cfg)
        out += [np.asarray(a, dtype=np.float32), sil]
    a = np.concatenate(out[:-1]) if out else np.zeros(1, np.float32)
    a = a / max(1e-4, float(np.max(np.abs(a)))) * 0.9
    return a, v.config.sample_rate
