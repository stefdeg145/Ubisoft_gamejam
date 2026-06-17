extends Node2D

const HOUSE := "res://scenes/house/house.tscn"
const MONITOR := preload("res://assets/Sound/Heartbeat flatline sound HD.mp3")

var _started := false
var _monitor: AudioStreamPlayer

const ECG_AMP := 120.0
const ECG_SCROLL := 220.0
const ECG_PERIOD := 240.0
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
	_update_prompt_text()

func _unhandled_input(event: InputEvent) -> void:
	if _started:
		return
		
	if event is InputEventKey or event is InputEventMouseButton:
		if InputManager.is_controller():
			_update_prompt_text()
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if not InputManager.is_controller():
			_update_prompt_text()

	var controller_pressed: bool = (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B and event.pressed)
	var keyboard_pressed: bool = event.is_action_pressed("ui_accept") or (event is InputEventKey and event.keycode == KEY_E and event.pressed)

	if keyboard_pressed or controller_pressed:
		_started = true
		_begin()

func _update_prompt_text() -> void:
	if not _started:
		if InputManager.is_controller():
			Game.show_prompt("press B")
		else:
			Game.show_prompt("press E")

func _begin() -> void:
	Game.hide_prompt()
	await get_tree().create_timer(1.2).timeout
	_monitor.volume_db = -20.0
	_monitor.play()
	_start_ecg()
	
	get_tree().create_timer(4.2).timeout.connect(_flatline_ecg)
	await Game.say("Eli. Stay with me.", 1.0)
	await get_tree().create_timer(2.0).timeout
	await Game.say("...", 1.0)
	await get_tree().create_timer(1.6).timeout
	
	_fade_monitor_out()
	_fade_ecg_out(1.4)
	await Game.say("Only the rain, now.", 1.0)
	await get_tree().create_timer(0.8).timeout
	await Game.show_title_card("After", "Ubisoft Gamejam 2026", 3.2)
	await get_tree().create_timer(0.6).timeout
	Game.change_scene(HOUSE)

func _fade_monitor_out() -> void:
	if not _monitor.playing:
		return
	var t := create_tween()
	t.tween_property(_monitor, "volume_db", -80.0, 1.4)
	t.tween_callback(_monitor.stop)

func _build_ecg() -> void:
	_ecg_layer = CanvasLayer.new()
	_ecg_layer.layer = 101
	add_child(_ecg_layer)
	_ecg = Line2D.new()
	_ecg.width = 3.0
	_ecg.default_color = Color(0.45, 1.0, 0.55, 0.0)
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

func _ecg_value(d: float) -> float:
	if _ecg_flat:
		return 0.0
	var t: float = fmod(d, ECG_PERIOD) / ECG_PERIOD
	var y := 0.0
	y += 0.12 * exp(-pow((t - 0.30) / 0.030, 2.0))
	y -= 0.20 * exp(-pow((t - 0.46) / 0.012, 2.0))
	y += 1.00 * exp(-pow((t - 0.50) / 0.010, 2.0))
	y -= 0.35 * exp(-pow((t - 0.54) / 0.014, 2.0))
	y += 0.22 * exp(-pow((t - 0.68) / 0.040, 2.0))
	return y
