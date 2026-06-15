extends StageBase
## STAGE 1 — DENIAL · "The Ordinary Morning" (side-view kitchen).
## The room won't let things be wrong: every object you straighten quietly undoes
## itself, and the door stays sealed. The way through is to stop fixing — sit at
## the table and let the broken morning be broken.

var _tries := 0
var _resolved := false
var _fix_objects := {}     # Area2D -> Sprite2D

func _ready() -> void:
	setup_sideview("res://assets/art/stage1/kitchen_bg.png", 8.0)
	spawn_player(Vector2(230, 600), true)
	player.face("right")

	# breakfast table + seat
	add_prop("res://assets/art/house/dining_table.png", 640, 540, 4.0)
	var seat := add_prop("res://assets/art/house/chair.png", 520, 590, 4.0)
	seat.modulate = Color(1, 1, 1)

	# things that are subtly "wrong"
	_make_fix("res://assets/art/stage1/cup.png", 700, 545, "Straighten the cup",
		Vector2(700, 545), -0.6)
	_make_fix("res://assets/art/stage1/plate.png", 560, 600, "Wipe the spill",
		Vector2(560, 600), 0.0, Vector2(0.5, 0.5))
	_make_fix("res://assets/art/house/chair.png", 820, 600, "Push the chair in",
		Vector2(820, 600), 0.5)

	# the table seat: sit and accept
	var sit := add_interactable(600, 560, 90, "Sit down (E)")
	sit.used.connect(_on_sit)

	await Game.wake(1.8)
	await Game.say("It's that morning again. An ordinary breakfast.", 3.0)
	await Game.say("But everything is a little out of place. Fix it. Make it normal.", 3.4)
	player.can_move = true

func _make_fix(tex: String, x: float, y: float, prompt: String, home: Vector2, tilt: float, scl := Vector2(4, 4)) -> void:
	var sp := add_prop(tex, x, y, 1.0)
	sp.scale = scl
	sp.rotation = tilt                 # the "wrong" pose
	var area := add_interactable(x, y, 64, prompt)
	area.used.connect(_on_fix)
	_fix_objects[area] = {"sprite": sp, "home_rot": tilt, "home_pos": home}

func _on_fix(area: Area2D) -> void:
	if _resolved:
		return
	var d = _fix_objects.get(area)
	if d == null:
		return
	var sp: Sprite2D = d["sprite"]
	_tries += 1
	# straighten it...
	var t := create_tween()
	t.tween_property(sp, "rotation", 0.0, 0.25)
	t.tween_property(sp, "position:y", sp.position.y - 6, 0.15)
	await t.finished
	await get_tree().create_timer(0.7).timeout
	# ...and the room quietly puts it back wrong
	var t2 := create_tween()
	t2.tween_property(sp, "rotation", d["home_rot"], 0.4)
	t2.tween_property(sp, "position:y", d["home_pos"].y, 0.2)

	match _tries:
		1: Game.flash("There. ...No. It tipped again.", 2.4)
		2: Game.flash("Nothing stays fixed. The room won't let it.", 2.6)
		3: Game.flash("You can't make this morning normal. It wasn't.", 3.0)
		_: Game.flash("Maybe it isn't the room that needs fixing.", 3.0)

func _on_sit(_a: Area2D) -> void:
	if _resolved:
		return
	_resolved = true
	player.can_move = false
	Game.hide_prompt()
	player.position.x = 560
	player.face("right")
	await Game.say("You stop. You sit down with everything still wrong.", 3.2)
	await Game.say("You let the broken morning be broken.", 3.0)
	# the distortion releases
	for area in _fix_objects.keys():
		var sp: Sprite2D = _fix_objects[area]["sprite"]
		create_tween().tween_property(sp, "modulate:a", 0.5, 1.2)
	await Game.say("It was the last normal day. And it mattered.", 3.2)
	await finish("Denial", "The ordinary — the last normal morning mattered.")
