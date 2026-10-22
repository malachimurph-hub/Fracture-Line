#!/usr/bin/env python3
"""M2.7 combat intensity pass: unit attack / under_fire lines and the announcers' alarm lines
(base / units under attack, enemy strike, tunnel lost) re-voiced urgent, shouted and faster.

  /workspace/tools/tts/venv_cb/bin/python tools/gen_voices_intensity_m27.py [--only eu|us|tpla] [--unit <uid>]
        [--event attack,...] [--jobs 2] [--force] [--retake] [--out <dir>]

Malachi (M2.6 feedback): "add intensity to some voice lines, especially the ones about being
attacked or being in combat" - the Kokoro lines read calm and Kokoro cannot shout. Method per line:
  1. voice reference = the unit's own M2.6 voice, rendered dry (no radio / FX) by Kokoro-82M from the
     unit's calm select + created lines with its cast blend, accent rules, pitch and gravel
     (tools/voice_cast_m26.py). TPLA Militia (Malachi's favourite) uses its original M2.5 Chatterbox
     prompt; EU / US announcers their original Kokoro voice (female allowed for announcers only).
  2. Chatterbox Multilingual (MIT) clones that reference with high exaggeration and low cfg_weight
     (shouted, strained, faster). The language token carries the accent: EU = the unit's first
     language (de / fr / it / pl / nl / sv / es), US = en, TPLA = ar (Arabic token; never ru).
  3. tempo up to a combat speech rate (rubberband, pitch kept), gravel, the unit's FX profile, a
     combat chain (fast compression + mild tanh saturation), the faction radio plus radio clipping
     for radio units, and a hotter loudness target than the calm lines (+3 / +4 LU).
  4. Whisper QA (faster-whisper small) word match >= 0.8 and a length / babble check; failures are
     re-taken (other seed, then less exaggeration / more cfg), best take kept.
Calm events (select, move, created, build...) are untouched. Report: tools/voice_qa_intensity_m27.json."""
import os, sys, re, json, hashlib, subprocess, tempfile
import numpy as np, soundfile as sf
sys.path.insert(0, os.path.dirname(__file__))
import voice_manifest_src as vm
import voice_cast_m26 as vc
import import_voice as iv
import gen_voices_m26 as g

ROOT = iv.ROOT
OUT = os.path.join(ROOT, "audio", "voice_ai")
REP = os.path.join(ROOT, "tools", "voice_qa_intensity_m27.json")
PROMPTS = "/workspace/vw/int/prompts"
DRY = "/workspace/vw/int/dry"
THR = 0.8
UNIT_EV = ("attack", "under_fire")
ANN_EV = ("base_under_attack", "units_under_attack", "enemy_power_detected", "tunnel_lost")
CALM_EV = ("select", "created")
ACC_LANG = {"de": "de", "fr": "fr", "it": "it", "pl": "pl", "nl": "nl", "sv": "sv", "es": "es"}
# characters whose personality is calm / quiet: still urgent under fire, but less of a scream
CALM_PEOPLE = {"us_sniper", "us_jtac", "eu_aegis", "tpla_mule", "tpla_blight", "us_thunderlance", "eu_lancer"}
# (exaggeration, cfg_weight, target words/s, loudness offset LU, extra gravel)
INTENSITY = {"attack": (1.0, 0.3, 3.0, 3.0, 0.04), "under_fire": (1.2, 0.25, 3.4, 4.0, 0.06),
             "ann": (1.0, 0.3, 2.9, 3.0, 0.0)}
COMBAT_FX = "acompressor=threshold=-26dB:ratio=4:attack=2:release=70:makeup=4,asoftclip=type=tanh:threshold=0.7"
RADIO_CLIP = "volume=3dB,asoftclip=type=atan:threshold=0.75"
_m = None
_cond = {}

def cb():
    global _m
    if _m is None:
        import torch
        torch.set_num_threads(int(os.environ.get("FL_THREADS", "4")))
        from chatterbox.mtl_tts import ChatterboxMultilingualTTS
        _m = ChatterboxMultilingualTTS.from_pretrained("cpu")
    return _m

def calm_text(fac, uid):
    fd = vm.FACTIONS[fac]
    if uid == "announcer":
        say = fd["announcer"]
        t = [say[e]["say"][i] for e in ("battle_start", "unit_ready", "construction_complete", "building_captured") for i in range(2)]
    else:
        say = fd["units"][uid]["say"]
        t = say.get("select", []) + say.get("created", []) + say.get("move", [])[:2]
    return " ".join(x if x[-1] in ".!?" else x + "." for x in t)

def prompt(fac, uid, actor, key):
    """Dry voice reference for the unit (cached)."""
    os.makedirs(PROMPTS, exist_ok=True)
    p = os.path.join(PROMPTS, f"{key}.wav")
    if os.path.exists(p):
        return p
    k, _ = g.models()
    text = calm_text(fac, uid)
    if "st" not in actor:              # EU / US announcer: original M2 Kokoro voice
        a, sr = k.create(text, voice=g.style(k, actor["v"]), speed=actor["speed"], lang=vm.VOICE_CAST[fac]["lang"])
        sf.write(p, np.asarray(a, np.float32), sr)
        return p
    s = 1 if fac == "tpla" else actor["s"]
    ph = g.phon(k, text, fac, actor["acc"], s, vc.CAST[fac]["lang"])
    a, sr = k.create(ph, voice=g.style(k, actor["v"]), speed=float(actor["spd"]), is_phonemes=True)
    a = g.roughen(np.asarray(a, np.float32), sr, actor.get("rough", 0), 7)
    with tempfile.TemporaryDirectory() as td:
        w0 = os.path.join(td, "a.wav"); sf.write(w0, a, sr)
        if abs(actor["st"]) > 0.05:
            fm = "shifted" if actor.get("fmt") == "shift" else "preserved"
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", w0, "-af",
                            f"rubberband=pitch={2 ** (actor['st'] / 12):.5f}:formant={fm}:pitchq=quality", p], check=True)
        else:
            sf.write(p, a, sr)
    return p

def speech_span(a, sr):
    env = np.convolve(np.abs(a), np.ones(int(sr * 0.02)) / int(sr * 0.02), "same")
    on = np.where(env > env.max() * 0.06)[0]
    return (on[0], on[-1]) if len(on) else (0, len(a))

def process(src, dst, radio, style, pre, post, lufs):
    """tools/import_voice.process + a post-radio stage (radio clipping)."""
    with tempfile.TemporaryDirectory() as td:
        a = os.path.join(td, "a.wav")
        chain = iv.TRIM + ("," + pre if pre else "")
        if radio:
            chain += "," + iv.RADIO_STYLES.get(style, iv.RADIO)
        elif style.startswith("ann_"):
            chain += "," + iv.RADIO_STYLES[style]
        if post:
            chain += "," + post
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-ac", "1", "-ar", "48000", "-af", chain, a], check=True)
        m = iv.loud(a)
        dur = sf.info(a).duration
        if dur >= 0.5 and float(m["input_i"]) > -60:
            norm = (f"loudnorm=I={lufs}:TP=-1.0:LRA=9:measured_I={m['input_i']}:measured_TP={m['input_tp']}:"
                    f"measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}:offset={m['target_offset']}:linear=true")
        else:
            r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", a, "-af", "volumedetect", "-f", "null", "-"], capture_output=True, text=True)
            mean = float(re.search(r"mean_volume: (-?[\d.]+)", r.stderr).group(1))
            norm = f"volume={lufs - 3.0 - mean:.2f}dB"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", a, "-af", norm + ",alimiter=limit=0.89:attack=1:release=40,aresample=24000",
                        "-ac", "1", "-c:a", "libvorbis", "-q:a", "4", dst], check=True)
    return dur

def render(job):
    fac, uid, rel, ev, n, text, stem, dst, actor, akey, radio, rstyle = job
    import torch
    m = cb(); _, wm = g.models()
    h = int(hashlib.md5(stem.encode()).hexdigest()[:6], 16)
    ann = uid == "announcer"
    ex, cfg, wps_t, dl, erough = INTENSITY["ann" if ann else ev]
    if uid in CALM_PEOPLE:
        ex, cfg, wps_t, dl = ex - 0.15, cfg + 0.05, wps_t - 0.3, dl - 1.0
    militia = uid == "tpla_militia"
    if militia:
        import gen_ai_voices_me as gm
        ref = gm.prompt_for(actor)
        lang, fx, rough, base_lufs = "ar", "", 0.0, -16.0
    else:
        ref = prompt(fac, uid, actor, akey)
        lang = "ar" if fac == "tpla" else ACC_LANG.get(actor.get("acc"), "en") if fac == "eu" else "en"
        fx = vc.FX.get(actor.get("fx", "clean"), "") if not ann else ""
        rough = actor.get("rough", 0.0) if not ann else 0.0
        base_lufs = actor.get("lufs", -16.0)
    lufs = min(-12.0, base_lufs + dl)
    nw = len(g.words(text))
    # retake ladder: (exaggeration, cfg, language, seed)
    alt = "en" if fac != "tpla" else "ar"
    ladder = [(ex, cfg, lang, h), (ex, cfg, lang, h + 1), (ex - 0.2, cfg + 0.1, alt, h + 2), (max(0.6, ex - 0.4), 0.5, alt, h + 3)]
    best = (-9, None, "", None, {})
    with tempfile.TemporaryDirectory() as td:
        for i, (e, c, lg, seed) in enumerate(ladder):
            ck = (ref, round(e, 2))
            if _cond.get("k") != ck:
                m.prepare_conditionals(ref, exaggeration=e); _cond["k"] = ck
            torch.manual_seed(seed)
            w = m.generate(text, language_id=lg, exaggeration=e, cfg_weight=c, temperature=0.8).squeeze(0).numpy().astype(np.float32)
            sr = m.sr
            s0, s1 = speech_span(w, sr)
            w = w[max(0, s0 - int(sr * 0.03)): s1 + int(sr * 0.05)]
            spd = (s1 - s0) / sr
            wps = nw / max(0.3, spd)
            tempo = float(np.clip(wps_t / wps, 1.0, 1.18)) if nw > 2 else float(np.clip(wps_t / wps, 1.0, 1.08))
            dry = os.path.join(DRY, rel, f"{ev}_{n}_t{i}.wav")
            os.makedirs(os.path.dirname(dry), exist_ok=True); sf.write(dry, w, sr)     # pre-FX take, for the pitch check
            w = g.roughen(w, sr, rough + erough, seed) if not ann else w
            pad = np.zeros(int(sr * 0.08), np.float32)
            w0 = os.path.join(td, f"{i}.wav"); sf.write(w0, np.concatenate([pad, w, pad]), sr)
            src = w0
            if tempo > 1.01:
                src = os.path.join(td, f"{i}_t.wav")
                subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", w0, "-af", f"rubberband=tempo={tempo:.3f}:pitchq=quality", src], check=True)
            pre = ",".join(x for x in (fx, COMBAT_FX) if x)
            cand = os.path.join(td, f"{i}.ogg")
            dur = process(src, cand, radio, rstyle, pre, RADIO_CLIP if radio else "", lufs)
            sc, heard = g.score(wm, cand, text)
            extra = len(g.words(heard)) - nw
            bad_len = dur > 0.9 + 0.45 * nw or extra >= 2          # babble / long tail
            eff = sc - (0.3 if bad_len else 0.2 if extra >= 1 else 0)
            lid = None
            if fac == "tpla":     # accent drift guard: Whisper language-ID must not lean Russian
                x = subprocess.run(["ffmpeg", "-v", "quiet", "-i", cand, "-f", "f32le", "-ac", "1", "-ar", "16000", "-"], capture_output=True).stdout
                x = np.frombuffer(x, np.float32); z = np.zeros(8000, np.float32)
                d = dict(wm.detect_language(np.concatenate([z, x, z]))[2])
                lid = {"en": round(d.get("en", 0), 3), "ar_fa": round(d.get("ar", 0) + d.get("fa", 0), 3), "ru": round(d.get("ru", 0), 3)}
                if lid["ru"] > max(0.1, lid["ar_fa"]):
                    eff -= 0.25
            info = {"exag": round(e, 2), "cfg": round(c, 2), "lang": lg, "tempo": round(tempo, 3), "dur": round(dur, 2), "wps": round(nw / max(0.3, spd / tempo), 2), "lid": lid}
            if eff > best[0]:
                best = (eff, cand, heard, i, info, sc)
            if eff >= THR:
                break
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        subprocess.run(["cp", best[1], dst], check=True)
    r = {"file": os.path.relpath(dst, ROOT), "text": text, "event": ev, "unit": uid, "faction": fac, "qa": round(best[5], 2),
         "take": best[3], "heard": best[2], "lufs_target": lufs, "ref": os.path.basename(ref),
         "engine": "chatterbox-multilingual (MIT) intensity m27, ref " + ("M2.5 militia prompt" if militia else "kokoro-82m m26 cast voice")}
    r.update(best[4])
    return r

def jobs(only=None, unit=None, out=OUT, events=None):
    js = []
    for (fac, uid, folder, ev, n, text, stem, _s) in vm.lines():
        if (only and fac != only) or (unit and uid != unit):
            continue
        if uid == "announcer":
            if ev not in ANN_EV:
                continue
            if fac in vc.CAST and "announcer" in vc.CAST[fac]:
                actors, akey = vc.CAST[fac]["announcer"], f"{fac}_announcer"
            else:
                actors, akey = vm.VOICE_CAST[fac]["announcer"], f"{fac}_announcer_m2"
            rel, radio = folder, False
        else:
            if ev not in UNIT_EV:
                continue
            if uid == "tpla_militia":
                actors, akey = vm.VOICE_CAST["tpla"]["units"]["tpla_militia"], "militia"
            else:
                actors, akey = vc.CAST[fac]["units"][uid], uid
            rel, radio = f"{fac}/{folder}", True
        if events and ev not in events:
            continue
        i = (n - 1) % len(actors)
        js.append((fac, uid, rel, ev, n, text, stem, os.path.join(out, rel, f"{ev}_{n}.ogg"), actors[i], f"{akey}_{i}", radio, iv.style_for(rel)))
    return js

def main(argv):
    arg = lambda k, d=None: argv[argv.index(k) + 1] if k in argv else d
    out = os.path.abspath(arg("--out", OUT))
    global REP
    if "--out" in argv:
        REP = os.path.join(out, "qa_intensity.json")
    evs = arg("--event"); evs = evs.split(",") if evs else None
    rep = {r["file"]: r for r in (json.load(open(REP)) if os.path.exists(REP) else [])}
    js = [j for j in jobs(arg("--only"), arg("--unit"), out, evs)
          if "--force" in argv or os.path.relpath(j[7], ROOT) not in rep or ("--retake" in argv and rep[os.path.relpath(j[7], ROOT)]["qa"] < THR)]
    # warm the prompt cache in this process (Kokoro), so workers don't race on it
    for j in js:
        if j[1] != "tpla_militia":
            prompt(j[0], j[1], j[8], j[9])
    print("lines to render:", len(js), flush=True)
    import multiprocessing as mp
    with mp.get_context("spawn").Pool(int(arg("--jobs", 2)), maxtasksperchild=20) as pool:
        for r in pool.imap_unordered(render, js):
            rep[r["file"]] = r
            print("%-52s %.2f t%d x%.2f c%.2f %s tempo %.2f %r" % (r["file"], r["qa"], r["take"], r["exag"], r["cfg"], r["lang"], r["tempo"], r["heard"]), flush=True)
            tmp = REP + ".tmp"
            json.dump(sorted(rep.values(), key=lambda x: x["file"]), open(tmp, "w"), indent=0)
            os.replace(tmp, REP)
    sc = [r["qa"] for r in rep.values()]
    print("QA: %d lines, mean %.2f, under %.1f: %d" % (len(sc), sum(sc) / max(1, len(sc)), THR, sum(1 for x in sc if x < THR)))

if __name__ == "__main__":
    main(sys.argv[1:])
