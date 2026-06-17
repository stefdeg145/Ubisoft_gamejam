extends Node
## Drives the entry into the BARGAINING stage from inside the house, kept fully
## self-contained so it never touches the rest of the house logic.
##
## Flow:
##   1. Once the Anger bleed resolves, house.gd calls begin_mission() on this node.
##      (INSERT still force-starts it for testing.)
##   2. A small objective popup slides in: sit on the couch and look at their photo.
##   3. When the player walks up to the couch (the one facing the TV), a pulsing
##      "Press E to sit" prompt appears. Pressing E sits him down.
##   4. He takes out the photograph — a framed close-up fades in — and reflects
##      (a Dialogic timeline). The room then warms and washes out in a distinct
##      "look-back" transition into the park memory (stage_bargaining.tscn).
##
## Add one of these as a child of the house (house.gd does this) and it does the
## rest. It only acts once begin_mission() is called, so it never interferes with
## normal play before then.

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
var _photo_layer: CanvasLayer

const PHOTO_TEX := "res://assets/art/props/photo.png"

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
	# INSERT force-starts the mission (dev shortcut; normally house.gd starts it).
	if not _started and event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_INSERT:
		begin_mission()
		get_viewport().set_input_as_handled()
		return

	# E near the couch sits him down. Consume it so the couch's normal
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
			Game.show_prompt("Press E to sit")
		else:
			Game.hide_prompt()

# ----------------------------------------------------------------- mission
## Called by house.gd once the Anger bleed resolves (or by INSERT for testing).
func begin_mission() -> void:
	if _started:
		return
	_started = true
	_find_player()
	if _player and "can_move" in _player:
		_player.can_move = true        # make sure they can walk to the couch
	_show_mission()

func _show_mission() -> void:
	_popup = ObjectivePopup.new()
	add_child(_popup)
	_popup.show_objective("NEW OBJECTIVE",
		"Sit on the couch facing the TV and look at the photograph of the two of you.")

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
		_player.face("up")            # sit facing the TV
	_hide_mission()

	await Game.say("Maybe just sit for a minute.", 2.6)
	await Game.say("...I still carry it everywhere. Let me look.", 2.8)

	# He takes out the photograph — a framed close-up of the two of them.
	await _show_photo_closeup()

	Dialogic.start(_load_timeline(COUCH_TIMELINE))
	await Dialogic.timeline_ended

	# Distinct "look-back" transition: the room warms and washes out, like slipping
	# into the memory (rather than the sleep/vignette used elsewhere).
	await _memory_look_back()
	Game.change_scene(PARK_SCENE)

# ----------------------------------------------------------------- photo + transition
func _show_photo_closeup() -> void:
	_photo_layer = CanvasLayer.new()
	_photo_layer.layer = 30           # above the world, below Game's captions (100)
	add_child(_photo_layer)

	# dim the room behind the photo
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo_layer.add_child(dim)

	var vs: Vector2 = get_viewport().get_visible_rect().size
	# a cream photo "frame" (polaroid-ish), centred and slightly raised
	var frame := Panel.new()
	var fw := 384.0
	var fh := 336.0
	frame.size = Vector2(fw, fh)
	frame.position = Vector2((vs.x - fw) * 0.5, (vs.y - fh) * 0.5 - 20.0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.95, 0.93, 0.86)
	box.set_corner_radius_all(2)
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = 16
	frame.add_theme_stylebox_override("panel", box)
	frame.pivot_offset = Vector2(fw, fh) * 0.5
	frame.scale = Vector2(0.96, 0.96)
	frame.modulate.a = 0.0
	_photo_layer.add_child(frame)

	# the photo itself, scaled up with nearest filter (intentionally pixel)
	var photo := TextureRect.new()
	photo.texture = load(PHOTO_TEX)
	photo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.position = Vector2(24, 24)
	photo.size = Vector2(fw - 48, fh - 96)   # leave a wider matte at the bottom
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(photo)

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(dim, "color:a", 0.72, 0.9)
	t.tween_property(frame, "modulate:a", 1.0, 0.9)
	t.tween_property(frame, "scale", Vector2(1.0, 1.0), 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished

func _memory_look_back() -> void:
	if _photo_layer == null or not is_instance_valid(_photo_layer):
		await Game.fade_out(1.2)
		return
	await Game.say("If I'd said it differently... maybe.", 2.6)
	# warm sepia wash over the held photo, as the present dissolves into the memory
	var warm := ColorRect.new()
	warm.color = Color(0.86, 0.72, 0.46, 0.0)
	warm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo_layer.add_child(warm)
	var t := create_tween()
	t.tween_property(warm, "color:a", 0.95, 1.8)
	await t.finished
	await Game.fade_out(0.9)          # settle to black; the park scene wakes from here

## Build the timeline from the .dtl text directly (robust at runtime, while the
## files stay editable in the Dialogic editor).
func _load_timeline(path: String) -> DialogicTimeline:
	var tl := DialogicTimeline.new()
	var f := FileAccess.open(path, FileAccess.READ)
	if f:
		tl.from_text(f.get_as_text())
		f.close()
	return tl
