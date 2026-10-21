extends Node
## Holds the skirmish setup between the lobby, the match and the results screen.
var setup: Dictionary = {}       ## see ui/skirmish_setup.gd default_setup()
var last_result: Dictionary = {}
var resume_save: Dictionary = {} ## set when continuing a suspended match
