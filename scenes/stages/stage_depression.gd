extends StageBase
## STAGE 4 — DEPRESSION · "The Weight" (top-down living room, dusk into night).
##
## He surfaces from the Bargaining flashback STILL ON THE COUCH — it's gone dark
## and he hasn't moved. The stage is the inability to GET UP, not to sleep, so the
## "just woke / now sleeping" logic problem disappears. He's pinned to the couch;
## trying to walk only aches. The one thing in reach is Eli's phone on the coffee
## table, and replaying the voicemail sinks the room darker each time — until one
## ordinary line, "...get some rest, okay? Love you," finally lands as permission.
## He stands, a warm glow waits at the window (the same window from the cold open),
## he crosses to it, the rain eases, and the growing light blooms into the
## Acceptance morning. No bed, no clever fix: you don't solve depression, you
## survive it and let one small kindness move you.

const FX := "res://assets/art/fx/"
const HOUSE := "res://assets/art/house/"
const RAIN_BED := "res://assets/Sound/Oldies Playing In Another Room  with Gentle Rain and Thunder (V.1).mp3"
const ACCEPTANCE_SCENE := "res://scenes/stages/stage_acceptance.tscn"

# the little nook he can shuffle in once he can finally move
const ROOM := Rect2(360, 140, 576, 448)

var _win_pos := Vector2(640, 150)

var _dark: ColorRect
var _dawn: ColorRect
var _vig: TextureRect
var _rain_tex: TextureRect
var _rain_snd: AudioStreamPlayer
var _glow: Sprite2D
var _phone_sp: Sprite2D
var _cam: Camera2D

var _plays := 0
var _busy := false        # a voicemail line is playing; ignore further input
var _can_rise := false    # the "get some rest" beat has freed him to stand
var _ending := false      # the window dissolve has begun
var _ache_until := 0.0    # throttle the "I can't get up" lines

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_room()
	_build_overlays()
	_start_rain_bed()

	# he wakes sitting on the couch, facing the table + window; can't move yet
	spawn_player(Vector2(640, 452))
	player.face("up")
	player.speed = 46.0                       # heavy, slow shuffle once he can move
	var pcam := player.get_node_or_null("Camera2D")
	if pcam is Camera2D:
		(pcam as Camera2D).enabled = false    # use the stationary stage camera
	_build_camera()

	await Game.wake(2.0)
	await Game.say("...Oh. The park's gone. I'm still on the couch.", 3.0)
	await Game.say("It got dark. I don't know how long I sat here.", 3.2)
	await Game.say("I should get up. ...In a minute.", 3.0)

	_add_phone()
	Game.flash("Eli's phone is on the table. (E)", 3.2)

# ------------------------------------------------------------------ build
func _build_room() -> void:
	var floors := Node2D.new(); add_child(floors)
	var wood: Texture2D = load(HOUSE + "floor_wood.png")
	for ix in range(9):
		for iy in range(7):
			var sp := Sprite2D.new()
			sp.texture = wood; sp.centered = false
			sp.position = Vector2(360 + ix * 64, 140 + iy * 64)
			sp.scale = Vector2(2, 2)
			sp.modulate = Color(0.42, 0.43, 0.52)
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			floors.add_child(sp)

	# north wall + the window he'll cross to
	var wall := ColorRect.new()
	wall.color = Color(0.15, 0.15, 0.19)
	wall.position = Vector2(360, 96); wall.size = Vector2(576, 48)
	add_child(wall)
	var win := Sprite2D.new()
	win.texture = load(HOUSE + "wall_window.png")
	win.centered = true
	win.position = _win_pos
	win.scale = Vector2(2.6, 2.2)
	win.modulate = Color(0.5, 0.52, 0.62)
	win.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(win)

	# couch (he's on it) + coffee table in front
	_dim(HOUSE + "couch.png", 640, 540, 2.2)
	_dim(HOUSE + "coffee_table.png", 640, 392, 2.0)

	# bounds — he can only move within the nook
	_wall(ROOM.position.x - 24, ROOM.position.y, 24, ROOM.size.y)
	_wall(ROOM.end.x, ROOM.position.y, 24, ROOM.size.y)
	_wall(ROOM.position.x, ROOM.position.y - 24, ROOM.size.x, 24)
	_wall(ROOM.position.x, ROOM.end.y, ROOM.size.x, 24)

func _dim(path: String, x: float, y: float, s: float) -> Sprite2D:
	var tex: Texture2D = load(path)
	var sp := Sprite2D.new()
	sp.texture = tex; sp.centered = false
	sp.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
	sp.position = Vector2(x, y); sp.scale = Vector2(s, s)
	sp.modulate = Color(0.5, 0.5, 0.6)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)
	return sp

func _add_phone() -> void:
	# small stand-in device on the coffee table (swap the art whenever)
	_phone_sp = _dim("res://assets/art/props/record.png", 640, 372, 1.1)
	_phone_sp.modulate = Color(0.72, 0.74, 0.88)

func _build_overlays() -> void:
	var cl := CanvasLayer.new(); cl.layer = 8; add_child(cl)

	_rain_tex = TextureRect.new()
	_rain_tex.texture = load(FX + "rain.png")
	_rain_tex.stretch_mode = TextureRect.STRETCH_TILE
	_rain_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rain_tex.modulate = Color(1, 1, 1, 0.12)
	_rain_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_rain_tex)

	_dark = ColorRect.new(); _dark.color = Color(0.02, 0.02, 0.06, 0.45)
	_dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_dark)

	_vig = TextureRect.new(); _vig.texture = load(FX + "vignette.png")
	_vig.stretch_mode = TextureRect.STRETCH_SCALE
	_vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vig.modulate = Color(1, 1, 1, 0.5)
	_vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_vig)

	# the dawn light that blooms at the very end (above everything)
	var cl2 := CanvasLayer.new(); cl2.layer = 9; add_child(cl2)
	_dawn = ColorRect.new(); _dawn.color = Color(1.0, 0.97, 0.9, 0.0)
	_dawn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl2.add_child(_dawn)

func _build_camera() -> void:
	_cam = Camera2D.new()
	_cam.position = Vector2(640, 360)
	_cam.zoom = Vector2(1, 1)
	add_child(_cam)
	_cam.make_current()

func _start_rain_bed() -> void:
	_rain_snd = AudioStreamPlayer.new()
	var s = load(RAIN_BED)
	if s is AudioStreamMP3:
		s.loop = true
	_rain_snd.stream = s
	_rain_snd.volume_db = -20.0
	add_child(_rain_snd)
	_rain_snd.play()

# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if _busy or _ending:
		return
	if not _can_rise:
		# pinned to the couch: E plays the voicemail, trying to walk only aches
		if event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			_play_voicemail()
		elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") \
				or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			_ache()

func _ache() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _ache_until:
		return
	_ache_until = now + 3.0
	var lines := ["...I can't. Not yet.", "My legs won't.", "...In a minute."]
	Game.flash(lines[randi() % lines.size()], 2.2)

# ------------------------------------------------------------------ voicemail
func _play_voicemail() -> void:
	if _busy or _can_rise:
		return
	_busy = true
	Game.hide_prompt()
	_plays += 1
	match _plays:
		1:
			await Game.say("\"Hey, it's me — forgot my charger again. Figures.\"", 3.2)
			await Game.say("\"Don't wait up. Get some rest, okay? ...Love you.\"", 3.6)
			await Game.say("...I'll play it again.", 2.4)
			_darken(0.6)
			Game.flash("Play it again. (E)", 2.6)
			_busy = false
		2:
			await Game.say("\"...Get some rest, okay? ...Love you.\"", 3.2)
			await Game.say("...Again.", 2.0)
			_darken(0.76)
			Game.flash("Play it again. (E)", 2.6)
			_busy = false
		_:
			await Game.say("\"...Get some rest.\"", 2.6)
			await Game.say("They're not asking me to do anything. Just... rest.", 3.6)
			await Game.say("...Okay. Okay. I hear you.", 3.0)
			await _allow_rise()
			_busy = false

func _darken(to: float, dur := 1.4) -> void:
	create_tween().tween_property(_dark, "color:a", to, dur)
	create_tween().tween_property(_vig, "modulate:a", min(1.0, to + 0.25), dur)

func _allow_rise() -> void:
	_can_rise = true
	if _phone_sp and is_instance_valid(_phone_sp):
		create_tween().tween_property(_phone_sp, "modulate:a", 0.25, 1.2)
	# the window becomes the one warm thing in the room
	_glow = Sprite2D.new()
	_glow.texture = load(FX + "glow_warm.png")
	_glow.position = _win_pos
	_glow.scale = Vector2(2.4, 2.4)
	_glow.modulate = Color(1, 1, 1, 0.0)
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_glow)
	create_tween().tween_property(_glow, "modulate:a", 0.85, 1.6)
	await Game.say("...Up. Just — up.", 2.6)
	player.can_move = true
	Game.flash("Go to the window.", 3.0)

# ------------------------------------------------------------------ the window
func _process(_dt: float) -> void:
	if _ending or not _can_rise or player == null:
		return
	if player.global_position.distance_to(_win_pos) < 96.0:
		_to_window()

func _to_window() -> void:
	_ending = true
	player.can_move = false
	player.face("up")
	Game.hide_prompt()
	await Game.say("The rain. ...It's letting up.", 3.0)
	# rain eases, the dark lifts, the held breath of the night finally exhales
	var t := create_tween(); t.set_parallel(true)
	t.tween_property(_rain_tex, "modulate:a", 0.0, 3.0)
	t.tween_property(_dark, "color:a", 0.0, 3.0)
	t.tween_property(_vig, "modulate:a", 0.15, 3.0)
	if _glow:
		t.tween_property(_glow, "modulate:a", 0.0, 2.0)
	if _rain_snd:
		t.tween_property(_rain_snd, "volume_db", -50.0, 3.0)
	await t.finished
	await Game.say("...Morning.", 2.4)
	# bloom to soft dawn light — this becomes the Acceptance morning
	var w := create_tween()
	w.tween_property(_dawn, "color:a", 1.0, 2.8)
	await w.finished
	if _rain_snd:
		_rain_snd.stop()
	GameState.complete_stage("Depression", "the depth — all the way down, and the morning still came.")
	Game.change_scene(ACCEPTANCE_SCENE)
