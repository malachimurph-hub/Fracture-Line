# FRACTURE LINE M2.6 (0.2.6, versionCode 10)

Built from Malachi's M2.5 feedback (FEEDBACK_malachi_2026-10-22_m25.md).

## Fixes
- **Stuck on "Paused" after closing and reopening the app.**
  - Pausing now tracks reasons (pause button, pause menu, app sent to background).
  - When Android pauses the app, the game autosaves and pauses behind the pause menu.
  - On return, the menu is up. **Resume** always clears every pause reason, so the game can no
    longer be left paused with no way out.
  - The M2.5 bug path (pause menu open → app backgrounded → reopened → Resume did nothing) is
    covered by tests/m26_ui_test.

## Building placement
- After choosing a structure, **tap a spot or drag the ghost** to move it. The ghost stays until
  you confirm.
- **✓ / ✗ buttons float just above the silhouette** and follow it.
  - ✓ is greyed out and does nothing while the spot is invalid (the ghost turns red).
  - ✗ cancels.
- The same build-anywhere rules apply (sim `can_place`).
- Rotate stays in the side bar. On desktop, a click moves the ghost and Enter or ✓ confirms.

## HUD
- **Command bar slides away** (animated, ~0.2 s) when nothing is selected. The **minimap grows**
  from 98 to 168 dp at the bottom-left.
  - Money, power, General and Build stay in their own small faction panel at the bottom-right.
  - Any selection slides the bar back up.
- **Top-strip buttons are about 15% smaller** (drawn at 37 dp instead of 44). Invisible tap
  padding keeps every touch target at 44 dp.
- **Faction-themed HUD**, ZH-style:
  - **EU:** gunmetal, gold and cyan with rounded frames.
  - **TPLA:** rust, umber and sand with square, slanted, welded-edge frames and a heavier,
    slightly slanted font.
  - **US:** navy, steel blue and white with tight corners and a soft steel glow.
  - Each faction has its own emblem (drawn in code) on the resource panel, plus its own money,
    title and accent colours.

## Main menu
- **A live battle loops behind the menu** (ZH-style).
  - It is a real match on a random skirmish map: real sim, unit models, weapons and effects.
  - Two random factions trade waves in the middle while the camera drifts over the fighting.
  - Maps come from `Content.maps` and units from each faction's roster in `Content.units`, so
    future maps and units appear automatically.
  - It is kept light: half-resolution sub-viewport, no shadows, 30 FPS cap while the menu is
    up, about 8 units a side, no AI economy, and silent.
  - It can be turned off in Settings ("Battle behind the main menu").

## Naming
- The US "Marine Grunt" is now **"Marine Rifleman"** in all player-visible text and docs.
  - This covers the unit name, the JTAC description, Paradrop ("Five Marine Riflemen"), the
    US faction sheet and the roster doc.
  - The internal id `us_grunt` is kept so saves and replays stay valid.

## Balance (US AI was winning far too often)
See SOAK.md for the before/after table and seeds. Numbers only; every unit keeps its role and
abilities.

Harrier (helicopter):
- Chain gun: 16 → 12 dmg, 180 → 240 ms, now a 20-round belt with a 3.5 s reload. It still
  reloads in the air and never lands.
- Hellfire: 90 → 70 dmg, reload 9 → 11 s.
- HP 700 → 540, cost 1500 → 1600.

Halberd:
- HP 1050 → 980, gun 125 → 110, cost 1100 → 1200.

Other US units:
- Javelin: cost 450 → 500.
- Lynx HMG: 12 → 10.
- Marine Rifleman rifle: 13 → 12.

TPLA:
- Militia HP 170 → 180.
- Rocket Cell HP 130 → 150.
- Hailstorm cost 700 → 650.

## Voices / licence
- The licence review of the Persian Piper voices behind the TPLA prompts is in
  docs/m2_6/LICENCE_REVIEW.md.
  - All three voices descend from the research-only "lessac" voice.
  - That is not clearly permissive, so TPLA voices are being regenerated without them by the
    asset track.
