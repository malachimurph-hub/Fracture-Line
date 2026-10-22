#!/usr/bin/env python3
"""Set balance CSV fields:  bal_set.py units.csv us_harrier max_hp=620 cost=1600 ...  then run import_balance.py"""
import csv, sys, os, io
p = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data", "balance", sys.argv[1])
rows = list(csv.reader(open(p, newline="")))
hdr = rows[0]
for r in rows[1:]:
    if r and r[0] == sys.argv[2]:
        for kv in sys.argv[3:]:
            k, v = kv.split("=", 1)
            print(f"{sys.argv[2]}.{k}: {r[hdr.index(k)]} -> {v}")
            r[hdr.index(k)] = v
        break
else:
    sys.exit("no row " + sys.argv[2])
with open(p, "w", newline="") as f:
    csv.writer(f, lineterminator="\n").writerows(rows)
