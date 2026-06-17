extends Node2D
## The house hub. The floor, the north wall you actually see, the colour grade
## and the rain are built in code; the interior walls, all the furniture and the
## interactable doors live as real nodes in house.tscn so they can be dragged and
## arranged in the editor. The player, the glowing memory objects and the story
## flow are still spawned here. One memory glows at a time; entering it drifts the
## player into that stage's dream, and completing a stage warms the house.

const PlayerScene := preload("res://scenes/actors/player.tscn")
const MemoryScript := preload("res://scripts/memory_object.gd")
const TiredScript := preload("res://scripts/tired_prop.gd")
const BedScript := preload("res://scripts/bed.gd")
const AngerScene := preload("res://scripts/anger_sequence.gd")
const LettersScript := preload("res://scripts/sympathy_letters.gd")

const DENIAL_SCENE := "res://scenes/stages/stage_denial.tscn"
## Where the Anger bleed leads once it resolves: the Bargaining stage (being
## pushed by another dev). Until that scene exists this path will fail to load,
## so _on_anger_finished falls back to the house if it's missing.
const ANGER_NEXT_SCENE := "res://scenes/stages/stage_bargaining.tscn"

const A := "res://assets/art/house/"
const ART := "res://assets/art/"
const PROP := "res://assets/art/props/"
const FX := "res://assets/art/fx/"
const MUSIC := "res://assets/Sound/Oldies Playing In Another Room  with Gentle Rain and Thunder (V.1).mp3"

# world bounds for the play area (interior)
const LEFT := 64
const TOP := 128
const RIGHT := 960
const BOTTOM := 640
const TILE := 64

var player: CharacterBody2D
var _grade: CanvasModulate
var _music: AudioStreamPlayer
## [{zone, sprite}] pairs kept in sync each frame so interactions track furniture.
var _follow_zones: Array = []
## "Your bed" sprite (the top-left one) — used to spawn beside it after a dream.
var _my_bed: Sprite2D
var _my_bed_zone                # the bed's interaction Area2D (locked until cards are read)
var _letters: SympathyLetters   # the sympathy cards: the first thing to face on waking
var _letters_read := false
var _denial_popup: ObjectivePopup
var _bargaining: Node      # couch->Bargaining flow; started once Anger resolves

@onready var _floor: Node2D = $Floor
@onready var _northwall: Node2D = $NorthWall
@onready var _world: Node2D = $World      # y-sorted: furniture (from scene) + player + memories

# stage_name -> [prop_texture, scene_path, feet_x, feet_y, locked_line]
var MEMORIES := {
	"Denial": [PROP + "mug.png", "res://scenes/stages/stage_denial.tscn", 700, 320,
		"Their mug. Half a ring of coffee, dried. ...I'm not ready."],
	"Bargaining": [PROP + "photo.png", "res://scenes/stages/stage_bargaining.tscn", 664, 532,
		"That photograph. The last good day. Not yet. I can't look at that one yet."],
	"Depression": [PROP + "record.png", "res://scenes/stages/stage_depression.tscn", 285, 604,
		"Their voice is on that tape. ...I'm not ready to hear it."],
	"Acceptance": [PROP + "coat.png", "res://scenes/stages/stage_acceptance.tscn", 150, 360,
		"Their coat. Still smells like rain. Not yet."],
}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_floor()
	_build_north_wall()
	_spawn_player()
	# Denial entry is now sleep-based: most furniture is "too tired", and only the
	# top-left bed lets the player sleep into the dream. (The old glowing-memory
	# entrances are off for now — we'll rework stage entries when designing levels.)
	_build_interactions()
	_build_grade()
	_build_rain()
	_build_music()
	_update_grade()

	# Bargaining entry (self-contained). It waits until Anger resolves, then
	# _on_anger_finished() calls begin_mission() to hand the player the couch
	# objective. (INSERT still force-starts it for testing.)
	_bargaining = preload("res://scripts/bargaining_controller.gd").new()
	add_child(_bargaining)

	# Only play the opening intro on a truly fresh start. Once any stage has been
	# resolved, returning to the house always goes through the wake-from-dream path
	# (so finishing Denial leads into Anger, not back to the intro).
	if GameState.first_wake and GameState.completed.is_empty():
		_build_letters()
		_gate_props_until_cards(true)   # nothing else responds until the cards are read
		_intro()
	else:
		_return_from_dream()

# -------------------------------------------------------------- helpers
func _tl(parent: Node, tex: Texture2D, x: int, y: int, s := 2.0, mod := Color.WHITE) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.position = Vector2(x, y)
	sp.scale = Vector2(s, s)
	sp.modulate = mod
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(sp)
	return sp

func _collider(x: int, y: int, w: int, h: int) -> void:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, h)
	cs.shape = shape
	cs.position = Vector2(x + w / 2.0, y + h / 2.0)
	body.add_child(cs)
	add_child(body)

# -------------------------------------------------------------- build
func _build_floor() -> void:
	var wood: Texture2D = load(A + "floor_wood.png")
	var tile: Texture2D = load(A + "floor_tile.png")
	var x := LEFT
	while x < RIGHT:
		var y := TOP
		while y < BOTTOM:
			var kitchen := x >= 552 and y < 372          # kitchen/dining (top-right)
			var bath := x >= 352 and x < 552 and y < 300  # bathroom (top-center)
			_tl(_floor, tile if (kitchen or bath) else wood, x, y, 2.0)
			y += TILE
		x += TILE

func _build_north_wall() -> void:
	var face: Texture2D = load(A + "wall_face.png")     # 32x48 -> 64x96 @2
	var x := LEFT
	while x < RIGHT:
		_tl(_northwall, face, x, TOP - 96, 2.0)
		x += TILE
	_tl(_northwall, load(A + "wall_window.png"), 760, TOP - 92, 2.0)
	# side wall caps (simple dark borders so the room reads as enclosed)
	var dark := Color(0.22, 0.20, 0.22)
	var west := ColorRect.new(); west.color = dark
	west.position = Vector2(LEFT - 16, TOP - 96); west.size = Vector2(16, BOTTOM - TOP + 96)
	_northwall.add_child(west)
	var east := ColorRect.new(); east.color = dark
	east.position = Vector2(RIGHT, TOP - 96); east.size = Vector2(16, BOTTOM - TOP + 96)
	_northwall.add_child(east)
	var south := ColorRect.new(); south.color = dark
	south.position = Vector2(LEFT - 16, BOTTOM); south.size = Vector2(RIGHT - LEFT + 32, 16)
	_northwall.add_child(south)
	# perimeter colliders
	_collider(LEFT - 24, TOP - 8, RIGHT - LEFT + 48, 16)   # north
	_collider(LEFT - 24, BOTTOM, RIGHT - LEFT + 48, 24)    # south
	_collider(LEFT - 24, TOP - 96, 24, BOTTOM - TOP + 120) # west
	_collider(RIGHT, TOP - 96, 24, BOTTOM - TOP + 120)     # east

func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	# start asleep in the window armchair
	player.position = Vector2(860, 576)
	player.can_move = false
	player.add_to_group("player")
	_world.add_child(player)
	player.face("left")
	_setup_camera()

## Pin the player's camera to the house so it never scrolls past the edges into the
## grey void around the room. Limits are the visible house extents (floor + the
## wall caps drawn in _build_north_wall). Because the room is a touch narrower than
## the camera's view at the default zoom, we also zoom in just enough here that the
## view fits *inside* the room horizontally — otherwise Godot would still reveal
## grey on one side, since limits can't center a level smaller than the screen.
## This only touches the house's camera; the dream stages keep the player's default.
func _setup_camera() -> void:
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam == null:
		return
	# Visible house bounds (matches the wall caps: LEFT-16 .. RIGHT+16, TOP-96 .. BOTTOM+16).
	var view_left := LEFT - 16
	var view_top := TOP - 96
	var view_right := RIGHT + 16
	var view_bottom := BOTTOM + 16
	cam.limit_left = view_left
	cam.limit_top = view_top
	cam.limit_right = view_right
	cam.limit_bottom = view_bottom
	cam.limit_smoothed = true            # ease to a stop at the edge instead of snapping
	# Make sure the view fits within the room on both axes so no grey can peek in.
	var vp: Vector2 = get_viewport_rect().size
	var room_w := float(view_right - view_left)
	var room_h := float(view_bottom - view_top)
	var min_zoom: float = max(vp.x / room_w, vp.y / room_h)
	var z: float = max(cam.zoom.x, ceilf(min_zoom * 100.0) / 100.0)
	cam.zoom = Vector2(z, z)
	cam.reset_smoothing()                # don't glide in from (0,0) on the first frame

## A standing spot just below/beside "your bed", clamped inside the play area.
func _bed_spawn_point() -> Vector2:
	if _my_bed == null or not is_instance_valid(_my_bed):
		return Vector2(860, 576)
	var r := _visual_aabb(_my_bed)
	var p := Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y + 28.0)
	p.x = clampf(p.x, LEFT + 24, RIGHT - 24)
	p.y = clampf(p.y, TOP + 24, BOTTOM - 24)
	return p

# -------------------------------------------------------------- interactions
## Wraps the furniture (already placed in house.tscn) with interaction zones in
## code, so the editable layout is never touched. Beds get the sleep behaviour;
## the most top-left bed is "your bed". Everything else gives a "too tired" line.
func _build_interactions() -> void:
	var inter := Node2D.new()
	inter.name = "Interactions"
	add_child(inter)

	# find the bed nodes and pick the most top-left one (by on-screen position)
	var beds: Array = []
	for c in _world.get_children():
		if c is Sprite2D and (c as Sprite2D).texture != null and c.name.begins_with("Bed"):
			beds.append(c)
	var my_bed: Node = null
	var best := INF
	for b in beds:
		var ctr := _visual_center(b)
		if ctr.x + ctr.y < best:
			best = ctr.x + ctr.y
			my_bed = b
	_my_bed = my_bed as Sprite2D

	for c in _world.get_children():
		if not (c is Sprite2D) or (c as Sprite2D).texture == null:
			continue
		if c.name.begins_with("Bed"):
			_add_bed_zone(inter, c, c == my_bed)
		else:
			_add_tired_zone(inter, c)

func _visual_aabb(sp: Sprite2D) -> Rect2:
	# Sprite2D is centered=false with an offset, so the drawn rect starts at
	# position + offset*scale and spans texture_size*scale.
	if sp == null or sp.texture == null:
		return Rect2(sp.position if sp else Vector2.ZERO, Vector2(32, 32))
	var ts: Vector2 = sp.texture.get_size()
	var top_left: Vector2 = sp.position + sp.offset * sp.scale
	return Rect2(top_left, ts * sp.scale)

func _visual_center(sp: Sprite2D) -> Vector2:
	var r := _visual_aabb(sp)
	return r.position + r.size * 0.5

# Builds the Area2D + detection shape but does NOT add it to the tree yet, so the
# caller can attach the script and set properties before _ready() fires.
func _zone(sp: Sprite2D, pad: float) -> Area2D:
	var a := Area2D.new()
	var r := _visual_aabb(sp)
	a.position = r.position + r.size * 0.5
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size + Vector2(pad, pad)
	cs.shape = shape
	a.add_child(cs)
	return a

func _add_tired_zone(parent: Node, sp: Sprite2D) -> void:
	var a := _zone(sp, 28.0)
	a.set_script(TiredScript)
	a.source_sprite = sp
	parent.add_child(a)
	_follow_zones.append({"zone": a, "sprite": sp})

func _add_bed_zone(parent: Node, sp: Sprite2D, mine: bool) -> void:
	var a := _zone(sp, 48.0)
	a.set_script(BedScript)
	a.source_sprite = sp
	a.is_my_bed = mine
	a.stage_scene = DENIAL_SCENE
	if mine:
		a.chosen.connect(_on_memory_chosen)   # reuse drift-to-sleep -> dream flow
		_my_bed_zone = a
		# On a fresh start the cards must be read before sleep unlocks Denial.
		a.sleep_locked = GameState.first_wake and GameState.completed.is_empty()
	parent.add_child(a)
	_follow_zones.append({"zone": a, "sprite": sp})

## Each frame, keep every interaction zone snapped to its furniture's current
## visual centre. Dragging furniture around in the editor (or moving it at
## runtime) then never desyncs the trigger or the floating "E".
func _process(_dt: float) -> void:
	for e in _follow_zones:
		var sp = e["sprite"]
		var z = e["zone"]
		if not (is_instance_valid(sp) and is_instance_valid(z)):
			continue
		var r := _visual_aabb_global(sp)
		z.global_position = r.position + r.size * 0.5

func _visual_aabb_global(sp: Sprite2D) -> Rect2:
	var ts: Vector2 = sp.texture.get_size()
	var base_tl: Vector2 = sp.offset
	if sp.centered:
		base_tl -= ts * 0.5
	var tl: Vector2 = sp.global_position + base_tl * sp.scale
	return Rect2(tl, ts * sp.scale)

func _build_memories() -> void:
	for stage in MEMORIES.keys():
		var d = MEMORIES[stage]
		var m := _make_memory(stage, d[0], d[2], d[3], d[4])
		m.stage_scene = d[1]
	# ambient flavour memory on the bedroom-2 bookshelf
	_make_memory_raw("Book", PROP + "book.png", 120, 600, true,
		"A half-finished book. The bookmark hasn't moved in weeks.")

func _make_memory(stage: String, tex_path: String, fx: int, fy: int, locked: String) -> Area2D:
	var area := Area2D.new()
	area.set_script(MemoryScript)
	area.stage_name = stage
	area.locked_line = locked
	area.position = Vector2(fx, fy)
	# glow halo (behind prop)
	var glow := Sprite2D.new()
	glow.name = "Glow"
	glow.texture = load(FX + "glow_warm.png")
	glow.scale = Vector2(1.6, 1.6)
	glow.position = Vector2(0, -14)
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	area.add_child(glow)
	# prop
	var prop: Texture2D = load(tex_path)
	var ps := Sprite2D.new()
	ps.texture = prop
	ps.centered = false
	ps.offset = Vector2(-prop.get_width() / 2.0, -prop.get_height())
	ps.scale = Vector2(2.0, 2.0)
	ps.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	area.add_child(ps)
	# interaction shape
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 60.0
	cs.shape = shape
	cs.position = Vector2(0, -10)
	area.add_child(cs)
	_world.add_child(area)
	area.chosen.connect(_on_memory_chosen)
	return area

func _make_memory_raw(mem_name: String, tex_path: String, fx: int, fy: int, ambient: bool, line: String) -> void:
	var m := _make_memory(mem_name, tex_path, fx, fy, "")
	m.ambient = ambient
	m.idle_line = line
	m.name = mem_name

func _build_grade() -> void:
	_grade = CanvasModulate.new()
	add_child(_grade)

func _build_rain() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var rain := TextureRect.new()
	rain.texture = load(FX + "rain.png")
	rain.stretch_mode = TextureRect.STRETCH_TILE
	rain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rain.modulate = Color(1, 1, 1, 0.10)
	rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rain)

func _update_grade() -> void:
	var w := GameState.warmth()
	# cold grey -> warm/full colour as memories resolve
	var cold := Color(0.55, 0.57, 0.66)
	_grade.color = cold.lerp(Color(1, 1, 1), w)

# -------------------------------------------------------------- music
func _build_music() -> void:
	_music = AudioStreamPlayer.new()
	_music.stream = load(MUSIC)        # imported with loop = true
	_music.volume_db = -8.0
	add_child(_music)

func _play_music() -> void:
	if _music and not _music.playing:
		_music.volume_db = -8.0
		_music.play()

func _fade_out_music(dur := 2.0) -> void:
	if _music == null or not _music.playing:
		return
	var t := create_tween()
	t.tween_property(_music, "volume_db", -40.0, dur)
	t.tween_callback(_music.stop)

# -------------------------------------------------------------- flow
func _intro() -> void:
	Game.set_black(true)
	await get_tree().create_timer(0.6).timeout
	await Game.fade_in(3.0)                       # slow wake into the grey house
	await get_tree().create_timer(0.8).timeout
	await Game.say("You fell asleep in the chair by the window. Waiting.", 3.0)
	await Game.say("The house is so quiet now.", 2.6)
	player.can_move = true
	GameState.first_wake = false
	_play_music()                                  # the house comes alive once you can move
	await get_tree().create_timer(0.4).timeout
	var _move_hint := "Left Stick / D-Pad" if InputManager.is_controller() else "WASD"
	var _act_hint  := "A" if InputManager.is_controller() else "E"
	Game.flash("Cards. People keep leaving cards on the table. (%s to move, %s to interact)" % [_move_hint, _act_hint], 4.5)
	# First objective: read the sympathy cards before the morning can begin.
	_denial_popup = ObjectivePopup.new()
	add_child(_denial_popup)
	_denial_popup.show_objective("NEW OBJECTIVE", "Read the cards people left on the table.")

# -------------------------------------------------------------- sympathy cards
## Drop the sympathy-card stack on the dining table (falls back to a fixed spot
## if the table sprite isn't found) and wait for the player to read them.
func _build_letters() -> void:
	_letters = LettersScript.new()
	var table := _find_world_sprite("DiningTable")
	if table != null:
		var c := _visual_center(table)
		_letters.position = Vector2(c.x, c.y - 6)
	else:
		_letters.position = Vector2(700, 300)
	_world.add_child(_letters)
	_letters.finished.connect(_on_letters_read)

## Before the cards are read, every prop (and your bed) steers the player back to
## them; afterwards the house behaves normally. The cards themselves live in
## _world, so they stay interactable while everything else is gated.
func _gate_props_until_cards(gated: bool) -> void:
	var inter := get_node_or_null("Interactions")
	if inter != null:
		for z in inter.get_children():
			if "gated" in z:                  # tired props
				z.gated = gated
	if _my_bed_zone and is_instance_valid(_my_bed_zone):
		_my_bed_zone.sleep_locked = gated

## Once the cards are read: unlock the bed and hand over the "go to sleep" objective.
func _on_letters_read() -> void:
	if _letters_read:
		return
	_letters_read = true
	if _denial_popup:
		_denial_popup.dismiss()
		_denial_popup = null
	_gate_props_until_cards(false)       # the house responds normally now
	await Game.say("...I can't keep my eyes open. Maybe in the dream, it's still that morning.", 4.0)
	_denial_popup = ObjectivePopup.new()
	add_child(_denial_popup)
	_denial_popup.show_objective("NEW OBJECTIVE", "You can barely keep your eyes open. Go to your bed and sleep.")

func _return_from_dream() -> void:
	_update_grade()
	# wake up beside the bed (where you fell asleep into the dream), not the chair
	if _my_bed and is_instance_valid(_my_bed):
		player.position = _bed_spawn_point()
		player.face("down")
	await Game.wake(1.8)
	_play_music()
	# After Denial, the waking house turns hostile — the Anger "Bleed".
	if GameState.completed.has("Denial") and not GameState.completed.has("Anger"):
		_start_anger()
		return
	player.can_move = true
	if GameState.completed.size() >= GameState.STAGES.size():
		await Game.say("It's quiet. But the grey is almost gone.", 3.0)
	else:
		await Game.say("You wake. The house feels a little less heavy than before.", 3.0)

# -------------------------------------------------------------- anger bleed
func _start_anger() -> void:
	_play_music()                         # keep the house BGM going through the bleed
	_set_house_interactions(false)        # silence the "too tired" props mid-bleed
	var seq := AngerScene.new()
	var rug := get_node_or_null("Decals/RugLiving")
	var chair := _find_world_sprite("Chair")
	var table := _find_world_sprite("DiningTable")
	var table_top := Vector2(700, 300)
	if table != null:
		var r := _visual_aabb_global(table)
		table_top = Vector2(r.position.x + r.size.x * 0.5, r.position.y + 10.0)
	seq.setup(player, _world, Rect2(LEFT, TOP, RIGHT - LEFT, BOTTOM - TOP),
		rug, chair, table_top)
	add_child(seq)
	seq.finished.connect(_on_anger_finished)
	seq.start()

func _on_anger_finished() -> void:
	_update_grade()                       # house warms a notch now Anger is resolved
	await Game.say("The mug is in pieces. The rain keeps on, softer now.", 3.0)
	# Hand control back, then start the couch flow: an objective to sit and look at
	# their photograph, which is what actually bridges into the Bargaining memory.
	_set_house_interactions(true)
	player.can_move = true
	if _bargaining and is_instance_valid(_bargaining) and _bargaining.has_method("begin_mission"):
		_bargaining.begin_mission()
	else:
		await Game.say("(The next memory isn't ready yet.)", 2.4)

func _find_world_sprite(prefix: String) -> Sprite2D:
	for c in _world.get_children():
		if c is Sprite2D and c.name.begins_with(prefix):
			return c
	return null

## Toggle the house's own interaction zones (beds / tired props) on or off, e.g.
## so they don't compete with a scripted sequence like the Anger bleed.
func _set_house_interactions(enabled: bool) -> void:
	var inter := get_node_or_null("Interactions")
	if inter == null:
		return
	for z in inter.get_children():
		if z is Area2D:
			z.monitoring = enabled
			z.monitorable = enabled
			if not enabled and is_instance_valid(player):
				player.remove_interactable(z)
	if not enabled and is_instance_valid(player):
		player.nearby_object = null

func _on_memory_chosen(node: Node) -> void:
	player.can_move = false
	Game.hide_prompt()
	_fade_out_music(2.0)                            # let the oldies fade as we drift off
	if _denial_popup:
		_denial_popup.dismiss()
		_denial_popup = null
	await Game.drift_to_sleep(2.2)
	if not GameState.title_shown:
		GameState.title_shown = true
		await Game.show_title("THE LAST MORNING", 3.0)
		await Game.say("In the dream, it's that morning again.", 3.0)
	Game.change_scene(node.stage_scene)
