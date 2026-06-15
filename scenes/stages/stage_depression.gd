extends StageBase
## STAGE 3 — DEPRESSION · "Insomnia" (dark top-down bedroom).
## Different camera again: a small room from above, the air heavy. You try to
## sleep and can't. You play their voice and it only sinks you lower. Thirsty,
## you reach for the water on the nightstand — mash to reach — but you fall, and
## pass out, down into acceptance.

const FX := "res://assets/art/fx/"
const A := "res://assets/art/house/"

var _dark: ColorRect
var _vig: TextureRect
var _step := 0
var _mashing := false
var _mash := 0
var _reach: Sprite2D
var _bar: ProgressBar
var _done := false

func _ready() -> void:
	setup_room()
	spawn_player(Vector2(640, 470))
	player.face("up")

	var bed_a := add_interactable(640, 250, 90, "Try to sleep (E)")
	bed_a.used.connect(_on_bed)
	var rec_a := add_interactable(900, 330, 80, "Play their voice (E)")
	rec_a.used.connect(_on_record)
	var water_a := add_interactable(900, 250, 80, "Reach for the water (E)")
	water_a.used.connect(_on_water)

	await Game.wake(1.8)
	await Game.say("You're so tired. You just need to sleep. To stop, for a while.", 3.2)
	player.can_move = true

func setup_room() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# dim carpet floor
	var floors := Node2D.new(); add_child(floors)
	var carpet: Texture2D = load(A + "floor_carpet.png")
	for ix in range(8):
		for iy in range(6):
			var sp := Sprite2D.new()
			sp.texture = carpet; sp.centered = false
			sp.position = Vector2(320 + ix * 64, 200 + iy * 64); sp.scale = Vector2(2, 2)
			sp.modulate = Color(0.5, 0.5, 0.6)
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			floors.add_child(sp)
	# bed + nightstand
	_dim_prop(A + "bed.png", 640, 250, 2.2)
	_dim_prop(A + "nightstand.png", 900, 330, 2.0)
	_reach = _dim_prop("res://assets/art/props/record.png", 900, 360, 2.0)  # recording on stand
	_dim_prop("res://assets/art/props/mug.png", 900, 250, 2.0)              # the "water" cup

	# bounds
	_wall(300, 180, 24, 420); _wall(840, 180, 24, 420)
	_wall(300, 180, 560, 24); _wall(300, 580, 560, 24)

	# darkness overlays
	var cl := CanvasLayer.new(); cl.layer = 8; add_child(cl)
	_dark = ColorRect.new(); _dark.color = Color(0, 0, 0.02, 0.35)
	_dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_dark)
	_vig = TextureRect.new(); _vig.texture = load(FX + "vignette.png")
	_vig.stretch_mode = TextureRect.STRETCH_SCALE
	_vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vig.modulate = Color(1, 1, 1, 0.4)
	_vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_vig)

func _dim_prop(path: String, x: float, y: float, s: float) -> Sprite2D:
	var tex: Texture2D = load(path)
	var sp := Sprite2D.new()
	sp.texture = tex; sp.centered = false
	sp.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
	sp.position = Vector2(x, y); sp.scale = Vector2(s, s)
	sp.modulate = Color(0.55, 0.55, 0.66)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)
	return sp

func _darken(to: float, dur := 1.5) -> void:
	create_tween().tween_property(_dark, "color:a", to, dur)
	create_tween().tween_property(_vig, "modulate:a", min(1.0, to + 0.3), dur)

func _on_bed(_a) -> void:
	if _step != 0: return
	_step = 1
	player.can_move = false
	await Game.say("You lie down. You close your eyes.", 2.6)
	await Game.say("Nothing. Your mind keeps running. Sleep won't come.", 3.0)
	_darken(0.5)
	Game.flash("Their voice is still on the recorder. (the nightstand)", 3.0)
	player.can_move = true

func _on_record(_a) -> void:
	if _step != 1: return
	_step = 2
	player.can_move = false
	await Game.say("\"Hey — it's me. Call me back when you get this, okay?\"", 3.4)
	await Game.say("\"...I'm not angry. I never really was. Talk soon.\"", 3.4)
	await Game.say("You play it again. And again. It doesn't bring them back.", 3.2)
	_darken(0.72)
	Game.flash("Your throat is dry. There's water on the stand.", 2.8)
	player.can_move = true

func _on_water(_a) -> void:
	if _step != 2 or _mashing: return
	_mashing = true
	player.can_move = false
	_make_bar()
	Game.flash("Reach for it — keep pressing E.", 2.2)

func _make_bar() -> void:
	var cl := CanvasLayer.new(); cl.layer = 9; add_child(cl)
	_bar = ProgressBar.new()
	_bar.min_value = 0; _bar.max_value = 100; _bar.value = 0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(420, 30)
	_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_bar.position = Vector2(-210, 120)
	cl.add_child(_bar)

func _unhandled_input(event: InputEvent) -> void:
	if not _mashing or _done:
		return
	if event.is_action_pressed("ui_accept"):
		_mash += 1
		_bar.value = min(100, _mash * 9)
		# the arm strains a little closer each press, then drains back
		create_tween().tween_property(_reach, "position:x", _reach.position.x - 2, 0.06)
		if _bar.value >= 100:
			_collapse()

func _collapse() -> void:
	_done = true
	_mashing = false
	await Game.say("Your fingers brush the glass —", 2.0)
	await Game.say("— and the room tips sideways.", 2.0)
	# pass out: fade to a soft white that becomes the acceptance dawn
	var t := create_tween()
	t.tween_property(_dark, "color", Color(1, 1, 1, 1), 2.2)
	await t.finished
	GameState.complete_stage("Depression", "The recording — grief is the love with nowhere to go.")
	Game.change_scene("res://scenes/stages/stage_acceptance.tscn")
