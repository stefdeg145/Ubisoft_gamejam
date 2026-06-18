extends StageBase
## FINAL — ACCEPTANCE · "The Last Morning" (reworked).
##
## No dream, no goodbye scene, no monitor flatline. For the first time in the
## whole game the player is simply real and awake. They wake in the chair in a
## still-grey house, stand on their own, and cross to the FRONT DOOR — sealed all
## game. They open it themselves; warm morning light grows with the swing, floods
## the house back into colour, and carries them OUT into the same park from
## Bargaining — now a rain-washed morning instead of a grey argument, and the
## spot where the lost one (Eli) stood is empty. They stand in the absence, find
## it bearable, and walk on down the path into the morning. Theme: peace — not
## forgetting, not moving on, but carrying it and still opening the door.
##
## The game name appears AFTER the walk, as the final card.

const FX   := "res://assets/art/fx/"
const A    := "res://assets/art/house/"
const CH   := "res://assets/art/characters/"
const PROP := "res://assets/art/props/"
const PARK_BG  := "res://scenes/stages/Bargaining_bg.jpg"
const PARK_AMB := "res://assets/Sound/Park ambience sound  (Royalty Free).mp3"

# interior playable nook + the door on the north wall
const ROOM := Rect2(356, 176, 568, 428)
const DOOR_POS := Vector2(640, 150)
const SPOT_X := 940.0          # where Eli stood, on the right of the park frame

var _cam: Camera2D
var _interior: Node2D
var _park: Node2D
var _white: ColorRect          # warm-white bloom overlay (open + close)
var _door_glow: Sprite2D
var _amb: AudioStreamPlayer
var _greyed: Array[CanvasItem] = []    # interior props that flood to full colour

var _opening := false
var _park_active := false
var _spot_done := false
var _finale := false           # the very end; E restarts

# ---------------------------------------------------------------- ready
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Game.set_black(false)
	Game.hide_prompt()
	# keep the end-of-game prompt in sync with keyboard/controller
	InputManager.device_changed.connect(_on_device_changed)

	# one fixed camera for the whole level (interior + park line up to the screen)
	_cam = Camera2D.new()
	_cam.position = Vector2(640, 360)
	add_child(_cam)

	_build_white()
	_white.color.a = 1.0          # open straight out of the depression bloom

	_build_interior()

	# wake sitting in the chair; can't move yet
	spawn_player(Vector2(640, 520))
	player.face("up")
	player.speed = 64.0           # gentle, unhurried
	# disable the player's follow-cam, THEN claim the fixed stage camera (a newly
	# entered player camera would otherwise steal "current").
	var pcam := player.get_node_or_null("Camera2D")
	if pcam is Camera2D:
		(pcam as Camera2D).enabled = false
	_cam.make_current()

	_run_interior()

# ---------------------------------------------------------------- overlays
func _build_white() -> void:
	var cl := CanvasLayer.new(); cl.layer = 60; add_child(cl)
	_white = ColorRect.new()
	_white.color = Color(1.0, 0.97, 0.9, 0.0)
	_white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_white)

# ---------------------------------------------------------------- interior
func _build_interior() -> void:
	_interior = Node2D.new(); add_child(_interior)

	# greyish wood floor across the nook
	var wood: Texture2D = load(A + "floor_wood.png")
	for ix in range(9):
		for iy in range(8):
			var sp := Sprite2D.new()
			sp.texture = wood; sp.centered = false
			sp.position = Vector2(356 + ix * 64, 140 + iy * 64)
			sp.scale = Vector2(2, 2)
			sp.modulate = Color(0.5, 0.51, 0.6)
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_interior.add_child(sp)
			_greyed.append(sp)

	# north wall + the sealed front door
	var wall := ColorRect.new()
	wall.color = Color(0.15, 0.15, 0.19)
	wall.position = Vector2(356, 96); wall.size = Vector2(568, 56)
	_interior.add_child(wall); _greyed.append(wall)

	# warm glow behind the door (blooms when it opens)
	_door_glow = Sprite2D.new()
	_door_glow.texture = load(FX + "glow_warm.png")
	_door_glow.position = DOOR_POS
	_door_glow.scale = Vector2(2.2, 2.2)
	_door_glow.modulate = Color(1, 1, 1, 0.0)
	_door_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_interior.add_child(_door_glow)

	# door frame + panel (no door art in the pack — built from rects)
	var frame := ColorRect.new()
	frame.color = Color(0.12, 0.09, 0.07)
	frame.size = Vector2(118, 150); frame.position = DOOR_POS - frame.size * 0.5
	_interior.add_child(frame); _greyed.append(frame)
	var panel := ColorRect.new()
	panel.color = Color(0.34, 0.25, 0.18)
	panel.size = Vector2(96, 134); panel.position = DOOR_POS - panel.size * 0.5
	panel.modulate = Color(0.6, 0.6, 0.68)     # dimmed like the rest, floods later
	_interior.add_child(panel); _greyed.append(panel)
	var knob := ColorRect.new()
	knob.color = Color(0.75, 0.66, 0.4)
	knob.size = Vector2(8, 8); knob.position = DOOR_POS + Vector2(30, -2)
	_interior.add_child(knob); _greyed.append(knob)

	# a little life: armchair he wakes in + a plant
	_prop(_interior, A + "armchair.png", 640, 556, 2.2, Color(0.5, 0.5, 0.6))
	_prop(_interior, A + "plant.png", 420, 300, 2.0, Color(0.5, 0.52, 0.58))

	# bounds — keep him in the nook, reachable up to the door trigger
	_wall(ROOM.position.x - 24, ROOM.position.y, 24, ROOM.size.y)
	_wall(ROOM.end.x, ROOM.position.y, 24, ROOM.size.y)
	_wall(ROOM.position.x, ROOM.position.y - 24, ROOM.size.x, 24)
	_wall(ROOM.position.x, ROOM.end.y, ROOM.size.x, 24)

func _prop(parent: Node, tex: String, x: float, y: float, s: float, tint := Color(1, 1, 1)) -> Sprite2D:
	var t: Texture2D = load(tex)
	var sp := Sprite2D.new()
	sp.texture = t; sp.centered = false
	sp.offset = Vector2(-t.get_width() / 2.0, -t.get_height())
	sp.position = Vector2(x, y); sp.scale = Vector2(s, s)
	sp.modulate = tint
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(sp)
	if tint != Color(1, 1, 1):
		_greyed.append(sp)
	return sp

func _run_interior() -> void:
	await get_tree().create_timer(0.4).timeout
	await _tween_a(_white, 0.0, 3.2)               # reveal the still-grey room

	await Game.say("Morning. The real one, this time.", 3.0)
	await Game.say("The rain stopped in the night.", 2.8)
	await Game.say("...I can get up now.", 2.8)

	player.can_move = true
	# door becomes the one warm thing; faint glow + a trigger glued to it
	create_tween().tween_property(_door_glow, "modulate:a", 0.3, 1.6)
	var area := add_interactable(DOOR_POS.x, DOOR_POS.y + 80, 90, "Open the door. (E)")
	area.used.connect(_open_door)
	Game.flash("Go to the door.", 3.0)

# ---------------------------------------------------------------- the door
func _open_door(_who: Node = null) -> void:
	if _opening:
		return
	_opening = true
	player.can_move = false
	player.face("up")
	Game.hide_prompt()

	# birdsong begins to rise even before the door is fully open
	_start_ambience(-30.0)
	if _amb:
		create_tween().tween_property(_amb, "volume_db", -12.0, 3.0)

	await Game.say("...Okay.", 2.0)

	# light blooms with the swing; the house floods back into full colour
	create_tween().tween_property(_door_glow, "modulate:a", 1.0, 1.6)
	var flood := create_tween(); flood.set_parallel(true)
	for ci in _greyed:
		if is_instance_valid(ci):
			flood.tween_property(ci, "modulate", Color(1, 1, 1, 1), 2.2)
	await _tween_a(_white, 1.0, 2.6)               # warm wash carries us through
	await get_tree().create_timer(0.6).timeout
	_enter_park()

# ---------------------------------------------------------------- the park
func _enter_park() -> void:
	_interior.queue_free()

	_park = Node2D.new(); add_child(_park)
	# regraded morning park: the Bargaining backdrop, warm and bright, no vignette
	var cl := CanvasLayer.new(); cl.layer = -10; _park.add_child(cl)
	var bg := TextureRect.new()
	bg.texture = load(PARK_BG)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(1.0, 0.98, 0.92)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(bg)
	# soft warm morning haze
	var warm := ColorRect.new()
	warm.color = Color(1.0, 0.92, 0.74, 0.14)
	warm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(warm)

	# step into the morning at the left, facing right across the park
	player.position = Vector2(300, 545)
	player.scale = Vector2(1.3, 1.3)
	player.lock_vertical = true
	player.face("right")

	await _tween_a(_white, 0.0, 2.8)
	await Game.say("...Oh. It's the park.", 2.8)
	await Game.say("Where it happened.", 2.6)

	player.can_move = true
	Game.flash("Walk. (→)", 3.0)
	_park_active = true

func _process(_dt: float) -> void:
	if not _park_active or _spot_done or player == null:
		return
	if player.global_position.x > SPOT_X:
		_spot_done = true
		_spot_beat()

func _spot_beat() -> void:
	_park_active = false
	player.can_move = false
	player.face("right")
	Game.hide_prompt()
	await Game.say("Just grass now. A bench, and the light through the trees.", 3.6)
	await Game.say("...I can be here. It's okay.", 3.0)
	await _walk_away()

func _walk_away() -> void:
	# a single look back at the empty spot — staying, not fleeing
	player.face("left")
	await get_tree().create_timer(0.9).timeout
	await Game.say("Thank you. For all of it.", 3.0)

	# the morning is fully his now — the MC warms to full colour as he goes
	GameState.complete_stage("Acceptance", "the morning — you opened the door, and walked on.")

	player.face("right")
	player.lock_vertical = false
	player.auto_walk = Vector2(0.62, -0.26).normalized()    # away, into the distance

	var t := create_tween(); t.set_parallel(true)
	t.tween_property(player, "scale", Vector2(0.42, 0.42), 5.5)
	if _amb:
		t.tween_property(_amb, "volume_db", -6.0, 5.0)        # birdsong swells
	await get_tree().create_timer(4.0).timeout

	player.auto_walk = Vector2.ZERO
	player.can_move = false
	# a gentle golden haze — NOT a full white-out, so the title + park stay legible
	await _tween_a(_white, 0.38, 2.8)

	# the game name, AFTER the walk
	await get_tree().create_timer(0.6).timeout
	await Game.show_title("THE LAST MORNING", 3.5)
	await Game.say("thank you for staying.", 3.0)
	_finale = true
	_update_accept_prompt()

# ---------------------------------------------------------------- audio
func _start_ambience(db: float) -> void:
	if _amb or not ResourceLoader.exists(PARK_AMB):
		return
	_amb = AudioStreamPlayer.new()
	var s = load(PARK_AMB)
	if s is AudioStreamMP3:
		s.loop = true
	_amb.stream = s
	_amb.volume_db = db
	_amb.bus = "Master"
	add_child(_amb)
	_amb.play()

# ---------------------------------------------------------------- helpers
func _tween_a(node: CanvasItem, to: float, dur: float) -> void:
	var t := create_tween()
	if node is ColorRect:
		t.tween_property(node, "color:a", to, dur)
	else:
		t.tween_property(node, "modulate:a", to, dur)
	await t.finished

func _update_accept_prompt() -> void:
	if InputManager.is_controller():
		Game.show_prompt("press", "A")
	else:
		Game.show_prompt("press E")

func _on_device_changed(_device: String) -> void:
	if _finale:
		_update_accept_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if not _finale:
		return
	if event.is_action_pressed("ui_accept"):
		_finale = false
		Game.hide_prompt()
		if _amb:
			create_tween().tween_property(_amb, "volume_db", -50.0, 1.0)
		GameState.reset()
		await Game.fade_out(1.2)
		Game.change_scene("res://scenes/intro/cold_open.tscn")
