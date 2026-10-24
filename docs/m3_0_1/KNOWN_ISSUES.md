# M3.0.1 known issues

- **The new fixes have not been timed on the S24 Ultra.** All timings were measured on the build box
  with the headless (CPU-only) engine. GPU costs, such as shader compiles the first time a material is
  drawn, could not be measured there.
- **A new menu battle still has one heavy step,** building the map view: about 2 s on the box, likely
  much less on the phone. This happens only at start-up and after a match. The menu is already on
  screen and the backdrop fades in afterwards.
- **Loading a battle still takes a moment** (about 2.3 s on the box, down from 3.5 s). The "Loading battle…"
  screen covers it.
- The shoreline cache files are stored in `user://cache/`, about 3–50 KB per map.
- Everything else from M3.0 still applies: `docs/m3_0/KNOWN_ISSUES.md`.
