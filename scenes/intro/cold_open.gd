extends Node2D
## Phase 0 — the cold open. Pure black, a heartbeat the player can almost feel,
## one line, then a flatline. No title, no menu. The first scene the game loads.

const HOUSE := "res://scenes/house/house.tscn"
const MONITOR := preload("res://assets/Sound/Heartbeat flatline sound HD.mp3")
## The clip runs ~4s of steady heartbeat, then a sustained flatline tone from ~4.2s.
## Starting it as the line begins lands the flatline exactly as "Stay with me" fades.

var _started := false
var _monitor: AudioStreamPlayer

func _ready() -> void:
	Game.set_black(true)
	Game.hide_prompt()
	_monitor = AudioStreamPlayer.new()
	_monitor.stream = MONITOR
	_monitor.bus = "Master"
	add_child(_monitor)
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
	_monitor.play()                                      # steady heartbeat under the line...
	await Game.say("Stay with me.", 3.2)
	await get_tree().create_timer(2.0).timeout          # ...the monitor flatlines, held too long
	await Game.say("...", 1.6)                            # the line goes flat
	await get_tree().create_timer(1.6).timeout
	_fade_monitor_out()                                  # the tone gives way to the rain
	await Game.say("Only the rain, now.", 2.6)
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
