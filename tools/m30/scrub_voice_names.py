#!/usr/bin/env python3
"""M3.0: drop voice variants that speak a unit's OLD name (renamed units reuse their voices).
A name-bearing <event>_<n>.ogg is deleted and the event's last variant is moved into its slot,
unless it is the only variant (kept; listed in KNOWN_ISSUES). Updates voice_ai_index.json.
Usage: scrub_voice_names.py <fac>/<folder>:<Name>[|<Name>] ..."""
import json, os, re, sys, glob
IDX = "audio/voice_ai/voice_ai_index.json"
idx = json.load(open(IDX))
by_file = {l["file"]: l for l in idx["lines"]}
kept = []
for arg in sys.argv[1:]:
    fold, names = arg.split(":")
    pat = re.compile(names, re.I)
    d = "audio/voice_ai/" + fold
    for l in [l for l in idx["lines"] if l["file"].startswith(d + "/") and pat.search(l["text"])]:
        f = l["file"]
        m = re.match(r"(.*/)(\w+?)_(\d+)\.ogg$", f)
        ev = m.group(2)
        vs = sorted(glob.glob(d + "/%s_*.ogg" % ev), key=lambda p: int(re.search(r"_(\d+)\.ogg$", p).group(1)))
        if len(vs) <= 1:
            kept.append((f, l["text"])); continue
        last = vs[-1]
        os.remove(f)
        for ext in [".import"]:
            if os.path.exists(f + ext): os.remove(f + ext)
            if os.path.exists(last + ext): os.remove(last + ext)
        idx["lines"].remove(l)
        if last != f:
            os.rename(last, f)
            by_file[last]["file"] = f
        print("dropped", f, repr(l["text"]))
json.dump(idx, open(IDX, "w"), indent=0, ensure_ascii=False)
for f, t in kept: print("KEPT (only variant)", f, repr(t))
