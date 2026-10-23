# Last Command (formerly FRACTURE LINE)

Original mobile RTS for Android, made in Godot 4.7.2 for Malachi Murphy. Main scene: `res://ui/main_menu.tscn`.

## Rename (M2.7)

The player-visible name is now **Last Command**: main-menu title, credits, Android launcher label
(`application/config/name`, export `package/name`) and the APK file name (`LastCommand-M<x>.apk`).

These stay the same so the new APK installs as an update and keeps settings and saves:

- Android package id `com.malachimurphy.fractureline` (`package/unique_name` in `export_presets.cfg`) and the same signing key.
- `user://`. On Android it is the app's files folder, which comes from the package id, not the app name.
  On desktop, `config/use_custom_user_dir` pins it to the old `godot/app_userdata/Fracture Line` folder.

Internal code names, class names, folder names, the `FractureLineVerify` test build and older docs still say FRACTURE LINE.

Changelogs and credits for each milestone are in `docs/`.
