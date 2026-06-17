extends Node
## ─────────────────────────────────────────────
##  InputManager — autoloaded as InputManager
##  Detects keyboard/mouse vs Xbox controller
##  and emits device_changed when it switches.
##  All other scripts listen to this signal to
##  update their UI hints automatically.
## ─────────────────────────────────────────────

signal device_changed(new_device: String)  # "keyboard" or "controller"

var active_device := "keyboard"

const SWITCH_COOLDOWN := 0.3
var _cooldown := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta


func _input(event: InputEvent) -> void:
	if _cooldown > 0.0:
		return

	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadMotion and abs(event.axis_value) < 0.2:
			return
		if active_device != "controller":
			active_device = "controller"
			_cooldown = SWITCH_COOLDOWN
			emit_signal("device_changed", "controller")

	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		if active_device != "keyboard":
			active_device = "keyboard"
			_cooldown = SWITCH_COOLDOWN
			emit_signal("device_changed", "keyboard")


func is_controller() -> bool:
	return active_device == "controller"


func is_keyboard() -> bool:
	return active_device == "keyboard"


## Returns the correct hint text for the current device
## action: "accept" / "navigate"
func hint(action: String) -> String:
	match action:
		"accept":
			return "A" if is_controller() else "E"
		"navigate":
			return "Left Stick / D-Pad" if is_controller() else "WASD"
		"dialogic":
			return "A" if is_controller() else "Enter / Click"
		_:
			return ""
