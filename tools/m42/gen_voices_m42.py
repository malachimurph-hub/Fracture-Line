#!/usr/bin/env python3
"""M4.2 (items 2 + 13): male acknowledgement lines for the three transport helicopters and the
announcer lines for the narrated first battle.

  FL_THREADS=4 /workspace/tools/tts/venv_cb/bin/python tools/m42/gen_voices_m42.py [--only blackhawk,...]

Method (all original, nothing cloned from a real person):
  1. reference = an existing cached dry Kokoro-82M (Apache-2.0) / Piper take already used for this project,
     pitch + formant shifted with rubberband so it becomes a NEW speaker (helicopter pilots are male);
  2. Chatterbox Multilingual (MIT) speaks the line from that reference with the faction language token
     (US en, Germany de accent, Russia ru accent; the announcer keeps the US announcer reference);
  3. faction radio chain + loudness (gen_voices_intensity_m27.process);
  4. Whisper QA (faster-whisper small); best of up to 3 takes, stop at word match >= 0.8.
Writes res://audio/voice_ai/<fac>/<folder>/<event>_<n>.ogg, announcer_us/tut_*.ogg, tools/m42/voice_qa_m42.json."""
import os, sys, json, hashlib, tempfile, subprocess
import numpy as np, soundfile as sf
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import import_voice as iv
import gen_voices_m26 as g
import gen_voices_intensity_m27 as gi
import voice_cast_m26 as vc

ROOT = iv.ROOT
WORK = "/workspace/vw/m42"
REP = os.path.join(ROOT, "tools", "m42", "voice_qa_m42.json")
P = "/workspace/vw/int/prompts/"
JOBS = {
 "blackhawk": dict(rel="us/blackhawk", ref=P + "us_harrier_0.wav", st=-2.0, lang="en", fx="helmet", lines={
   "select": ["Transport bird, standing by.", "Rotors turning. Where to?"], "move": ["Moving out.", "Copy that."],
   "attack": ["Door guns, open fire!"], "under_fire": ["Taking fire! Hold on!"],
   "created": ["Transport helicopter, ready for tasking."], "garrison": ["Troops aboard. Lifting off."]}),
 "h145m": dict(rel="eu/h145m", ref="/workspace/vw/m33de/prompts/field_engineer.wav", st=1.5, lang="de", fx="helmet", lines={
   "select": ["Helicopter ready.", "Light transport, go ahead."], "move": ["On our way.", "Understood, flying there."],
   "attack": ["Engaging target!"], "under_fire": ["We are hit! Evading!"],
   "created": ["Helicopter ready for the mission."], "garrison": ["Team aboard. Taking off."]}),
 "hind": dict(rel="ecc/hind", ref="/workspace/tools/tts/prompts_me/reza_-2.0.wav", st=-1.0, lang="ru", fx="", lines={
   "select": ["Assault helicopter ready.", "Crew ready, comrade."], "move": ["Flying there.", "Moving low."],
   "attack": ["Rockets away!"], "under_fire": ["We are hit! Armour holding!"],
   "created": ["Flying tank ready."], "garrison": ["Soldiers aboard. Lifting off."]}),
 "tutorial": dict(rel="announcer_us", ref=P + "us_announcer_m2_0.wav", st=0.0, lang="en", fx="", ann=True, lines={
   "tut_welcome": ["Welcome, Commander. This is your first battle. Follow my lead."],
   "tut_select": ["Tap your bulldozer to select it."],
   "tut_power": ["Open the build menu and place a power plant."],
   "tut_barracks": ["Good. Now build a barracks to train infantry."],
   "tut_train": ["Select the barracks and train two squads."],
   "tut_move": ["Select your soldiers, then tap the ground to move them."],
   "tut_attack": ["The enemy base is to the east. Destroy it to win."],
   "tut_done": ["Well done, Commander. You are ready for skirmish."]}),
}
CALM = {"select", "move", "created", "garrison"}

def reference(name, job):
    os.makedirs(os.path.join(WORK, "prompts"), exist_ok=True)
    p = os.path.join(WORK, "prompts", name + ".wav")
    if not os.path.exists(p):
        if abs(job["st"]) < 0.05:
            subprocess.run(["cp", job["ref"], p], check=True)
        else:
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", job["ref"], "-af",
                            f"rubberband=pitch={2 ** (job['st'] / 12):.5f}:formant=shifted:pitchq=quality", p], check=True)
    return p

def main(argv):
    only = argv[argv.index("--only") + 1].split(",") if "--only" in argv else list(JOBS)
    import torch
    m = gi.cb(); _, wm = g.models()
    rep = {r["file"]: r for r in (json.load(open(REP)) if os.path.exists(REP) else [])}
    for name in only:
        job = JOBS[name]
        ref = reference(name, job)
        ann = job.get("ann", False)
        for ev, texts in job["lines"].items():
            for n, text in enumerate(texts, 1):
                dst = os.path.join(ROOT, "audio", "voice_ai", job["rel"], f"{ev}_{n}.ogg")
                if os.path.relpath(dst, ROOT) in rep and os.path.exists(dst):
                    continue
                calm = ann or ev in CALM
                ex, cfg = (0.5, 0.5) if calm else (0.9, 0.3)
                h = int(hashlib.md5(f"{name}{ev}{n}".encode()).hexdigest()[:6], 16)
                best = (-9, None, "")
                with tempfile.TemporaryDirectory() as td:
                    for i, (e, c, seed) in enumerate([(ex, cfg, h), (ex, cfg, h + 1), (max(0.4, ex - 0.2), cfg + 0.1, h + 2)]):
                        m.prepare_conditionals(ref, exaggeration=e)
                        torch.manual_seed(seed)
                        w = m.generate(text, language_id=job["lang"], exaggeration=e, cfg_weight=c, temperature=0.75).squeeze(0).numpy().astype(np.float32)
                        sr = m.sr
                        s0, s1 = gi.speech_span(w, sr)
                        w = w[max(0, s0 - int(sr * 0.03)): s1 + int(sr * 0.06)]
                        pad = np.zeros(int(sr * 0.08), np.float32)
                        w0 = os.path.join(td, f"{i}.wav"); sf.write(w0, np.concatenate([pad, w, pad]), sr)
                        cand = os.path.join(td, f"{i}.ogg")
                        fx = vc.FX.get(job["fx"], "") if job["fx"] else ""
                        pre = fx if calm else ",".join(x for x in (fx, gi.COMBAT_FX) if x)
                        gi.process(w0, cand, not ann, iv.style_for(job["rel"]), pre, "" if calm else gi.RADIO_CLIP, -16.0 if calm else -13.0)
                        sc, heard = g.score(wm, cand, text)
                        if len(g.words(heard)) > len(g.words(text)):
                            sc -= 0.15 * (len(g.words(heard)) - len(g.words(text)))
                        if sc > best[0]:
                            keep = os.path.join(WORK, "keep", f"{name}_{ev}_{n}.ogg")
                            os.makedirs(os.path.dirname(keep), exist_ok=True)
                            subprocess.run(["cp", cand, keep], check=True)
                            best = (sc, keep, heard)
                        if sc >= 0.8:
                            break
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                subprocess.run(["cp", best[1], dst], check=True)
                r = {"file": os.path.relpath(dst, ROOT), "text": text, "heard": best[2], "score": round(best[0], 2),
                     "engine": "chatterbox-multilingual (MIT) lang=%s; reference = project Kokoro-82M (Apache-2.0)/Piper take shifted %+.1f st" % (job["lang"], job["st"])}
                rep[r["file"]] = r
                json.dump(sorted(rep.values(), key=lambda x: x["file"]), open(REP, "w"), indent=1)
                print(f"{r['file']}: {best[0]:.2f} {text!r} -> {best[2]!r}", flush=True)
    print("=== M42 VOICES DONE", len(rep), flush=True)

if __name__ == "__main__":
    main(sys.argv[1:])
