#!/usr/bin/env python3
"""Import recorded voice lines into the game.

  python3 tools/import_voice.py <input files or folders...> [--radio|--no-radio] [--dry-run]

Accepted names (any audio format ffmpeg reads: WAV, M4A, MP3, OGG, FLAC...):
  eu_leopold_attack_1.m4a          -> audio/voice/eu/leopold/attack_1.ogg
  announcer_low_power_1.wav        -> audio/voice/announcer/low_power_1.ogg
  eu/leopold/attack_2.wav          (folder layout also works)
  eu_leopold_attack.m4a, ..._take2 (no/duplicate number -> next free variant 1..9)
Processing: trim leading/trailing silence -> per-faction radio filter (unit lines; the
announcer stays clean) -> two-pass loudness normalisation to -16 LUFS (short clips use an
RMS fallback) -> -1 dBTP limiter -> mono 24 kHz Ogg Vorbis q4.
Also used by tools/gen_placeholder_voices.py with --out audio/voice_placeholder."""
import json, os, re, subprocess, sys, tempfile
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MAN = json.load(open(os.path.join(ROOT, "data", "audio", "voice_manifest.json")))
EXTS = (".wav", ".m4a", ".mp3", ".ogg", ".flac", ".aac", ".opus", ".3gp", ".amr", ".webm")
RADIO = "highpass=f=320,lowpass=f=3300,acompressor=threshold=-20dB:ratio=5:attack=4:release=80:makeup=4,asoftclip=type=tanh,highpass=f=300,lowpass=f=3500"
TRIM = "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.04,areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.08,areverse"

def known():
    folders = {}
    for fac, fd in MAN["factions"].items():
        for uid, ud in fd["units"].items():
            folders[(fac, ud["folder"])] = ud["events"]
    return folders, list(MAN["events"].keys()), list(MAN["announcer"]["events"].keys())

def parse(path):
    """-> (rel_dir, event, n or None, radio_default)"""
    folders, unit_events, ann_events = known()
    p = path.replace("\\", "/").lower()
    stem = os.path.splitext(os.path.basename(p))[0]
    stem = re.sub(r"[\s\-]+", "_", stem)
    stem = re.sub(r"(_?take_?\d+|_t\d+|\(\d+\))$", "", stem).strip("_")
    parent = p.split("/")[-3:-1]
    if len(parent) == 2 and (parent[0], parent[1]) in folders:
        stem = f"{parent[0]}_{parent[1]}_{stem}"
    elif parent and parent[-1] == "announcer" and not stem.startswith("announcer"):
        stem = "announcer_" + stem
    m = re.match(r"^(.*?)(?:_(\d))?$", stem)
    base, n = m.group(1), (int(m.group(2)) if m.group(2) else None)
    if base.startswith("announcer_"):
        ev = base[len("announcer_"):]
        if ev in ann_events:
            return ("announcer", ev, n, MAN["announcer"]["radio"])
        raise ValueError(f"unknown announcer event '{ev}'")
    for (fac, folder), evs in folders.items():
        pre = f"{fac}_{folder}_"
        if base.startswith(pre):
            ev = base[len(pre):]
            if ev in evs:
                return (f"{fac}/{folder}", ev, n, MAN["factions"][fac]["radio"])
            raise ValueError(f"'{ev}' is not an event of {fac}/{folder} (expected one of {evs})")
    raise ValueError("can't tell which unit/event this is: " + os.path.basename(path))

def loud(path):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json", "-f", "null", "-"], capture_output=True, text=True)
    js = r.stderr[r.stderr.rfind("{"):r.stderr.rfind("}") + 1]
    return json.loads(js)

def process(src, dst, radio):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        a = os.path.join(td, "a.wav")
        chain = TRIM + ("," + RADIO if radio else "")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-ac", "1", "-ar", "48000", "-af", chain, a], check=True)
        dur = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", a], capture_output=True, text=True).stdout.strip() or 0)
        m = loud(a)
        if dur >= 0.5 and float(m["input_i"]) > -60:
            norm = (f"loudnorm=I=-16:TP=-1.5:LRA=11:measured_I={m['input_i']}:measured_TP={m['input_tp']}:"
                    f"measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}:offset={m['target_offset']}:linear=true")
        else:   # very short clip: RMS-based gain (~ -16 LUFS for speech)
            r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", a, "-af", "volumedetect", "-f", "null", "-"], capture_output=True, text=True)
            mean = float(re.search(r"mean_volume: (-?[\d.]+)", r.stderr).group(1))
            norm = f"volume={-19.0 - mean:.2f}dB"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", a, "-af", norm + ",alimiter=limit=0.84:attack=2:release=40,aresample=24000",
                        "-ac", "1", "-c:a", "libvorbis", "-q:a", "4", dst], check=True)
    return dur

def main(argv):
    radio_force = None
    dry = "--dry-run" in argv
    out_root = os.path.join(ROOT, "audio", "voice")
    files = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--radio": radio_force = True
        elif a == "--no-radio": radio_force = False
        elif a == "--out": out_root = os.path.abspath(argv[i + 1]); i += 1
        elif a == "--dry-run": pass
        elif os.path.isdir(a):
            for dp, _, fs in os.walk(a):
                files += [os.path.join(dp, f) for f in sorted(fs) if f.lower().endswith(EXTS)]
        else: files.append(a)
        i += 1
    used = set()
    ok = bad = 0
    for f in files:
        try:
            rel, ev, n, radio = parse(f)
        except ValueError as e:
            print("SKIP", f, "-", e); bad += 1; continue
        if radio_force is not None: radio = radio_force
        cand = [n] if n else []
        cand += [k for k in range(1, MAN.get("max_variants", 9) + 1) if k != n]
        dst = None
        for k in cand:
            p = os.path.join(out_root, rel, f"{ev}_{k}.ogg")
            if p not in used and (k == n or not os.path.exists(p)):
                dst = p; break
        if dst is None:
            print("SKIP", f, "- all variant slots used"); bad += 1; continue
        used.add(dst)
        if dry:
            print("would import", f, "->", os.path.relpath(dst, ROOT), "radio" if radio else "clean"); ok += 1; continue
        d = process(f, dst, radio)
        print("OK", os.path.relpath(dst, ROOT), f"{d:.2f}s", "radio" if radio else "clean"); ok += 1
    print(f"imported {ok}, skipped {bad}. Re-open the Godot project (or run --import) so the new .ogg files are picked up.")
    return 0 if bad == 0 else 1

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
