# M2.3 known issues

- **Balance: Medium AI matchup leans EU.** In the 24-seed EU vs TPLA soak, EU won 15 and TPLA 9.
  By difficulty: Medium 8-0 EU, Hard 4-4, Easy 5-3 TPLA. In the separate 12-seed Hard vs Hard soak
  EU won 7-5. Before M2.3, Medium leaned TPLA. The new mechanics (aim, clips, scatter) shifted
  fights toward EU; one retune pass made Hard even, but Medium TPLA still loses. Next step: tune
  the Medium TPLA AI and its army mix.
- **All numbers are our tuning, not Zero Hour data.** This covers turn rates, acceleration, clip
  sizes, reloads, pre-attack times, scatter radii and the damaged-speed penalty. ZH's INI data is
  not in the GPL release.
- **Wheeled vehicles can briefly circle a destination** that is very close and to one side; they
  slow to 1/4 speed near the goal, and re-pathing breaks it.
- **Arrival is not fully together.** Group moves cap speed at the slowest member, but formation
  slots are still a ring, so slot distances (and tracked vehicles' slower acceleration) leave a
  few seconds of spread.
- **A shot that scatters away from its target deals no damage to it unless it has splash.** The
  missed target is not alerted, so it does not react until it is actually hit.
- **Deferred ZH gaps** (see ZH_REFERENCE.md): two-ring splash, idle builder auto-repair, projectile
  travel time, continuous-fire ramp-up, a 30 Hz logic rate (we keep 20 Hz) and stealth reveal delay.
- All M2.2 and M2.1 known issues still apply (debug-key signed, arm64 only, partial art upgrade, no on-device perf measurement).
