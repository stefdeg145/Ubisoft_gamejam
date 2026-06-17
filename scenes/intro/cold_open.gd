extends Node2D
## Phase 0 — the cold open. Pure black, a heartbeat the player can almost feel,
## one line, then a flatline. No title, no menu. The first scene the game loads.

const HOUSE := "res://scenes/house/house.tscn"
const MONITOR := preload("res://assets/Sound/Heartbeat flatline sound HD.mp3")
## The clip runs ~4s of steady heartbeat, then a sustained flatline tone from ~4.2s.
## Starting it as the line begins lands the flatline exactly as "Stay with me" fades.

var _started := false
var _monitor: AudioStreamPlayer

# --- heart-monitor ECG trace (drawn over the black so the cold open reads as a
#     hospital bedside, not just a sound in the dark) ---
const ECG_AMP := 120.0          # spike height in px
const ECG_SCROLL := 220.0       # px/s the trace scrolls left
const ECG_PERIOD := 240.0       # px between heartbeats
var _ecg_layer: CanvasLayer
var _ecg: Line2D
var _ecg_running := false
var _ecg_flat := false
var _ecg_phase := 0.0

func _ready() -> void:
	Game.set_black(true)
	Game.hide_prompt()
	_monitor = AudioStreamPlayer.new()
	_monitor.stream = MONITOR
	_monitor.bus = "Master"
	add_child(_monitor)
	_build_ecg()
	await get_tree().create_timer(1.0).timeout
	Game.show_prompt("press E")

func _unhandled_input(event: InputEvent) -> void:
	if _started:
		return
	if event.is_action_pressed("ui_accept"):
		_started = true
		_begin()

func _begin() -> void:
	Game.hide_prompt()
	await get_tree().create_timer(1.2).timeout
	_monitor.volume_db = -20.0                           # 20 dB quieter than default
	_monitor.play()                                      # steady heartbeat under the line...
	_start_ecg()                                         # ...and the trace starts beating
	# The clip flatlines from ~4.2s; flatten the trace to match.
	get_tree().create_timer(4.2).timeout.connect(_flatline_ecg)
	await Game.say("Eli. Stay with me.", 1.0)
	await get_tree().create_timer(2.0).timeout          # ...the monitor flatlines, held too long
	await Game.say("...", 1.0)                           # the line goes flat
	await get_tree().create_timer(1.6).timeout
	_fade_monitor_out()                                  # the tone gives way to the rain
	_fade_ecg_out(1.4)
	await Game.say("Only the rain, now.", 1.0)
	await get_tree().create_timer(0.8).timeout
	# Title card: the game name, then the jam credit, over the black.
	await Game.show_title_card("After", "Ubisoft Gamejam 2026", 3.2)
	await get_tree().create_timer(0.6).timeout
	Game.change_scene(HOUSE)

func _fade_monitor_out() -> void:
	if not _monitor.playing:
		return
	var t := create_tween()
	t.tween_property(_monitor, "volume_db", -40.0, 1.4)
	t.tween_callback(_monitor.stop)

# ---------------------------------------------------------------- ECG trace
func _build_ecg() -> void:
	_ecg_layer = CanvasLayer.new()
	_ecg_layer.layer = 101                               # above Game's black fade (layer 100)
	add_child(_ecg_layer)
	_ecg = Line2D.new()
	_ecg.width = 3.0
	_ecg.default_color = Color(0.45, 1.0, 0.55, 0.0)     # soft monitor green, invisible until it beats
	_ecg.joint_mode = Line2D.LINE_JOINT_ROUND
	_ecg_layer.add_child(_ecg)
	_rebuild_ecg()

func _start_ecg() -> void:
	_ecg_running = true
	var t := create_tween()
	t.tween_property(_ecg, "default_color:a", 0.85, 0.6)

func _flatline_ecg() -> void:
	_ecg_flat = true

func _fade_ecg_out(dur: float) -> void:
	if _ecg == null:
		return
	var t := create_tween()
	t.tween_property(_ecg, "default_color:a", 0.0, dur)

func _process(delta: float) -> void:
	if not _ecg_running or _ecg == null:
		return
	_ecg_phase += delta * ECG_SCROLL
	_rebuild_ecg()

func _rebuild_ecg() -> void:
	var vp := get_viewport().get_visible_rect().size
	var baseline := vp.y * 0.5
	var pts := PackedVector2Array()
	var x := 0.0
	while x <= vp.x:
		pts.append(Vector2(x, baseline - _ecg_value(x + _ecg_phase) * ECG_AMP))
		x += 4.0
	_ecg.points = pts

## A simple PQRST-ish heartbeat shape repeating every ECG_PERIOD px. Returns 0
## (flat) once the heart has stopped.
func _ecg_value(d: float) -> float:
	if _ecg_flat:
		return 0.0
	var t: float = fmod(d, ECG_PERIOD) / ECG_PERIOD       # 0..1 within one beat
	var y := 0.0
	y += 0.12 * exp(-pow((t - 0.30) / 0.030, 2.0))        # P wave
	y -= 0.20 * exp(-pow((t - 0.46) / 0.012, 2.0))        # Q dip
	y += 1.00 * exp(-pow((t - 0.50) / 0.010, 2.0))        # R spike
	y -= 0.35 * exp(-pow((t - 0.54) / 0.014, 2.0))        # S dip
	y += 0.22 * exp(-pow((t - 0.68) / 0.040, 2.0))        # T wave
	return y
