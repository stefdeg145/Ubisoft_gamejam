extends Node2D
## Phase 0 — the cold open. Pure black, a heartbeat the player can almost feel,
## one line, then a flatline. No title, no menu. The first scene the game loads.

const HOUSE := "res://scenes/house/house.tscn"
var _started := false

func _ready() -> void:
	Game.set_black(true)
	Game.hide_prompt()
	await get_tree().create_timer(1.0).timeout
	Game.show_prompt("press any key")

func _unhandled_input(event: InputEvent) -> void:
	if _started:
		return
	if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		_started = true
		_begin()

func _begin() -> void:
	Game.hide_prompt()
	await get_tree().create_timer(1.2).timeout
	await Game.say("Stay with me.", 3.2)
	await get_tree().create_timer(2.0).timeout          # hold the black, uncomfortably long
	await Game.say("...", 1.6)                            # the line goes flat
	await get_tree().create_timer(1.6).timeout
	await Game.say("Only the rain, now.", 2.6)
	await get_tree().create_timer(0.8).timeout
	Game.change_scene(HOUSE)
