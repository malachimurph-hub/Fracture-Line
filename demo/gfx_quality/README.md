# Graphics review

One small snowy field, one M1A3, one power station, one scripted shot. It is a review scene. It does not replace the live tank, the live power station, or any map.

Open it from the main menu: **Graphics review**. Back returns to the menu.

From a terminal, in the project folder:

```
godot --path . --rendering-method mobile res://demo/gfx_quality/combat_review.tscn
```

The project renderer is Mobile (Vulkan). Keys: `1` RTS camera, `2` close-up, `3` impact camera, `R` replay, `Esc` back.

Screenshots (normal RTS, close-up, the hit, and the aftermath) plus a small stats file per frame:

```
godot --path . --rendering-method mobile --resolution 1600x900 \
  res://demo/gfx_quality/combat_review.tscn -- --shots /tmp/gfx_shots
```

Headless checks (they do not judge the picture):

```
godot --headless --path . res://tests/test_runner.tscn -- gfx_review
```

Regenerate the meshes and textures (Blender 4.0 or newer):

```
blender --background --factory-startup --python tools/gfx_review/author_demo.py
```

What you should see: the tank drives in, the turret lays on the station, the gun recoils, a tracer reaches the wall, then flash, fire, smoke, debris and scorch. The station swaps to a wreck. Smoke and fire are capped and reused if the shot is played again.
