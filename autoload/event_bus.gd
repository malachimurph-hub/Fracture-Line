extends Node
## Typed signals for UI and audio feedback. The simulation never listens to it.
signal selection_changed(ids: Array)
signal alert_raised(kind: String, text: String, world_pos: Vector2i)
signal toast(text: String)
signal command_issued(kind: String, world_pos: Vector2i)
signal match_ended(result: Dictionary)
signal settings_changed
