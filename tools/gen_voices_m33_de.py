#!/usr/bin/env python3
"""M3.3 Phase 4 (item 38): natural German-accented male lines for the German faction.

  /workspace/tools/tts/venv_cb/bin/python tools/gen_voices_m33_de.py [--only crawler,field_engineer,sturmtrupp]

Malachi: the German "unit reporting" line sounds robotic. It was the Pioneer (eu_crawler) created line
"Engineering unit reporting." (Kokoro + phoneme accent rules + a 2-semitone shift), and the two newer
German units (Field Engineer, Sturmtrupp) still fell back to the robotic placeholder "Unit reporting."
for every event. Method per line (all male, all original, nothing cloned from a real person):
  1. voice reference = a dry Kokoro-82M (Apache-2.0) take of the character with the M2.6 German accent
     rules (tools/voice_cast_m26.py), cached in /workspace/vw/m33de/prompts;
  2. Chatterbox Multilingual (MIT) re-voices the line from that reference with the German language token
     and calm settings (natural prosody, relaxed timing, no shouting except attack / under fire);
  3. the faction radio chain + loudness (tools/import_voice.py via the M2.7 process());
  4. Whisper QA (faster-whisper small): word match >= 0.8, else retake with another seed / settings.
Writes res://audio/voice_ai/eu/<folder>/<event>_<n>.ogg and tools/voice_qa_m33_de.json."""
import os, sys, json, hashlib, tempfile, subprocess
import numpy as np, soundfile as sf
sys.path.insert(0, os.path.dirname(__file__))
import voice_cast_m26 as vc
import import_voice as iv
import gen_voices_m26 as g
import gen_voices_intensity_m27 as gi

ROOT = iv.ROOT
OUT = os.path.join(ROOT, "audio", "voice_ai", "eu")
WORK = "/workspace/vw/m33de"
REP = os.path.join(ROOT, "tools", "voice_qa_m33_de.json")

CREW = {
    "crawler": dict(actor=vc.CAST["eu"]["units"]["eu_crawler"][0],
                    lines={"created": ["Engineering unit, reporting in.", "Pioneers here. What are we building?"]}),
    "field_engineer": dict(actor=dict(v="bm_daniel:0.5,am_michael:0.5", acc="de", s=0.55, st=-0.8, fmt="shift", spd=0.95, fx="grit", rough=0.06),
                    lines={"select": ["Field engineer.", "Tools are ready."], "move": ["On my way.", "Moving up."],
                           "attack": ["Engaging!", "Covering fire!"], "under_fire": ["We're taking fire!", "Get down!"],
                           "created": ["Field engineer, reporting.", "Engineer ready for work."], "build": ["I'll get it done.", "Starting work."],
                           "veteran": ["Promoted. Still fixing things."], "garrison": ["Inside. Securing the building."]}),
    "sturmtrupp": dict(actor=dict(v="am_fenrir:0.6,bm_george:0.4", acc="de", s=0.6, st=-1.2, fmt="shift", spd=1.0, fx="shout", rough=0.1),
                    lines={"select": ["Assault squad, standing by.", "Ready."], "move": ["Moving out.", "Forward, go!"],
                           "attack": ["Storm them!", "Go, go, go!"], "under_fire": ["Contact! Taking fire!", "Into cover!"],
                           "created": ["Assault team, reporting.", "Sturmtrupp ready."], "veteran": ["We know the drill now."],
                           "garrison": ["In the building. Holding."]}),
}
CALM = {"select", "move", "created", "build", "veteran", "garrison"}

def reference(folder, actor):
    os.makedirs(os.path.join(WORK, "prompts"), exist_ok=True)
    p = os.path.join(WORK, "prompts", folder + ".wav")
    if os.path.exists(p):
        return p
    k, _ = g.models()
    lines = CREW[folder]["lines"]
    text = " ".join(t for ev in ("select", "created", "move", "build") for t in lines.get(ev, [])) or "Engineering unit. Ready to build. On my way."
    if folder == "crawler":
        text = "Pioneers ready. Where do you want it? On my way. Building now. We'll have it up in no time."
    ph = g.phon(k, text, "eu", actor["acc"], actor["s"], vc.CAST["eu"]["lang"])
    a, sr = k.create(ph, voice=g.style(k, actor["v"]), speed=float(actor["spd"]), is_phonemes=True)
    a = np.asarray(a, np.float32)
    with tempfile.TemporaryDirectory() as td:
        w0 = os.path.join(td, "a.wav"); sf.write(w0, a, sr)
        fm = "shifted" if actor.get("fmt") == "shift" else "preserved"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", w0, "-af",
                        f"rubberband=pitch={2 ** (actor['st'] / 12):.5f}:formant={fm}:pitchq=quality", p], check=True)
    return p

def main(argv):
    only = argv[argv.index("--only") + 1].split(",") if "--only" in argv else list(CREW)
    # --lines folder/event_n,... : retake just those lines with fresh seeds (5 tries, extra words penalised)
    lines = argv[argv.index("--lines") + 1].split(",") if "--lines" in argv else None
    if lines:
        only = sorted({x.split("/")[0] for x in lines})
    import torch
    m = gi.cb(); _, wm = g.models()
    rep = []
    for folder in only:
        actor = CREW[folder]["actor"]
        ref = reference(folder, actor)
        for ev, texts in CREW[folder]["lines"].items():
            for n, text in enumerate(texts, 1):
                if lines and f"{folder}/{ev}_{n}" not in lines:
                    continue
                calm = ev in CALM
                ex, cfg = (0.5, 0.5) if calm else (0.95, 0.3)
                h = int(hashlib.md5(f"{folder}{ev}{n}".encode()).hexdigest()[:6], 16)
                best = (-9, None, "")
                with tempfile.TemporaryDirectory() as td:
                    tries = [(ex, cfg, h), (ex, cfg, h + 1), (max(0.4, ex - 0.2), cfg + 0.1, h + 2)]
                    if lines:
                        tries = [(ex, cfg, h + 10 + k) for k in range(3)] + [(max(0.4, ex - 0.2), cfg + 0.1, h + 20 + k) for k in range(2)]
                    for i, (e, c, seed) in enumerate(tries):
                        m.prepare_conditionals(ref, exaggeration=e)
                        torch.manual_seed(seed)
                        w = m.generate(text, language_id="de", exaggeration=e, cfg_weight=c, temperature=0.75).squeeze(0).numpy().astype(np.float32)
                        sr = m.sr
                        s0, s1 = gi.speech_span(w, sr)
                        w = w[max(0, s0 - int(sr * 0.03)): s1 + int(sr * 0.06)]
                        pad = np.zeros(int(sr * 0.08), np.float32)
                        w0 = os.path.join(td, f"{i}.wav"); sf.write(w0, np.concatenate([pad, w, pad]), sr)
                        cand = os.path.join(td, f"{i}.ogg")
                        pre = vc.FX.get(actor.get("fx", "clean"), "") if calm else ",".join(x for x in (vc.FX.get(actor.get("fx", "clean"), ""), gi.COMBAT_FX) if x)
                        dur = gi.process(w0, cand, True, iv.style_for("eu/" + folder), pre, "" if calm else gi.RADIO_CLIP, -16.0 if calm else -13.0)
                        sc, heard = g.score(wm, cand, text)
                        nw = len(g.words(text))
                        if dur > 1.0 + 0.5 * nw:
                            sc -= 0.3
                        if len(g.words(heard)) > nw:   # extra / invented words
                            sc -= 0.15 * (len(g.words(heard)) - nw)
                        if sc > best[0]:
                            best = (sc, cand, heard)
                            os.makedirs(os.path.join(WORK, "keep"), exist_ok=True)
                            subprocess.run(["cp", cand, os.path.join(WORK, "keep", f"{folder}_{ev}_{n}.ogg")], check=True)
                        if sc >= 0.8:
                            break
                dst = os.path.join(OUT, folder, f"{ev}_{n}.ogg")
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                subprocess.run(["cp", os.path.join(WORK, "keep", f"{folder}_{ev}_{n}.ogg"), dst], check=True)
                rep.append({"file": os.path.relpath(dst, ROOT), "text": text, "heard": best[2], "score": round(best[0], 2),
                            "engine": "chatterbox-multilingual (MIT), lang=de, ref = Kokoro-82M (Apache-2.0) German-accent take"})
                print(f"{folder}/{ev}_{n}: {best[0]:.2f}  {text!r} -> {best[2]!r}", flush=True)
    old = json.load(open(REP)) if os.path.exists(REP) else []
    keep = {r["file"]: r for r in old}
    for r in rep:
        keep[r["file"]] = r
    json.dump(list(keep.values()), open(REP, "w"), indent=1)

if __name__ == "__main__":
    main(sys.argv[1:])
