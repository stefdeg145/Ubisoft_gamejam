extends Node2D
## The house hub, built procedurally in an oblique (2.5D) pixel style: a floor
## seen from above, a north wall whose papered face + window you actually see,
## and furniture drawn with visible front faces. One memory glows at a time;
## entering it drifts the player into that stage's dream. Completing a stage
## warms the house a little (the grey grade lifts).

const PlayerScene := preload("res://scenes/actors/player.tscn")
const MemoryScript := preload("res://scripts/memory_object.gd")

const A := "res://assets/art/house/"
const PROP := "res://assets/art/props/"
const FX := "res://assets/art/fx/"

# world bounds for the play area (interior)
const LEFT := 64
const TOP := 128
const RIGHT := 960
const BOTTOM := 640
const TILE := 64

var player: CharacterBody2D
var _world: Node2D          # y-sorted layer (furniture + player)
var _grade: CanvasModulate

# stage_name -> [prop_texture, scene_path, feet_x, feet_y, locked_line]
var MEMORIES := {
	"Denial": [PROP + "mug.png", "res://scenes/stages/stage_denial.tscn", 700, 300,
		"Their mug. Half a ring of coffee, dried. ...I'm not ready."],
	"Bargaining": [PROP + "photo.png", "res://scenes/stages/stage_bargaining.tscn", 470, 585,
		"That photograph. The last good day. Not yet. I can't look at that one yet."],
	"Depression": [PROP + "record.png", "res://scenes/stages/stage_depression.tscn", 300, 620,
		"Their voice is on that tape. ...I'm not ready to hear it."],
	"Acceptance": [PROP + "coat.png", "res://scenes/stages/stage_acceptance.tscn", 770, 620,
		"Their coat. Still smells like rain. Not yet."],
}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_floor()
	_build_walls()
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)
	_build_furniture()
	_spawn_player()
	_build_memories()
	_build_grade()
	_build_rain()
	_update_grade()

	if GameState.first_wake:
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

func _feet(parent: Node, path: String, fx: int, fy: int, s := 2.0) -> Sprite2D:
	var tex: Texture2D = load(path)
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
	sp.position = Vector2(fx, fy)
	sp.scale = Vector2(s, s)
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
	var floors := Node2D.new()
	add_child(floors)
	var wood: Texture2D = load(A + "floor_wood.png")
	var tile: Texture2D = load(A + "floor_tile.png")
	var x := LEFT
	while x < RIGHT:
		var y := TOP
		while y < BOTTOM:
			var kitchen := x >= 600 and y < 320
			_tl(floors, tile if kitchen else wood, x, y, 2.0)
			y += TILE
		x += TILE
	# living-room rug (floor decal)
	_tl(floors, load(A + "rug.png"), 360, 430, 2.0)

func _build_walls() -> void:
	var walls := Node2D.new()
	add_child(walls)
	var face: Texture2D = load(A + "wall_face.png")     # 32x48 -> 64x96 @2
	# north wall: a row of papered faces, bottom resting on the floor's top edge
	var x := LEFT
	while x < RIGHT:
		_tl(walls, face, x, TOP - 96, 2.0)
		x += TILE
	# window set into the north wall
	_tl(walls, load(A + "wall_window.png"), 760, TOP - 92, 2.0)
	# side wall caps (simple dark borders so the room reads as enclosed)
	var dark := Color(0.22, 0.20, 0.22)
	var west := ColorRect.new(); west.color = dark
	west.position = Vector2(LEFT - 16, TOP - 96); west.size = Vector2(16, BOTTOM - TOP + 96)
	add_child(west)
	var east := ColorRect.new(); east.color = dark
	east.position = Vector2(RIGHT, TOP - 96); east.size = Vector2(16, BOTTOM - TOP + 96)
	add_child(east)
	var south := ColorRect.new(); south.color = dark
	south.position = Vector2(LEFT - 16, BOTTOM); south.size = Vector2(RIGHT - LEFT + 32, 16)
	add_child(south)
	# perimeter colliders
	_collider(LEFT - 24, TOP - 8, RIGHT - LEFT + 48, 16)   # north
	_collider(LEFT - 24, BOTTOM, RIGHT - LEFT + 48, 24)    # south
	_collider(LEFT - 24, TOP - 96, 24, BOTTOM - TOP + 120) # west
	_collider(RIGHT, TOP - 96, 24, BOTTOM - TOP + 120)     # east

func _build_furniture() -> void:
	# bedroom (top-left)
	_feet(_world, A + "bed.png", 190, 300); _collider(120, 200, 130, 100)
	_feet(_world, A + "nightstand.png", 300, 296); _collider(276, 250, 48, 44)
	_feet(_world, A + "wardrobe.png", 150, 470); _collider(96, 410, 88, 60)
	# kitchen (top-right)
	_feet(_world, A + "sink_counter.png", 660, 250); _collider(575, 196, 150, 50)
	_feet(_world, A + "counter.png", 540, 250); _collider(465, 196, 150, 50)
	_feet(_world, A + "stove.png", 860, 252); _collider(826, 198, 70, 54)
	_feet(_world, A + "fridge.png", 920, 300); _collider(896, 232, 50, 64)
	_feet(_world, A + "dining_table.png", 720, 390); _collider(640, 340, 168, 56)
	_feet(_world, A + "chair.png", 680, 420)
	_feet(_world, A + "chair.png", 770, 420)
	# living (bottom)
	_feet(_world, A + "couch.png", 470, 470); _collider(380, 420, 190, 56)
	_feet(_world, A + "coffee_table.png", 470, 560); _collider(420, 525, 110, 36)
	_feet(_world, A + "tv_stand.png", 470, 638); _collider(410, 612, 120, 28)
	_feet(_world, A + "armchair.png", 880, 560); _collider(836, 505, 84, 56)
	_feet(_world, A + "record_player.png", 300, 612); _collider(270, 582, 76, 30)
	_feet(_world, A + "bookshelf.png", 150, 612); _collider(110, 540, 88, 72)
	_feet(_world, A + "plant.png", 600, 612)
	# ambient flavour memory on the bookshelf
	_make_memory_raw("Book", PROP + "book.png", 150, 590, true,
		"A half-finished book. The bookmark hasn't moved in weeks.")

func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	# start asleep in the window armchair
	player.position = Vector2(880, 545)
	player.can_move = false
	player.add_to_group("player")
	_world.add_child(player)
	player.face("left")

func _build_memories() -> void:
	for stage in MEMORIES.keys():
		var d = MEMORIES[stage]
		var m := _make_memory(stage, d[0], d[2], d[3], d[4])
		m.stage_scene = d[1]

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

func _make_memory_raw(name: String, tex_path: String, fx: int, fy: int, ambient: bool, line: String) -> void:
	var m := _make_memory(name, tex_path, fx, fy, "")
	m.ambient = ambient
	m.idle_line = line
	m.name = name

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
	await get_tree().create_timer(0.4).timeout
	Game.flash("Something across the room is glowing. Go to it. (arrows / WASD, E to look)", 4.0)

func _return_from_dream() -> void:
	_update_grade()
	await Game.wake(1.8)
	player.can_move = true
	if GameState.completed.size() >= GameState.STAGES.size():
		await Game.say("It's quiet. But the grey is almost gone.", 3.0)
	else:
		await Game.say("You wake in the chair. The house feels a little warmer.", 3.0)
		Game.flash("Another memory has begun to glow.", 3.0)

func _on_memory_chosen(node: Node) -> void:
	player.can_move = false
	Game.hide_prompt()
	await Game.drift_to_sleep(2.2)
	if not GameState.title_shown:
		GameState.title_shown = true
		await Game.show_title("THE LAST MORNING", 3.0)
		await Game.say("In the dream, it's that morning again.", 3.0)
	Game.change_scene(node.stage_scene)
