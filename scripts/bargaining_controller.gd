extends Node
## Drives the entry into the BARGAINING stage from inside the house, kept fully
## self-contained so it never touches the rest of the house logic.
##
## Flow:
##   1. The anger inter-level isn't built yet, so INSERT stands in for "anger just
##      finished". Pressing INSERT (once, while in the house) begins the mission.
##   2. A small objective popup slides in at the top-right: rest on the couch.
##   3. When the player walks up to the couch, a pulsing "Press E to rest" prompt
##      appears. Pressing E starts the couch self-talk (a Dialogic timeline).
##   4. When that dialogue ends, the screen drifts to sleep and we transition into
##      the park flashback scene (stage_bargaining.tscn).
##
## Add one of these as a child of the house (house.gd does this) and it does the
## rest. It only ever acts after F1, so it can't interfere with normal play.

const COUCH_TIMELINE := "res://dialogic/timelines/bargaining_couch.dtl"
const PARK_SCENE := "res://scenes/stages/stage_bargaining.tscn"

const COUCH_FALLBACK := Vector2(640, 600)
const NEAR_RADIUS := 84.0

var _started := false          # mission begun (F1 pressed)
var _resting := false          # couch sequence running / done
var _near := false
var _couch_point := COUCH_FALLBACK

var _player: Node2D
var _popup: ObjectivePopup

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Locate the couch in the house so the rest-point is exact (fallback if not).
	var couch := get_parent().get_node_or_null("World/Couch")
	if couch and couch is Node2D:
		_couch_point = (couch as Node2D).global_position + Vector2(0, -8)

func _find_player() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

# ----------------------------------------------------------------- input
func _input(event: InputEvent) -> void:
	# INSERT stands in for "anger finished" -> start the bargaining mission once.
	if not _started and event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_INSERT:
		_begin_mission()
		get_viewport().set_input_as_handled()
		return

	# E near the couch starts the rest dialogue. Consume it so the couch's normal
	# "too tired" line doesn't also fire.
	if _started and not _resting and _near and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_rest_on_couch()

func _process(_delta: float) -> void:
	if not _started or _resting:
		return
	_find_player()
	if _player == null:
		return
	var near := _player.global_position.distance_to(_couch_point) <= NEAR_RADIUS
	if near != _near:
		_near = near
		if _near:
			Game.show_prompt("Press E to rest")
		else:
			Game.hide_prompt()

# ----------------------------------------------------------------- mission
func _begin_mission() -> void:
	_started = true
	_find_player()
	if _player and "can_move" in _player:
		_player.can_move = true        # make sure they can walk to the couch
	_show_mission()

func _show_mission() -> void:
	_popup = ObjectivePopup.new()
	add_child(_popup)
	_popup.show_objective("NEW OBJECTIVE", "You're exhausted. Rest on the couch in the living room.")

func _hide_mission() -> void:
	if _popup:
		_popup.dismiss()
		_popup = null

# ----------------------------------------------------------------- couch
func _rest_on_couch() -> void:
	_resting = true
	_near = false
	Game.hide_prompt()
	_find_player()
	if _player and "can_move" in _player:
		_player.can_move = false
	if _player and _player.has_method("face"):
		_player.face("up")            # turn toward the couch
	_hide_mission()

	await Game.say("Maybe just sit for a minute. Close my eyes.", 2.8)

	Dialogic.start(_load_timeline(COUCH_TIMELINE))
	await Dialogic.timeline_ended

	await Game.drift_to_sleep(2.2)
	Game.change_scene(PARK_SCENE)

## Build the timeline from the .dtl text directly (robust at runtime, while the
## files stay editable in the Dialogic editor).
func _load_timeline(path: String) -> DialogicTimeline:
	var tl := DialogicTimeline.new()
	var f := FileAccess.open(path, FileAccess.READ)
	if f:
		tl.from_text(f.get_as_text())
		f.close()
	return tl
