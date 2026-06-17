extends Node
## STAGE 4 — DEPRESSION · "The Weight", played INSIDE the house (no scene change).
##
## house.gd starts this when the player returns from Bargaining. He surfaces still
## on the living-room couch, too heavy to move — trying to walk only aches. The one
## thing in reach is Eli's phone on the coffee table; replaying the voicemail sinks
## the room darker each time, until one ordinary line — "...get some rest, okay?
## Love you" — finally lands as permission. He stands, a warm glow waits at the
## front door, he crosses the dark house to it, opens it, and the morning light
## floods in — the rain has stopped — blooming into the Acceptance morning. No bed,
## no clever fix: you don't solve depression, you survive it and let one small
## kindness move you toward the door.

const FX := "res://assets/art/fx/"
const ACCEPTANCE_SCENE := "res://scenes/stages/stage_acceptance.tscn"

var player: CharacterBody2D
var world: Node2D
var house: Node

# world-space anchors (house coordinates)
var _phone_point := Vector2(640, 530)     # ON the coffee table surface in front of the couch
var _door_point := Vector2(470, 600)      # floor spot in front of the front door
var _glow_point := Vector2(470, 632)      # the warm morning light spilling in at the door

var _layer: CanvasLayer
var _dark: ColorRect
var _dawn: ColorRect
var _vig: TextureRect
var _rain_tex: TextureRect
var _glow: Sprite2D
var _phone_sp: Sprite2D
var _phone_glow: Sprite2D
var _pill: Label

var _plays := 0
var _busy := false        # a voicemail line is playing; ignore further input
var _can_rise := false    # the "get some rest" beat has freed him to stand
var _ending := false      # the door-opening / dawn bloom has begun
var _ache_until := 0.0    # throttle the "I can't get up" lines

func setup(p_player: CharacterBody2D, p_world: Node2D, p_house: Node) -> void:
	player = p_player
	world = p_world
	house = p_house

func start() -> void:
	_build_overlays()
	if player:
		player.can_move = false
		player.speed = 46.0                   # heavy, slow shuffle once he can move

	await Game.wake(2.0)
	await Game.say("...Oh. The park's gone. I'm still on the couch.", 3.0)
	await Game.say("It got dark. I don't know how long I sat here.", 3.2)
	await Game.say("I should get up. ...In a minute.", 3.0)

	_add_phone()

# ------------------------------------------------------------------ build
func _build_overlays() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 7                          # over the world + house rain, under captions
	house.add_child(_layer)

	_rain_tex = TextureRect.new()
	_rain_tex.texture = load(FX + "rain.png")
	_rain_tex.stretch_mode = TextureRect.STRETCH_TILE
	_rain_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rain_tex.modulate = Color(1, 1, 1, 0.16)
	_rain_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_rain_tex)

	_dark = ColorRect.new(); _dark.color = Color(0.02, 0.02, 0.06, 0.4)
	_dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_dark)

	_vig = TextureRect.new(); _vig.texture = load(FX + "vignette.png")
	_vig.stretch_mode = TextureRect.STRETCH_SCALE
	_vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vig.modulate = Color(1, 1, 1, 0.5)
	_vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_vig)

	# the dawn light that blooms at the very end (above everything)
	var cl2 := CanvasLayer.new(); cl2.layer = 9; house.add_child(cl2)
	_dawn = ColorRect.new(); _dawn.color = Color(1.0, 0.97, 0.9, 0.0)
	_dawn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl2.add_child(_dawn)

func _add_phone() -> void:
	# warm halo so the phone is the one findable thing in the dark room
	_phone_glow = Sprite2D.new()
	_phone_glow.texture = load(FX + "glow_warm.png")
	_phone_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_phone_glow.position = _phone_point
	_phone_glow.scale = Vector2(1.5, 1.5)
	_phone_glow.z_index = 38
	_phone_glow.modulate = Color(1, 1, 1, 0.9)
	world.add_child(_phone_glow)

	# the phone itself (stand-in art — swap whenever), kept bright so it reads
	_phone_sp = Sprite2D.new()
	_phone_sp.texture = load("res://assets/art/props/record.png")
	_phone_sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_phone_sp.position = _phone_point
	_phone_sp.scale = Vector2(1.5, 1.5)
	_phone_sp.z_index = 40
	_phone_sp.modulate = Color(0.96, 0.97, 1.0)
	world.add_child(_phone_sp)

	# a bobbing "E" pill on the table + a persistent on-screen prompt
	_make_pill()
	Game.show_prompt("Eli's old voicemail — press E")

func _make_pill() -> void:
	_pill = Label.new()
	_pill.text = "E"
	_pill.z_index = 60
	_pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pill.add_theme_font_size_override("font_size", 18)
	_pill.add_theme_color_override("font_color", Color(0.97, 0.95, 0.86))
	_pill.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_pill.add_theme_constant_override("shadow_offset_x", 1)
	_pill.add_theme_constant_override("shadow_offset_y", 1)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.1, 0.12, 0.85)
	box.set_corner_radius_all(5)
	box.content_margin_left = 7; box.content_margin_right = 7
	box.content_margin_top = 3; box.content_margin_bottom = 3
	_pill.add_theme_stylebox_override("normal", box)
	world.add_child(_pill)
	_pill.position = _phone_point + Vector2(-9, -56)
	var by := _pill.position.y
	var t := create_tween().set_loops()
	t.tween_property(_pill, "position:y", by - 5.0, 0.6).set_trans(Tween.TRANS_SINE)
	t.tween_property(_pill, "position:y", by, 0.6).set_trans(Tween.TRANS_SINE)

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
			await Game.say("Eli's voicemail. Months old — from back when they'd still call about nothing.", 3.8)
			await Game.say("Eli: \"Hey, it's me — forgot my charger again. Figures.\"", 3.4)
			await Game.say("Eli: \"Don't wait up. Get some rest, okay? ...Love you.\"", 3.8)
			await Game.say("...I'll play it again.", 2.4)
			_darken(0.58)
			Game.show_prompt("Play it again — press E")
			_busy = false
		2:
			await Game.say("Eli: \"...Get some rest, okay? ...Love you.\"", 3.4)
			await Game.say("...Again.", 2.0)
			_darken(0.74)
			Game.show_prompt("Play it again — press E")
			_busy = false
		_:
			await Game.say("Eli: \"...Get some rest.\"", 2.8)
			await Game.say("They're not asking me to do anything. Just... rest.", 3.6)
			await Game.say("...Okay. Okay. I hear you.", 3.0)
			await _allow_rise()
			_busy = false

func _darken(to: float, dur := 1.4) -> void:
	create_tween().tween_property(_dark, "color:a", to, dur)
	create_tween().tween_property(_vig, "modulate:a", min(1.0, to + 0.25), dur)

func _allow_rise() -> void:
	_can_rise = true
	Game.hide_prompt()
	if _pill and is_instance_valid(_pill):
		_pill.queue_free()
	if _phone_glow and is_instance_valid(_phone_glow):
		create_tween().tween_property(_phone_glow, "modulate:a", 0.0, 1.0)
	if _phone_sp and is_instance_valid(_phone_sp):
		create_tween().tween_property(_phone_sp, "modulate:a", 0.25, 1.2)
	# the front door becomes the one warm thing in the room — a thread of morning
	# light under it, the way out of the long night
	_glow = Sprite2D.new()
	_glow.texture = load(FX + "glow_warm.png")
	_glow.position = _glow_point
	_glow.scale = Vector2(2.6, 2.6)
	_glow.modulate = Color(1, 1, 1, 0.0)
	_glow.z_index = 2
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.add_child(_glow)
	create_tween().tween_property(_glow, "modulate:a", 0.85, 1.6)
	await Game.say("...Up. Just — up.", 2.6)
	if player:
		player.can_move = true
	Game.show_prompt("Go to the front door")

# ------------------------------------------------------------------ the door
func _process(_dt: float) -> void:
	if _ending or not _can_rise or player == null:
		return
	if player.global_position.distance_to(_door_point) < 64.0:
		_to_door()

func _to_door() -> void:
	_ending = true
	if player:
		player.can_move = false
		player.face("down")
	Game.hide_prompt()
	await Game.say("The front door. I haven't opened it in days.", 3.2)
	await Game.say("...Okay. Let's just open it.", 2.6)
	# the door opens: morning floods in, the dark lifts, the rain finally stops, and
	# the held breath of the night exhales
	var t := create_tween(); t.set_parallel(true)
	t.tween_property(_rain_tex, "modulate:a", 0.0, 3.0)
	t.tween_property(_dark, "color:a", 0.0, 3.0)
	t.tween_property(_vig, "modulate:a", 0.12, 3.0)
	if _glow:
		t.tween_property(_glow, "scale", Vector2(5.5, 5.5), 2.6)
		t.tween_property(_glow, "modulate:a", 1.0, 1.6)
	await t.finished
	await Game.say("...Morning. The rain's stopped.", 2.6)
	# bloom to soft dawn light — this becomes the Acceptance morning
	var w := create_tween()
	w.tween_property(_dawn, "color:a", 1.0, 2.8)
	await w.finished
	GameState.complete_stage("Depression", "the depth — all the way down, and the morning still came.")
	Game.change_scene(ACCEPTANCE_SCENE)
