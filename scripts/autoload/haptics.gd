extends Node
## ─────────────────────────────────────────────
##  Haptics — autoloaded as `Haptics`
##  Xbox-controller rumble with varying strength.
##
##  Every vibration in the game flows through here so it:
##    • only ever fires when a CONTROLLER is the active device
##      (never buzzes a phantom pad while playing on keyboard),
##    • stays consistent and is tuned in ONE place (the PRESETS below),
##    • is trivial to add anywhere: `Haptics.rumble("medium")`.
##
##  Xbox pads have two motors. `Input.start_joy_vibration` takes them as:
##    weak_magnitude   -> the small HIGH-frequency motor (a light, fast buzz)
##    strong_magnitude -> the big  LOW-frequency motor (a deep, heavy rumble)
##  So bigger physical events lean on the "strong" value; light taps lean "weak".
## ─────────────────────────────────────────────

## Named intensity presets: [weak_motor, strong_motor, duration_seconds].
## Values are 0..1. Tune these to taste — every call site just names a preset,
## so changing the feel of the whole game happens right here.
const PRESETS := {
	# light, incidental touches
	"tap":     [0.18, 0.00, 0.07],   # a tiny tick (confirmations / light props)
	"light":   [0.28, 0.12, 0.12],   # sliding a mug across a table
	"medium":  [0.40, 0.32, 0.18],   # dragging / shoving a chair
	# the anger stage leans harder than anywhere else
	"heavy":   [0.55, 0.60, 0.24],   # a frustrated chair shove (anger)
	"throw":   [0.50, 0.78, 0.22],   # the moment the mug leaves the hand
	"impact":  [0.95, 1.00, 0.40],   # the mug SHATTERING (the climax) — biggest hit
	# cinematic / story beats
	"door":    [0.22, 0.42, 0.65],   # the heavy front door swinging open (Depression)
	"slam":    [0.80, 0.95, 0.45],   # a title-card slamming in — a sharp cinematic hit
}

## Master toggle — flip to false (e.g. from an options menu) to disable all rumble.
var enabled := true

## Fire a named preset. Safe to call from anywhere, on any device — it no-ops
## unless a controller is currently in use.
func rumble(preset: String) -> void:
	if not enabled:
		return
	if not _has_controller():
		return
	var p: Array = PRESETS.get(preset, PRESETS["light"])
	Input.start_joy_vibration(_device(), p[0], p[1], p[2])

## One-off custom rumble when no preset fits. Magnitudes are clamped to 0..1.
func rumble_custom(weak: float, strong: float, duration: float) -> void:
	if not enabled or not _has_controller():
		return
	Input.start_joy_vibration(_device(), clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), duration)

## Cut any ongoing vibration immediately.
func stop() -> void:
	Input.stop_joy_vibration(_device())

# ----------------------------------------------------------------- internals
## Only rumble when the player is actually on a controller. InputManager already
## tracks the active device for the rest of the game, so we defer to it.
func _has_controller() -> bool:
	if Input.get_connected_joypads().is_empty():
		return false
	if InputManager and InputManager.has_method("is_controller"):
		return InputManager.is_controller()
	return true

## The first connected joypad (0 if, somehow, none is listed).
func _device() -> int:
	var pads := Input.get_connected_joypads()
	return pads[0] if pads.size() > 0 else 0
