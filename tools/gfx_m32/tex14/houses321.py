#!/usr/bin/env python3
"""M3.2.1: every other village house (not container stacks) becomes a garrisonable neutral house
(neutral_house_a..d, like the civilian blocks): its decor line goes, its tiles turn back to open
ground (the structure blocks them in the sim) and it is added to the map's neutrals with its
facing. Idempotent. Run: python3 houses321.py <repo_root> <map>..."""
import sys, re
root = sys.argv[1]
for mid in sys.argv[2:]:
    M = root + "/data/maps/" + mid
    tres = open(M + ".tres").read()
    if "neutral_house_" in tres:
        print(mid, "already done"); continue
    g = [list(l.rstrip("\n")) for l in open(M + ".txt")]
    dec = open(M + ".decor.txt").read().splitlines()
    keep, add, n = [], [], 0
    for l in dec:
        p = l.split()
        if len(p) >= 4 and p[0] in ("house_a", "house_b", "house_c", "house_d"):
            n += 1
            if n % 2 == 1:
                x0, y0, rot = int(round(float(p[1]) - 1.5)), int(round(float(p[2]) - 1.5)), int(p[3])
                for yy in range(y0, y0 + 3):
                    for xx in range(x0, x0 + 3):
                        g[yy][xx] = "."
                add.append('{"kind": "neutral_%s", "tile": Vector2i(%d, %d), "rot": %d}' % (p[0], x0, y0, rot))
                continue
        keep.append(l)
    m = re.search(r"neutrals = Array\[Dictionary\]\(\[(.*)\]\)", tres)
    tres = tres[:m.start(1)] + m.group(1) + ", " + ", ".join(add) + tres[m.end(1):]
    open(M + ".tres", "w").write(tres)
    open(M + ".decor.txt", "w").write("\n".join(keep) + "\n")
    open(M + ".txt", "w").write("\n".join("".join(r) for r in g) + "\n")
    print(mid, "houses", n, "garrisonable", len(add))
