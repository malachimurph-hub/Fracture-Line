# Fracture Line: Global Conflict

Original mobile RTS for Android, made in Godot 4.7.2 for Malachi Murphy. Main scene: `res://ui/main_menu.tscn`.

## Title (M3.2.2)

The player-visible name is **Fracture Line: Global Conflict** (M3.2.2; the M2.7-M3.2.1 builds were
called "Rules of Engagement", a title that is a registered trademark of another company for video
games, so it was dropped). Main-menu badge and title text, boot splash, credits, error screen,
window title (`application/config/name`) and Play listing use the full title; the Android launcher
label (export `package/name`) is the short **Fracture Line** so it is not cut off under the icon.
Output files: `FractureLine-M<x>.apk`, `FractureLine.aab`.

These stay the same so the new APK installs as an update and keeps settings and saves:

- Android package id `com.malachimurphy.fractureline` (`package/unique_name` in `export_presets.cfg`) and the same signing key.
- `user://`. On Android it is the app's files folder, which comes from the package id, not the app name.
  On desktop, `config/use_custom_user_dir` pins it to the old `godot/app_userdata/Fracture Line` folder.

Internal code names, class names, folder names, the `FractureLineVerify` test build and older docs still say FRACTURE LINE.

Changelogs and credits for each milestone are in `docs/`.
