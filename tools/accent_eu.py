#!/usr/bin/env python3
"""M2.6 accent rules for Kokoro-82M (Apache-2.0) voices: English text -> espeak IPA (en-gb or
en-us, Kokoro's own phonemizer) -> phoneme rewrites the way speakers of another first language
typically realise English -> Kokoro renders the phonemes directly (is_phonemes=True).

No cloning, no real person imitated; the accents are generic phonological rules.
  kinds: de (German), fr (French), it (Italian), pl (Polish), nl (Dutch), sv (Swedish),
         es (Spanish), south (US Southern drawl), none.
strength 0..1 applies a growing subset of the rules (first rules = most characteristic), so a
QA re-take can step the accent down when Whisper cannot understand a line."""
import re

# (pattern, replacement, weight). A rule applies when its weight <= strength. Patterns are regexes
# over the espeak IPA string (stress marks ˈˌ kept). Word boundary helpers: (?<![^\s,.!?]) etc.
B = r"(?=[\s,.!?;:]|$)"          # end of word
S = r"(?:(?<=^)|(?<=[\s,.!?;:]))"  # start of word
RULES = {
    "de": [(r"w", "v", 0.1), (r"θ", "s", 0.2), (S + r"ð", "d", 0.3), (r"ð", "z", 0.35), (r"ɹ", "ʁ", 0.25),
           (r"b" + B, "p", 0.5), (r"d" + B, "t", 0.45), (r"ɡ" + B, "k", 0.5), (r"z" + B, "s", 0.4),
           (r"æ|a", "ɛ", 0.6), (r"ʌ", "a", 0.55), (r"əʊ|oʊ", "oː", 0.3), (r"eɪ", "eː", 0.4),
           (r"dʒ|ʤ", "tʃ", 0.7), (r"ɜː", "øː", 0.6), (r"ə" + B, "ɐ", 0.5)],
    "fr": [(S + r"h", "", 0.1), (r"θ", "s", 0.2), (r"ð", "z", 0.2), (r"ɹ", "ʁ", 0.15), (r"ɪ", "i", 0.3),
           (r"ʊ", "u", 0.4), (r"æ|a", "a", 0.3), (r"ʌ", "œ", 0.45), (r"əʊ|oʊ", "o", 0.35), (r"eɪ", "e", 0.4),
           (r"ŋ", "ŋɡ", 0.7), (r"ˈ", "", 0.8), (r"ɜː", "œʁ", 0.6)],
    "it": [(r"ɹ", "r", 0.1), (r"θ", "t", 0.2), (r"ð", "d", 0.2), (S + r"h", "", 0.35), (r"ɪ", "i", 0.3),
           (r"ʊ", "u", 0.35), (r"æ|a", "ɛ", 0.45), (r"ʌ", "a", 0.3), (r"ə(?!ʊ)", "a", 0.5),
           (r"əʊ|oʊ", "o", 0.3), (r"eɪ", "e", 0.35), (r"([kɡtdpbs])" + B, r"\1ə", 0.6), (r"ŋ", "nɡ", 0.65)],
    "pl": [(r"ɹ", "r", 0.1), (r"θ", "f", 0.25), (r"ð", "d", 0.2), (r"æ|a", "ɛ", 0.4), (r"ʌ", "a", 0.3),
           (r"ə(?!ʊ)", "ɛ", 0.55), (r"ɪ", "ɨ", 0.5), (r"d" + B, "t", 0.45), (r"z" + B, "s", 0.45), (r"v" + B, "f", 0.5),
           (r"ŋ", "nk", 0.65), (r"əʊ|oʊ", "ɔw", 0.35), (r"h", "χ", 0.7)],
    "nl": [(r"θ", "t", 0.2), (r"ð", "d", 0.2), (r"ɹ", "ʁ", 0.3), (r"w", "ʋ", 0.15), (r"d" + B, "t", 0.4),
           (r"z" + B, "s", 0.4), (r"ʌ", "ɑ", 0.5), (r"æ|a", "ɛ", 0.45), (r"ɡ", "χ", 0.75), (r"v", "f", 0.6)],
    "sv": [(r"dʒ|ʤ", "j", 0.2), (r"z", "s", 0.2), (r"θ", "t", 0.25), (r"ð", "d", 0.25), (r"ɹ", "r", 0.15),
           (r"w", "v", 0.6), (r"ʌ", "a", 0.4), (r"æ|a", "ɛ", 0.45), (r"əʊ|oʊ", "uː", 0.5), (r"eɪ", "eː", 0.4),
           (r"ʃ", "ɕ", 0.7)],
    "es": [(S + r"s([ptkmnl])", r"es\1", 0.15), (r"v", "β", 0.25), (r"z", "s", 0.2), (r"ɪ", "i", 0.2),
           (r"æ|a", "a", 0.3), (r"ʌ", "a", 0.3), (r"ə(?!ʊ)", "a", 0.55), (r"θ", "t", 0.3), (r"ð", "d", 0.3),
           (S + r"h", "χ", 0.5), (r"ɹ", "ɾ", 0.35), (r"dʒ|ʤ", "ʝ", 0.6), (r"əʊ|oʊ", "o", 0.4), (r"eɪ", "e", 0.4)],
    # US Southern: monophthong /aɪ/, "-in'" endings, drawled vowels (length), r stays rhotic
    "south": [(r"aɪ", "aː", 0.2), (r"ɪŋ" + B, "ɪn", 0.3), (r"ɛ", "eɪ", 0.7), (r"æ", "æː", 0.5)],
    "none": [],
}

# diphthongs are protected as single tokens so monophthong rules cannot split them
DIPH = [("aɪ", "Ⓐ"), ("aʊ", "Ⓦ"), ("eɪ", "Ⓔ"), ("əʊ", "Ⓞ"), ("oʊ", "Ⓞ"), ("ɔɪ", "Ⓨ"), ("dʒ", "Ⓙ"), ("ʤ", "Ⓙ"), ("tʃ", "Ⓒ"), ("ʧ", "Ⓒ")]
BACK = {"Ⓐ": "aɪ", "Ⓦ": "aʊ", "Ⓔ": "eɪ", "Ⓞ": "əʊ", "Ⓨ": "ɔɪ", "Ⓙ": "ʤ", "Ⓒ": "ʧ"}
ALIAS = {"aɪ": "Ⓐ", "aʊ": "Ⓦ", "eɪ": "Ⓔ", "əʊ|oʊ": "Ⓞ", "dʒ|ʤ": "Ⓙ"}

def apply(ipa: str, kind: str, strength: float = 1.0) -> str:
    s = ipa
    for a, b in DIPH:
        s = s.replace(a, b)
    for pat, rep, w in RULES.get(kind, []):
        if w <= strength:
            s = re.sub(ALIAS.get(pat, pat), rep, s)
    for a, b in BACK.items():
        s = s.replace(a, b)
    return s

def phonemes(kokoro, text: str, lang: str, kind: str, strength: float) -> str:
    ipa = kokoro.tokenizer.phonemize(text, lang)
    return apply(ipa, kind, strength)

if __name__ == "__main__":
    import sys
    from kokoro_onnx import Kokoro
    k = Kokoro("/workspace/tools/tts/kokoro-v1.0.onnx", "/workspace/tools/tts/voices-v1.0.bin")
    t = sys.argv[1] if len(sys.argv) > 1 else "Main gun, fire! Tracks rolling. Bring them down, we have the shield."
    for kd in RULES:
        print(kd, apply(k.tokenizer.phonemize(t, "en-gb"), kd))
