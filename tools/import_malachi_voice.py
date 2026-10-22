#!/usr/bin/env python3
"""Import one of Malachi's own recorded lines as a numbered drop-in voice variant.

  python3 tools/import_malachi_voice.py <input> <event> [--unit us/sniper] [--start S --end E]
        [--n N] [--text "transcript"] [--reimport] [--commit] [--godot PATH] [--dry-run]

<input>  any file ffmpeg can read (WAV/MP3/M4A, or a phone video: the audio track is used).
<event>  manifest event of the unit (select, move, attack, under_fire, created, veteran, garrison).
--start/--end  cut window in seconds inside <input> (for a long take with several lines).
--n      variant number (default: next free slot in audio/voice/<unit>/, up to max_variants).

Gentle chain, his natural voice (no pitch / timbre / speed change):
  cut -> trim silence -> high-pass 80 Hz -> de-click -> light FFT noise reduction ->
  light compression (2.5:1) -> [dry copy kept aside] -> the faction's light radio colour
  (only for factions whose unit lines use it; US sniper does) -> loudness matched to the
  existing AI unit lines (ebur128 integrated, -14.5 LUFS like the shipped US set) ->
  -1 dBFS limiter -> 8 ms fade-in / 60 ms fade-out -> mono 24 kHz Ogg Vorbis q5.
Outputs:
  audio/voice/<unit>/<event>_<n>.ogg                       (game, overrides AI lines per event)
  assets_src/voice/malachi/<unit>/dry/<event>_<n>.wav      (dry version, not exported)
  assets_src/voice/malachi/<unit>/lines.json               (transcript / source log)
The game (autoload/audio_director.gd) picks among ALL variants 1..max_variants of an event
with a shuffle bag (no back-to-back repeat). If audio/voice/<unit>/ has any <event>_<n>.ogg,
only the recorded set is used for that event; events without recordings keep the AI lines."""
import json, os, re, subprocess, sys, tempfile
sys.path.insert(0, os.path.dirname(__file__))
import import_voice as iv
ROOT = iv.ROOT
MAN = iv.MAN
TARGET_LUFS = -14.5          # measured median of the shipped US AI unit lines (ebur128)
CLEAN = ("highpass=f=80:poles=2,adeclick=w=55:o=75,afftdn=nr=8:nf=-60:tn=1,"
         "acompressor=threshold=-24dB:ratio=2.5:attack=8:release=140:makeup=2:knee=4")
TRIM = ("silenceremove=start_periods=1:start_threshold=-48dB:start_silence=0.05,areverse,"
        "silenceremove=start_periods=1:start_threshold=-48dB:start_silence=0.09,areverse")

def run(cmd):
    return subprocess.run(cmd, check=True, capture_output=True, text=True)

def lufs(path):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128=peak=true", "-f", "null", "-"],
                       capture_output=True, text=True).stderr
    i = float(re.findall(r"I:\s+(-?[\d.]+) LUFS", r)[-1])
    return i

def dur(path):
    return float(run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path]).stdout.strip())

def finish(src, dst_wav, chain_extra=""):
    """loudness-match + limiter + fades -> dst_wav (48 kHz mono float)."""
    with tempfile.TemporaryDirectory() as td:
        a = os.path.join(td, "a.wav")
        run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-af", chain_extra or "anull", "-c:a", "pcm_f32le", a])
        d = dur(a)
        g = TARGET_LUFS - lufs(a)
        for _ in range(3):   # limiter eats a little loudness: converge
            b = os.path.join(td, "b.wav")
            run(["ffmpeg", "-y", "-loglevel", "error", "-i", a, "-af",
                 f"volume={g:.2f}dB,alimiter=limit=0.89:attack=3:release=50:level=false,"
                 f"afade=t=in:d=0.008,afade=t=out:st={max(0.0, d - 0.06):.3f}:d=0.06", "-c:a", "pcm_f32le", b])
            err = TARGET_LUFS - lufs(b)
            if abs(err) < 0.3:
                break
            g += err
        os.replace(b, dst_wav)
    return d

def next_free(folder, event, want=None):
    maxv = int(MAN.get("max_variants", 9))
    if want:
        return want
    for k in range(1, maxv + 1):
        if not os.path.exists(os.path.join(folder, f"{event}_{k}.ogg")):
            return k
    raise SystemExit(f"all {maxv} variant slots of {event} are used (raise max_variants in tools/voice_manifest_src.py)")

def godot_bin(given=None):
    for c in [given, os.environ.get("GODOT"), "/workspace/tools/godot", "godot", "godot4"]:
        if c and subprocess.run(["bash", "-c", f"command -v '{c}'"], capture_output=True).returncode == 0:
            return c
    return None

def main(argv):
    if len(argv) < 2 or argv[0] in ("-h", "--help"):
        print(__doc__); return 2
    src, event = argv[0], argv[1]
    opts = {"--unit": "us/sniper", "--start": None, "--end": None, "--n": None, "--text": "", "--godot": None}
    flags = set()
    i = 2
    while i < len(argv):
        a = argv[i]
        if a in opts: opts[a] = argv[i + 1]; i += 2
        else: flags.add(a); i += 1
    fac, folder = opts["--unit"].split("/")
    unit = next((u for u, d in MAN["factions"][fac]["units"].items() if d["folder"] == folder), None)
    if unit is None:
        raise SystemExit(f"unknown unit folder {opts['--unit']}")
    evs = MAN["factions"][fac]["units"][unit]["events"]
    if event not in evs:
        raise SystemExit(f"'{event}' is not an event of {unit}: {evs}")
    radio = bool(MAN["factions"][fac].get("radio", False))
    style = MAN["factions"][fac].get("radio_style", fac)
    out_dir = os.path.join(ROOT, "audio", "voice", fac, folder)
    src_dir = os.path.join(ROOT, "assets_src", "voice", "malachi", fac, folder)
    os.makedirs(out_dir, exist_ok=True); os.makedirs(os.path.join(src_dir, "dry"), exist_ok=True)
    n = next_free(out_dir, event, int(opts["--n"]) if opts["--n"] else None)
    dst = os.path.join(out_dir, f"{event}_{n}.ogg")
    dry = os.path.join(src_dir, "dry", f"{event}_{n}.wav")
    if "--dry-run" in flags:
        print("would import", src, "->", os.path.relpath(dst, ROOT), "radio" if radio else "clean"); return 0
    with tempfile.TemporaryDirectory() as td:
        cut = os.path.join(td, "cut.wav")
        cmd = ["ffmpeg", "-y", "-loglevel", "error"]
        if opts["--start"]: cmd += ["-ss", opts["--start"]]
        if opts["--end"]: cmd += ["-to", opts["--end"]]
        cmd += ["-i", src, "-vn", "-ac", "1", "-ar", "48000", "-af", TRIM + "," + CLEAN, "-c:a", "pcm_f32le", cut]
        run(cmd)
        d = finish(cut, os.path.join(td, "dry.wav"))
        run(["ffmpeg", "-y", "-loglevel", "error", "-i", os.path.join(td, "dry.wav"), "-c:a", "pcm_s24le", dry])
        wet = os.path.join(td, "wet.wav")
        finish(cut, wet, iv.RADIO_STYLES[style] if radio else "")
        run(["ffmpeg", "-y", "-loglevel", "error", "-i", wet, "-af", "aresample=24000:resampler=soxr", "-ac", "1",
             "-c:a", "libvorbis", "-q:a", "5", dst])
    log_p = os.path.join(src_dir, "lines.json")
    log = json.load(open(log_p)) if os.path.exists(log_p) else {"voice": "Malachi Murphy (own recording)", "lines": []}
    log["lines"] = [l for l in log["lines"] if l["file"] != os.path.relpath(dst, ROOT)]
    log["lines"].append({"file": os.path.relpath(dst, ROOT), "event": event, "text": opts["--text"],
                         "source": os.path.basename(src), "start": opts["--start"], "end": opts["--end"],
                         "radio": style if radio else "", "lufs": TARGET_LUFS, "dry": os.path.relpath(dry, ROOT)})
    log["lines"].sort(key=lambda l: l["file"])
    json.dump(log, open(log_p, "w"), indent=1)
    print(f"OK {os.path.relpath(dst, ROOT)} {d:.2f}s {'radio:' + style if radio else 'clean'}  \"{opts['--text']}\"")
    if "--reimport" in flags or "--commit" in flags:
        g = godot_bin(opts["--godot"])
        if g:
            subprocess.run([g, "--headless", "--path", ROOT, "--import"], capture_output=True, timeout=900)
        else:
            print("WARN: godot not found, skipped re-import")
    if "--commit" in flags:
        subprocess.run(["git", "-C", ROOT, "add", out_dir, src_dir], check=True)
        subprocess.run(["git", "-C", ROOT, "commit", "-q", "-m", f"voice: Malachi's own {unit} {event}_{n} \"{opts['--text']}\""], check=True)
        print("committed")
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
