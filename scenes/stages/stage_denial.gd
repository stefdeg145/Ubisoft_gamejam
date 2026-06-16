extends StageBase
## STAGE 1 — DENIAL · "The Ordinary Morning" (side-view kitchen).
## The room won't let things be wrong: every object you straighten quietly undoes
## itself, and the door stays sealed. The way through is to stop fixing — sit
## down and let the broken morning be broken.
##
## FULLY EDITOR-FRIENDLY: the Background, the Player and the props (Mug / Painting
## / ChairKnocked / ChairSeat) are all real nodes in stage_denial.tscn:
##   • move / scale / rotate any prop — its trigger + the "E" follow it,
##   • resize the Player by changing the Player node's Scale in the Inspector,
##   • the camera is stationary and frames the WHOLE background (set automatically
##     from the Background node's size).
## The pose you give a prop in the editor IS its "wrong" pose; fixing always undoes.

const MUG_CLEAN := "res://assets/art/Mug Unspilled for Denial.png"
const BACKGROUND := "res://assets/art/denial_stage/background.jpg"
const COOKING_BGM := "res://assets/Sound/Cooking_sound_denial_BGM.mp3"

## name in the scene -> {prompt, clean(optional swap texture), reach}
## `reach` is the radius of the interaction box — bump it for props the player
## can't stand right next to (e.g. a painting up on the wall).
const FIXABLES := [
	{"name": "Mug", "prompt": "Wipe the mug", "clean": MUG_CLEAN, "reach": 190.0},
	{"name": "Painting", "prompt": "Straighten the painting", "clean": "", "reach": 270.0},
	{"name": "ChairKnocked", "prompt": "Pick up the chair", "clean": "", "reach": 120.0},
]

var _tries := 0
var _resolved := false
var _fixing := false             # blocks re-triggering a fix while one is playing
var _fix_objects := {}          # Area2D -> {sprite, home_rot, home_pos, wrong_tex, fixed_tex}
var _music: AudioStreamPlayer

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_setup_view()
	_setup_player()
	_start_cooking_bgm()

	# wire each "wrong" prop the editor placed
	for f in FIXABLES:
		_register_fix(f["name"], f["prompt"], f["clean"], f["reach"])

	# the seat: sit down here to accept
	var seat := get_node_or_null("ChairSeat")
	if seat is Node2D:
		var sit := add_interactable(seat.position.x, seat.position.y, 95, "Sit down (E)", seat)
		sit.used.connect(_on_sit)

	await Game.wake(1.8)
	await Game.say("It's that morning again. An ordinary breakfast.", 3.0)
	await Game.say("But everything is a little out of place. Fix it. Make it normal.", 3.4)
	player.can_move = true

# ------------------------------------------------------------------ view
## Stationary camera that shows the whole (and only the whole) background, plus
## bounding walls at the background's edges.
func _setup_view() -> void:
	var bg := get_node_or_null("Background")
	var top_left := Vector2.ZERO
	var size := Vector2(1280, 714)
	if bg is Sprite2D and (bg as Sprite2D).texture != null:
		bg.centered = false
		size = (bg as Sprite2D).texture.get_size() * bg.scale
		top_left = bg.position
	else:
		# fallback if the Background node was removed: build one behind everything
		var b := Sprite2D.new()
		b.texture = load(BACKGROUND)
		b.centered = false
		b.scale = Vector2(0.93, 0.93)
		b.z_index = -100
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(b)
		move_child(b, 0)
		size = b.texture.get_size() * b.scale

	var cam := Camera2D.new()
	cam.position = top_left + size * 0.5
	var vp := get_viewport().get_visible_rect().size
	var z: float = min(vp.x / size.x, vp.y / size.y)   # fit the whole background
	cam.zoom = Vector2(z, z)
	add_child(cam)
	cam.make_current()

	# walls at the left/right edges (the player only walks left/right here)
	_wall(top_left.x - 24, top_left.y, 24, size.y)
	_wall(top_left.x + size.x, top_left.y, 24, size.y)

# ------------------------------------------------------------------ player
func _setup_player() -> void:
	player = get_node_or_null("Player") as CharacterBody2D
	if player == null:
		# fallback: spawn one if the Player node was removed from the scene
		spawn_player(Vector2(230, 600), true)
	# the stationary stage camera stays in control, not the player's follow-cam
	var pcam := player.get_node_or_null("Camera2D")
	if pcam is Camera2D:
		(pcam as Camera2D).enabled = false
	player.can_move = false
	player.lock_vertical = true
	player.face("right")

func _start_cooking_bgm() -> void:
	_music = AudioStreamPlayer.new()
	var stream = load(COOKING_BGM)
	if stream is AudioStreamMP3:
		stream.loop = true              # keep the kitchen alive for the whole level
	_music.stream = stream
	_music.volume_db = -6.0
	add_child(_music)
	_music.play()

## Find an editor-placed prop by name and attach the "fix never sticks" behaviour.
## Uses the prop's current rotation (as set in the editor) as its "wrong" pose.
func _register_fix(node_name: String, prompt: String, clean_path: String, reach := 110.0) -> void:
	var sp := get_node_or_null(node_name)
	if not (sp is Sprite2D):
		return
	var area := add_interactable(sp.position.x, sp.position.y, reach, prompt, sp)
	area.used.connect(_on_fix)
	var entry := {
		"sprite": sp, "home_rot": sp.rotation, "home_pos": sp.position,
		"wrong_tex": sp.texture, "fixed_tex": null,
	}
	if clean_path != "":
		entry["fixed_tex"] = load(clean_path)
	_fix_objects[area] = entry

# ------------------------------------------------------------------ fixing
func _on_fix(area: Area2D) -> void:
	if _resolved or _fixing:
		return
	var d = _fix_objects.get(area)
	if d == null:
		return
	_fixing = true
	var sp: Sprite2D = d["sprite"]
	_tries += 1
	# straighten it (and, for the mug, wipe it clean)...
	if d["fixed_tex"] != null:
		sp.texture = d["fixed_tex"]
	var t := create_tween()
	t.tween_property(sp, "rotation", 0.0, 0.25)
	t.tween_property(sp, "position:y", sp.position.y - 6, 0.15)
	await t.finished
	await get_tree().create_timer(0.7).timeout
	# ...and the room quietly puts it back wrong
	if d["fixed_tex"] != null:
		sp.texture = d["wrong_tex"]
	var t2 := create_tween()
	t2.tween_property(sp, "rotation", d["home_rot"], 0.4)
	t2.tween_property(sp, "position:y", d["home_pos"].y, 0.2)

	var hold := 3.0
	match _tries:
		1:
			hold = 2.6
			Game.flash("There. ...No. It tipped again.", hold)
		2:
			hold = 2.8
			Game.flash("Nothing stays fixed. The room won't let it.", hold)
		3:
			hold = 3.2
			Game.flash("You can't make this morning normal. It wasn't.", hold)
		_:
			hold = 3.2
			Game.flash("Maybe it isn't the room that needs fixing.", hold)

	# keep the line on screen long enough to read before another fix can interrupt
	await get_tree().create_timer(hold).timeout
	_fixing = false

# ------------------------------------------------------------------ resolve
func _on_sit(_a: Area2D) -> void:
	if _resolved:
		return
	_resolved = true
	player.can_move = false
	Game.hide_prompt()
	var seat := get_node_or_null("ChairSeat")
	if seat is Node2D:
		player.position.x = (seat as Node2D).position.x
	player.face("right")
	await Game.say("You stop. You sit down with everything still wrong.", 3.2)
	await Game.say("You let the broken morning be broken.", 3.0)
	# the distortion releases
	for a in _fix_objects.keys():
		var sp: Sprite2D = _fix_objects[a]["sprite"]
		create_tween().tween_property(sp, "modulate:a", 0.5, 1.2)
	await Game.say("It was the last normal day. And it mattered.", 3.2)
	if _music:
		create_tween().tween_property(_music, "volume_db", -40.0, 1.5)
	await finish("Denial", "The ordinary — the last normal morning mattered.")
