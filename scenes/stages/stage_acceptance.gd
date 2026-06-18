extends StageBase
## FINAL — ACCEPTANCE · "The Last Morning" (reworked v2).
##
## The house already plays the door-opening animation when the player leaves, so
## this level begins OUTSIDE. No dream, no goodbye scene, no monitor flatline —
## for the first time the player is simply real and awake, walking out into a
## rain-washed morning.
##
## Flow:
##   PATH  — a path leading away from the house (house still in view). The player
##           walks to the right edge of the frame...
##   PARK  — ...and arrives at the same park from Bargaining, now a calm morning
##           instead of a grey argument. The spot where Eli stood is empty. They
##           stand in the absence, find it bearable, and walk on down the path
##           into the light. The game name appears AFTER the walk.
##
## Theme: peace — not forgetting, not moving on, but carrying it and still
## walking out the door.

const PARK_BG  := "res://scenes/stages/Bargaining_bg.jpg"
## Drop your in-between art here (1280x720). Until it exists, a placeholder
## morning is drawn so the flow is fully playable.
const PATH_BG  := "res://assets/art/bg/path_to_park.png"
const PARK_AMB := "res://assets/Sound/Park ambience sound  (Royalty Free).mp3"

# feet sit ON the walkable strip — the two backdrops have different ground lines
const PATH_GROUND_Y := 620.0
const PARK_GROUND_Y := 645.0
const MC_SCALE   := Vector2(3.0, 3.0)        # readable character size
const PATH_SPAWN := Vector2(260, PATH_GROUND_Y)   # start at the house, on the left
const PATH_MIN_X := 120.0
const PARK_SPAWN := Vector2(300, PARK_GROUND_Y)
const SPOT_X     := 940.0       # where Eli stood, right of the park frame
const HALF_VIEW  := 640.0       # half the 1280-wide viewport (camera clamp)

var _path_width := 1280.0       # world width of the path backdrop (set on build)

var _cam: Camera2D
var _path: Node2D
var _park: Node2D
var _white: ColorRect           # warm morning-light overlay (transitions + close)
var _amb: AudioStreamPlayer

var _phase := ""                # "path" | "park" | "" (busy / done)
var _finale := false            # the very end; E restarts

# ---------------------------------------------------------------- ready
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Game.set_black(true)        # we arrive from the house's drift-to-black
	Game.hide_prompt()
	InputManager.device_changed.connect(_on_device_changed)

	# one fixed camera so the screen-space backdrops line up with world coords
	_cam = Camera2D.new()
	_cam.position = Vector2(640, 360)
	add_child(_cam)

	_build_white()

	spawn_player(PATH_SPAWN)
	player.scale = MC_SCALE
	player.speed = 64.0          # gentle, unhurried
	player.lock_vertical = true  # side-on walk
	player.face("right")
	var pcam := player.get_node_or_null("Camera2D")
	if pcam is Camera2D:
		(pcam as Camera2D).enabled = false
	_cam.make_current()

	_build_path()
	_start_ambience(-28.0)
	_run_path()

# ---------------------------------------------------------------- overlays
func _build_white() -> void:
	var cl := CanvasLayer.new(); cl.layer = 60; add_child(cl)
	_white = ColorRect.new()
	_white.color = Color(1.0, 0.97, 0.9, 0.0)
	_white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_white)

# ---------------------------------------------------------------- the path
func _build_path() -> void:
	_path = Node2D.new(); add_child(_path)
	# World-space backdrop so the camera can SCROLL across it (the house slides
	# out of view as you walk right). Scaled to fill the 720px height; its world
	# width becomes the level length.
	if ResourceLoader.exists(PATH_BG):
		var tex: Texture2D = load(PATH_BG)
		var s := 720.0 / float(max(1, tex.get_height()))
		var bg := Sprite2D.new()
		bg.texture = tex
		bg.centered = false
		bg.position = Vector2(0, 0)
		bg.scale = Vector2(s, s)
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bg.z_index = -100
		_path.add_child(bg)
		_path_width = float(tex.get_width()) * s
	else:
		_path_width = 2600.0
		_build_path_placeholder()

## A wide stand-in morning so the scroll is playable before the art exists:
## warm sky, long green ground + dirt path, and a little house on the far left.
func _build_path_placeholder() -> void:
	var sky := ColorRect.new()
	sky.color = Color(0.85, 0.88, 0.95)
	sky.position = Vector2(0, 0); sky.size = Vector2(_path_width, 720)
	sky.z_index = -100; _path.add_child(sky)
	var ground := ColorRect.new()
	ground.color = Color(0.46, 0.55, 0.34)
	ground.position = Vector2(0, 470); ground.size = Vector2(_path_width, 250)
	ground.z_index = -99; _path.add_child(ground)
	# one straight horizontal dirt path running the whole width
	var path_band := ColorRect.new()
	path_band.color = Color(0.62, 0.52, 0.38)
	path_band.position = Vector2(0, 600); path_band.size = Vector2(_path_width, 70)
	path_band.z_index = -98; _path.add_child(path_band)
	# the house we played in, on the far left (flat side elevation)
	var house := ColorRect.new()
	house.color = Color(0.40, 0.33, 0.30)
	house.position = Vector2(80, 380); house.size = Vector2(200, 150)
	house.z_index = -97; _path.add_child(house)
	var roof := Polygon2D.new()
	roof.polygon = PackedVector2Array([
		Vector2(60, 380), Vector2(180, 305), Vector2(300, 380)])
	roof.color = Color(0.30, 0.22, 0.20)
	roof.z_index = -97; _path.add_child(roof)
	var note := Label.new()
	note.text = "(placeholder path — drop path_to_park.png in assets/art/bg/)"
	note.position = Vector2(360, 40)
	note.add_theme_color_override("font_color", Color(0.2, 0.2, 0.25))
	_path.add_child(note)

func _run_path() -> void:
	await Game.fade_in(2.5)        # reveal the morning from black
	if _amb:
		create_tween().tween_property(_amb, "volume_db", -14.0, 3.0)
	await Game.say("Outside. The air is cold, and clean.", 3.2)
	await Game.say("The rain stopped sometime in the night.", 3.0)
	await Game.say("It's quiet. I'd forgotten quiet could feel gentle.", 3.6)
	await Game.say("...I'll walk a while.", 2.6)
	player.can_move = true
	_prompt_walk()
	_phase = "path"

# ---------------------------------------------------------------- the park
func _to_park() -> void:
	player.can_move = false
	Game.hide_prompt()
	await _tween_a(_white, 1.0, 1.8)        # warm morning light swallows the frame

	_path.queue_free()
	_build_park()
	_cam.position = Vector2(640, 360)        # park is a single fixed screen again
	player.position = PARK_SPAWN
	player.scale = MC_SCALE
	player.lock_vertical = true
	player.face("right")

	await _tween_a(_white, 0.0, 2.2)        # reveal the park
	await Game.say("...Oh. I know this place.", 3.0)
	await Game.say("The park. Where it happened.", 3.0)
	await Game.say("I haven't come back here since.", 3.2)
	player.can_move = true
	_prompt_walk()
	_phase = "park"

func _build_park() -> void:
	_park = Node2D.new(); add_child(_park)
	var cl := CanvasLayer.new(); cl.layer = -10; _park.add_child(cl)
	var bg := TextureRect.new()
	bg.texture = load(PARK_BG)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(1.0, 0.98, 0.92)    # warm, bright morning — no vignette
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(bg)
	var warm := ColorRect.new()
	warm.color = Color(1.0, 0.92, 0.74, 0.14)
	warm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(warm)

# ---------------------------------------------------------------- per-frame
func _process(_dt: float) -> void:
	if player == null:
		return
	match _phase:
		"path":
			# keep the walker on the backdrop, and scroll the camera to follow him
			player.position.x = clampf(player.position.x, PATH_MIN_X, _path_width - 40.0)
			var cam_max: float = maxf(HALF_VIEW, _path_width - HALF_VIEW)
			_cam.position.x = clampf(player.position.x, HALF_VIEW, cam_max)
			if player.position.x >= _path_width - 80.0:
				_phase = ""
				_to_park()
		"park":
			if player.global_position.x > SPOT_X:
				_phase = ""
				_spot_beat()

# ---------------------------------------------------------------- the ending
func _spot_beat() -> void:
	player.can_move = false
	player.face("right")
	Game.hide_prompt()
	await Game.say("...This is the spot. Where we said everything we shouldn't have.", 4.2)
	await Game.say("Where I watched you turn and go. And I couldn't make it stop.", 4.2)
	await Game.say("For the longest time, I thought if I just stood here...", 3.8)
	await Game.say("...long enough, I could undo it. Take it all back.", 3.8)
	await Game.say("But the grass grew back. The mornings kept coming anyway.", 4.0)
	await Game.say("...And here I am. Still standing. It doesn't break me now.", 4.2)
	await _walk_away()

func _walk_away() -> void:
	# one last look back at the empty spot
	player.face("left")
	await get_tree().create_timer(1.0).timeout
	await Game.say("I'm not letting you go, Eli.", 3.2)
	await Game.say("I'm just... going to stop holding on so hard.", 3.8)
	await Game.say("Thank you. For all of it. Even the end.", 4.2)

	# the morning is fully his now — the MC warms to full colour
	GameState.complete_stage("Acceptance", "the morning — you stayed, and then you walked on.")

	# a few slow, GROUNDED steps along the path — no drifting off into the sky
	player.face("right")
	player.speed = 38.0
	player.auto_walk = Vector2(1, 0)        # straight along the ground; lock_vertical keeps him on it
	var t := create_tween(); t.set_parallel(true)
	t.tween_property(player, "scale", MC_SCALE * 0.85, 3.0)   # a touch smaller, walking on
	if _amb:
		t.tween_property(_amb, "volume_db", -4.0, 4.5)         # birdsong swells
	await get_tree().create_timer(2.6).timeout

	# he stops — still here, in the morning. The camera holds on him.
	player.auto_walk = Vector2.ZERO
	await get_tree().create_timer(1.0).timeout
	await Game.say("...It's a good morning.", 3.0)
	await Game.say("A good morning to be walking.", 3.4)

	# the light blooms up around him — the dramatic swell, then the title
	await _tween_a(_white, 0.5, 3.4)
	await get_tree().create_timer(1.0).timeout
	await Game.show_title("THE LAST MORNING", 4.0)
	await Game.say("thank you for staying.", 3.4)
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
func _prompt_walk() -> void:
	if InputManager.is_controller():
		Game.flash("Walk", 3.0)
	else:
		Game.flash("Walk  (→ / D)", 3.0)

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
