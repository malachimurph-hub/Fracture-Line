class_name FLLogger
extends Logger
## Captures engine and script errors (thread-safe) so the game can show them on screen and
## save them to user:// on devices where no logcat is available.

const MAX_LINES := 200
var _lines: PackedStringArray = PackedStringArray()
var _mutex := Mutex.new()
var error_count := 0

func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	var kind: String = ["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"][clampi(error_type, 0, 3)]
	var msg := rationale if not rationale.is_empty() else code
	_add("%s: %s\n   at: %s (%s:%d)" % [kind, msg, function, file, line], error_type != 1)

func _log_message(message: String, error: bool) -> void:
	if error:
		_add(message.strip_edges(), true)

func _add(s: String, is_error: bool) -> void:
	_mutex.lock()
	_lines.append("[%d ms] %s" % [Time.get_ticks_msec(), s])
	if _lines.size() > MAX_LINES:
		_lines = _lines.slice(_lines.size() - MAX_LINES)
	if is_error:
		error_count += 1
	_mutex.unlock()

func text(last_n: int = MAX_LINES) -> String:
	_mutex.lock()
	var start := maxi(0, _lines.size() - last_n)
	var t := "\n".join(_lines.slice(start))
	_mutex.unlock()
	return t
