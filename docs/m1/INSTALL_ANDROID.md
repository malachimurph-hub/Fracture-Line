# Installing FRACTURE LINE (M1) on your Android phone

Target device: Samsung Galaxy S24 Ultra (Android 14+). Any 64-bit (arm64) Android 7.0+ phone should work.
This build has not been run on a real phone yet; it was verified in a desktop simulation (see KNOWN_ISSUES.md).

## Install
1. In the chat, tap **FractureLine-M1.2.apk** (the latest build) to download it. It installs over the older M1 and M1.1 builds.
2. Open it from the notification, or from **My Files > Downloads**.
3. Android will say the app you opened it with isn't allowed to install apps. Tap **Settings**, then turn on
   **Allow from this source** for *that* app (for example My Files, Chrome or Samsung Internet). Then go back.
4. Tap **Install**. If Play Protect warns about an unknown developer, tap **More details > Install anyway**.
   (It's a debug-signed test build, so this warning is expected.)
5. Tap **Open**. Play in landscape. Rotation lock is fine; the game is landscape-only.

To update later, install the new APK over this one. To remove it, long-press the icon and choose **Uninstall**.
You can turn **Allow from this source** off again after installing.

## Starting a game
Main menu > **Skirmish**. Set each slot (AI Easy/Medium/Hard, Open or Closed), plus team 1–4, color and start position.
Choose starting cash and fog. Tap **Start battle**. You can't start if everyone is on one team.

## Touch controls
| Gesture | What it does |
|---|---|
| Drag one finger | Pan the camera (flick for momentum) |
| Tap | Select a unit or building. With units selected, tap the ground to move or an enemy to attack. |
| Double-tap a unit | Select all units of that type on screen |
| Hold ~⅓ s, then drag | Box-select. You feel a tick when the hold registers; the box corner draws above your finger. |
| Hold, then release without dragging | Attack-move there |
| Two-finger tap | Cancel the current mode, or deselect |
| Pinch | Zoom (close / normal / far tactical; far shows unit icons) |
| Minimap (bottom-left) | Tap to jump, drag to scrub, long-press to send selected units there |

**Building:** select a Crawler (or tap **Build**), then tap a building in the grid. Drag the ghost; it floats above your finger.
Lifting your finger never places anything. Tap **Confirm** (green) to build, or use **Rotate** or **Cancel**. The Crawler drives over and builds.
Keep buildings inside your power grid (cyan circles around the HQ, Reactors and Pylons).

**Production:** tap a Barracks, Motor Pool, Heavy Factory or HQ, then tap a unit to queue it.
Long-press a unit to cancel one. **Rally** sets where new units go; **Loop** repeats the build.

**Other:** use **Army** to select all combat units and **Crawler** to find an idle builder.
Groups **1–5**: long-press to save the current selection, tap to recall, tap again to jump to it.
**II** pauses. **Menu** opens the menu (speed, restart, surrender, save & quit). **General** spends rank points on powers.
The phone's Back gesture opens the menu. The game autosaves when you switch apps; use **Continue** on the main menu.

The S Pen works like a finger.

## Mouse and keyboard (web build or a desktop)
- **Mouse:**
  - Left click selects; drag to box-select.
  - Right click gives the smart command, or cancels a mode.
  - Middle drag pans; the wheel zooms.
- **Keys:**
  - WASD or the arrow keys pan. A and S pan only when no units are selected.
  - Ctrl+1–5 saves a group and 1–5 recalls it.
  - A attack-move, S stop, G guard.
  - R rotates a building, Enter confirms it, B opens the build menu, P pauses.
  - Space jumps to the last alert. Esc cancels or opens the menu.
