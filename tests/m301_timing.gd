extends Node
## M3.0.1 timing probe launcher: puts tests/m301_probe.gd on the root so it survives scene changes.
func _ready() -> void:
	var n := Node.new()
	n.set_script(load("res://tests/m301_probe.gd"))
	get_tree().root.add_child.call_deferred(n)
