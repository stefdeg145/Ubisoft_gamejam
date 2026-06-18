extends Node2D
class_name AngerSequence
## STAGE 2 — ANGER · "Everything in the Way" (the first Bleed, in the waking house).
##
## After Denial, the house hands the griever a tidy little to-do list — and then
## refuses to let any of it go right. Each chore fumbles out of their hands,
## anger words bleed into the air and the room turns colder, until the last chore
## (washing Eli's mug) becomes the breaking point: the player aims and HURLS the
## mug, it arcs and spins across the room and shatters on a wall or the floor.
## Then stillness — the anger is spent, the photograph is pocketed, the house
## warms a notch, and Bargaining is armed.
##
## Self-contained: the house builds it, calls setup() + start(), and waits for
## the `finished` signal. Honouring the requested design, this stage deliberately
## breaks the game's usual "no HUD" rule — the nagging quest panel IS the irritant.

signal finished

# ---- wiring from the house ------------------------------------------------
var player: CharacterBody2D
var world: Node2D
var bounds: Rect2 = Rect2(64, 128, 896, 512)   # play area; mug shatters if it leaves it
var rug: Node2D
var chair: Node2D
var table_top: Vector2 = Vector2(700, 300)     # where the mug sits / is thrown from area

# ---- tuning ---------------------------------------------------------------
const SHATTER_SFX := "res://assets/Sound/Mug_Breaking.mp3"
const RUG_SFX := "res://assets/Sound/New_Rustling_Rug.wav"
const CHAIR_SFX := "res://assets/Sound/New_Moving_wood_or_chair.wav"
const THROW_SPEED := 360.0     # horizontal launch speed (px/s)
const THROW_VZ := 300.0        # initial upward "height" speed (fake Z)
const GRAVITY := 650.0         # fake-Z gravity
const SPIN := 14.0             # mug spin while airborne (rad/s)
const AIM_RATE := 2.4          # how fast A/D swing the aim (rad/s)
const FLOAT_WORDS := ["won't stay", "again", "stop", "why", "still here",
	"not fair", "too quiet", "enough"]

# ---- quest data -----------------------------------------------------------
var _quests := [
	{"title": "STRAIGHTEN THE RUG", "kind": "rug", "tries": 2, "state": 0},
	{"title": "PUSH IN THE CHAIR", "kind": "chair", "tries": 2, "state": 0},
	{"title": "WASH THE MUG", "kind": "mug", "tries": 2, "state": 0},
]
var _qi := 0
var _attempt := 0
var _busy := false
var _running := false

# ---- nodes ----------------------------------------------------------------
var _ui_layer: CanvasLayer
var _panel: Panel
var _shadow_panel: Panel
var _rows: Array = []           # Label per quest
var _cold_layer: CanvasLayer
var _cold: ColorRect
var _cold_level := 0.0
var _zone: Area2D
var _mug: Sprite2D
var _shadow: Sprite2D
var _aim_arrow: Line2D
var _sfx: AudioStreamPlayer
var _world_home := Vector2.ZERO

# ---- throw state ----------------------------------------------------------
var _aiming := false
var _flying := false
var _aim_angle := 0.0
var _g_pos := Vector2.ZERO       # mug ground position
var _z := 0.0                    # mug height
var _vz := 0.0
var _vel := Vector2.ZERO

# ===========================================================================
func setup(p_player: CharacterBody2D, p_world: Node2D, p_bounds: Rect2,
		p_rug: Node2D, p_chair: Node2D, p_table_top: Vector2) -> void:
	player = p_player
	world = p_world
	bounds = p_bounds
	rug = p_rug
	chair = p_chair
	table_top = p_table_top

func _ready() -> void:
	_world_home = world.position if world else Vector2.ZERO
	_build_cold()
	_build_ui()
	_build_mug()
	_sfx = AudioStreamPlayer.new()
	_sfx.stream = load(SHATTER_SFX)
	add_child(_sfx)
	InputManager.device_changed.connect(_on_device_changed)

# ---------------------------------------------------------------- the flow
func start() -> void:
	_running = true
	player.can_move = false
	# The rug sits crooked from the outset, so the first "straighten it" actually
	# has something to straighten (it reads as wrong before you ever touch it).
	if rug and is_instance_valid(rug):
		rug.rotation = deg_to_rad(-10.0)
	await Game.say("Awake again. The house feels wrong, like a held breath.", 3.0)
	await Game.say("...Tidy up. Make it normal. You can at least do that.", 3.2)
	_show_ui()
	player.can_move = true
	_spawn_zone()

func _spawn_zone() -> void:
	if _zone and is_instance_valid(_zone):
		# Drop the player's pointer to the old zone too — freeing an Area2D does not
		# reliably emit body_exited, so a stale reference could fire the wrong quest.
		if player and player.nearby_object == _zone:
			player.nearby_object = null
		_zone.queue_free()
	if _qi >= _quests.size():
		return
	var q = _quests[_qi]
	var target: Node2D = _quest_target(q["kind"])
	_zone = Area2D.new()
	_zone.set_script(load("res://scripts/interactable.gd"))
	_zone.prompt = _quest_prompt(q["kind"])
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 84.0
	cs.shape = sh
	_zone.add_child(cs)
	world.add_child(_zone)
	if target != null:
		_zone.bind_to(target)
	else:
		_zone.global_position = table_top
	_zone.used.connect(_on_quest_used)
	_highlight_row()

func _quest_target(kind: String) -> Node2D:
	match kind:
		"rug": return rug
		"chair": return chair
		"mug": return _mug
	return null

func _quest_prompt(kind: String) -> String:
	var btn: String = InputManager.hint("accept")
	match kind:
		"rug": return "Straighten it (%s)" % btn
		"chair": return "Push it in (%s)" % btn
		"mug": return "Wash the mug (%s)" % btn
	return "(%s)" % btn

func _on_quest_used(_area) -> void:
	if _busy or not _running or _qi >= _quests.size():
		return
	_busy = true
	Game.hide_prompt()
	var q = _quests[_qi]
	_attempt += 1
	match q["kind"]:
		"rug": await _fumble_rug()
		"chair": await _fumble_chair()
		"mug": await _fumble_mug()
	_busy = false

# ---------------------------------------------------------------- fumbles
func _fumble_rug() -> void:
	_anger_beat()
	Sfx.play(RUG_SFX)                    # the rug rustling as it's tugged (no haptic — it's light)
	var base := rug.rotation
	var t := create_tween()
	t.tween_property(rug, "rotation", base + 0.18, 0.12)   # tug it straight...
	t.tween_property(rug, "rotation", base - 0.14, 0.25)   # ...it flops crooked
	await t.finished
	if _attempt == 1:
		await Game.say("It won't lie flat. ...There. No—", 2.4)
	else:
		await Game.say("Why won't it just STAY down.", 2.2)
		await _botch_and_advance()

func _fumble_chair() -> void:
	_anger_beat()
	# A heavy wooden chair shoved in frustration — the strongest of the chore rumbles.
	Haptics.rumble("heavy")
	Sfx.play(CHAIR_SFX)                  # wood scraping the floor as the chair drags
	var home := chair.position
	var t := create_tween()
	t.tween_property(chair, "position", home + Vector2(0, -10), 0.12)  # push in...
	t.tween_property(chair, "position", home + Vector2(0, 14), 0.3)    # ...rolls back out
	t.tween_property(chair, "position", home, 0.15)
	await t.finished
	if _attempt == 1:
		await Game.say("Push it in. It just— rolls back out.", 2.4)
	else:
		await Game.say("Stay where I PUT you—", 2.0)
		await _botch_and_advance()

func _fumble_mug() -> void:
	_anger_beat()
	# The mug skids across the table — a lighter, scraping buzz than the chair.
	Haptics.rumble("medium")
	# the mug slides toward the table edge with each grab
	var slip := Vector2(34, 6) * _attempt
	var t := create_tween()
	t.tween_property(_mug, "global_position", table_top + slip, 0.18)
	t.tween_property(_mug, "rotation", deg_to_rad(8.0 * _attempt), 0.1)
	await t.finished
	if _attempt < _quests[_qi]["tries"]:
		await Game.say("Their mug. Just— wash it. It won't sit still.", 2.6)
	else:
		await Game.say("It won't— my hands won't—", 1.8)
		await _breaking_point()

func _botch_and_advance() -> void:
	_quests[_qi]["state"] = 2          # botched
	_set_row(_qi)
	_qi += 1
	_attempt = 0
	await get_tree().create_timer(0.4).timeout
	if _qi < _quests.size():
		_spawn_zone()

# ---------------------------------------------------------------- anger fx
func _anger_beat() -> void:
	_spawn_float(FLOAT_WORDS[randi() % FLOAT_WORDS.size()])
	_cold_level = min(0.46, _cold_level + 0.12)
	# a cold throb that settles into the new, higher baseline
	var t := create_tween()
	t.tween_property(_cold, "color:a", _cold_level + 0.16, 0.1)
	t.tween_property(_cold, "color:a", _cold_level, 0.5)

func _spawn_float(word: String) -> void:
	var l := Label.new()
	l.text = word
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(0.86, 0.88, 0.95))
	l.modulate.a = 0.0
	l.z_index = 50
	l.top_level = true
	world.add_child(l)
	var start := player.global_position + Vector2(randf_range(-60, 60), -70 + randf_range(-20, 20))
	l.global_position = start
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(l, "modulate:a", 0.55, 0.5)
	t.tween_property(l, "global_position", start + Vector2(randf_range(-20, 20), -46), 1.7)
	t.chain().tween_property(l, "modulate:a", 0.0, 0.6)
	t.chain().tween_callback(l.queue_free)

# ---------------------------------------------------------------- breaking point
func _breaking_point() -> void:
	_running = false
	player.can_move = false
	Game.hide_prompt()
	if _zone and is_instance_valid(_zone):
		_zone.queue_free()
	_set_row_breaking()
	await Game.say("Why won't anything just— STAY—", 2.2)
	# The house keeps its music + rain going through the throw (no dramatic silence).
	# the mug lifts to the hand: snap it to the player and start aiming
	_mug.rotation = 0.0
	_mug.global_position = player.global_position + Vector2(0, -28)
	_aim_angle = -PI / 2.0      # start aiming "up"/away
	_make_aim_arrow()
	_aiming = true
	if InputManager.is_controller():
		Game.show_prompt("Aim with Left Stick  —  throw", "A")
	else:
		Game.show_prompt("Aim with A / D   —   E to throw")

func _make_aim_arrow() -> void:
	_aim_arrow = Line2D.new()
	_aim_arrow.width = 3.0
	_aim_arrow.default_color = Color(0.95, 0.4, 0.32, 0.9)
	_aim_arrow.z_index = 60
	_aim_arrow.top_level = true
	world.add_child(_aim_arrow)
	_update_aim_arrow()

func _update_aim_arrow() -> void:
	if _aim_arrow == null:
		return
	var origin := player.global_position + Vector2(0, -20)
	var dir := Vector2.RIGHT.rotated(_aim_angle)
	var tip := origin + dir * 78.0
	_aim_arrow.points = PackedVector2Array([origin, tip,
		tip - dir.rotated(0.5) * 16.0, tip, tip - dir.rotated(-0.5) * 16.0])

func _launch() -> void:
	_aiming = false
	Game.hide_prompt()
	if _aim_arrow and is_instance_valid(_aim_arrow):
		_aim_arrow.queue_free()
	var dir := Vector2.RIGHT.rotated(_aim_angle)
	_g_pos = player.global_position
	_z = 28.0
	_vz = THROW_VZ
	_vel = dir * THROW_SPEED
	_flying = true
	# The release — a hard kick as the mug leaves the hand (the shatter hits harder).
	Haptics.rumble("throw")

# ---------------------------------------------------------------- device switch
func _on_device_changed(_device: String) -> void:
	# Refresh the throw prompt if currently aiming
	if _aiming:
		if InputManager.is_controller():
			Game.show_prompt("Aim with Left Stick  —  throw", "A")
		else:
			Game.show_prompt("Aim with A / D   —   E to throw")
	# Refresh quest prompt if a zone is active
	if _zone and is_instance_valid(_zone) and _running and not _busy:
		if _qi < _quests.size():
			_zone.prompt = _quest_prompt(_quests[_qi]["kind"])

# ---------------------------------------------------------------- per-frame
func _process(dt: float) -> void:
	if _aiming:
		var turn := Input.get_axis("ui_left", "ui_right")
		_aim_angle += turn * AIM_RATE * dt
		_update_aim_arrow()
		return
	if _flying:
		_step_throw(dt)

func _step_throw(dt: float) -> void:
	_z += _vz * dt
	_vz -= GRAVITY * dt
	_g_pos += _vel * dt
	_mug.global_position = _g_pos + Vector2(0, -_z)
	_mug.rotation += SPIN * dt
	if _shadow:
		_shadow.global_position = _g_pos
		var k: float = clampf(1.0 - _z / 240.0, 0.35, 1.0)
		_shadow.scale = Vector2(2, 1) * k
		_shadow.modulate.a = 0.35 * k
	# impact: left the room (a wall) or came back down to the floor
	if not bounds.has_point(_g_pos):
		_g_pos.x = clampf(_g_pos.x, bounds.position.x, bounds.end.x)
		_g_pos.y = clampf(_g_pos.y, bounds.position.y, bounds.end.y)
		_shatter()
	elif _z <= 0.0 and _vz < 0.0:
		_shatter()

func _unhandled_input(event: InputEvent) -> void:
	if _aiming and event.is_action_pressed("ui_accept"):
		_launch()

# ---------------------------------------------------------------- shatter
func _shatter() -> void:
	_flying = false
	var at := _g_pos
	_mug.visible = false
	if _shadow:
		_shadow.visible = false
	if _sfx.stream:
		_sfx.play()
	_spawn_shards(at)
	_screen_shake()
	# The biggest hit in the game — the mug shattering against the wall.
	Haptics.rumble("impact")
	_resolve(at)

func _spawn_shards(at: Vector2) -> void:
	var tex: Texture2D = _mug.texture
	for i in range(9):
		var s := Sprite2D.new()
		s.texture = tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(1.0, 1.0) * randf_range(0.5, 1.0)
		s.region_enabled = true
		# take a random quarter-ish slice of the mug so each shard looks like a piece
		var ts := tex.get_size()
		s.region_rect = Rect2(randf() * ts.x * 0.5, randf() * ts.y * 0.5,
			ts.x * 0.5, ts.y * 0.5)
		s.global_position = at
		s.z_index = 55
		s.top_level = true
		world.add_child(s)
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		var dest := at + dir * randf_range(30, 90) + Vector2(0, randf_range(10, 40))
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(s, "global_position", dest, randf_range(0.35, 0.7))
		t.tween_property(s, "rotation", randf_range(-6, 6), 0.6)
		t.tween_property(s, "modulate:a", 0.0, 0.7)
		t.chain().tween_callback(s.queue_free)

func _screen_shake() -> void:
	var t := create_tween()
	for i in range(8):
		t.tween_property(world, "position",
			_world_home + Vector2(randf_range(-7, 7), randf_range(-7, 7)), 0.035)
	t.tween_property(world, "position", _world_home, 0.06)

# ---------------------------------------------------------------- resolve
func _resolve(_at: Vector2) -> void:
	# the anger is spent: floats fade, the cold lifts a little, the room exhales
	var t := create_tween()
	t.tween_property(_cold, "color:a", 0.0, 2.5)
	await get_tree().create_timer(1.2).timeout
	await Game.say("...oh.", 1.6)
	await Game.say("I'm sorry. I'm not angry at you.", 2.6)
	await Game.say("I'm angry that you're gone.", 2.8)
	# The words are out — the room can breathe again. BGM + rain ease back in.
	_resume_surrounding_audio()
	_hide_ui()
	# He's spent. The photo he always carries is still in his pocket — the couch
	# flow (in the house) is where he finally sits down and looks at it.
	GameState.has_photo = true
	GameState.complete_stage("Anger", "the unfair — anger is love with nowhere to go")
	_running = false
	emit_signal("finished")

# ---------------------------------------------------------------- surrounding audio
## The bleed runs inside the house, which owns the BGM + rain. We're parented to
## it, so ask it to hush/resume. Guarded so this is harmless if the parent ever
## changes or lacks the methods (e.g. when run standalone for testing).
func _hush_surrounding_audio() -> void:
	var host := get_parent()
	if host and host.has_method("hush_house_audio"):
		host.hush_house_audio()

func _resume_surrounding_audio() -> void:
	var host := get_parent()
	if host and host.has_method("resume_house_audio"):
		host.resume_house_audio()

# ---------------------------------------------------------------- build bits
func _build_mug() -> void:
	_shadow = Sprite2D.new()
	_shadow.texture = _soft_shadow_tex()
	_shadow.scale = Vector2(2, 1)
	_shadow.modulate = Color(0, 0, 0, 0.35)
	_shadow.global_position = table_top
	_shadow.z_index = 1
	world.add_child(_shadow)

	_mug = Sprite2D.new()
	_mug.texture = load("res://assets/art/props/mug.png")
	_mug.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mug.scale = Vector2(2, 2)
	_mug.global_position = table_top
	_mug.z_index = 30
	world.add_child(_mug)

func _soft_shadow_tex() -> Texture2D:
	var img := Image.create(16, 10, false, Image.FORMAT_RGBA8)
	for y in range(10):
		for x in range(16):
			var d := Vector2(x - 7.5, (y - 4.5) * 1.6).length() / 8.0
			img.set_pixel(x, y, Color(0, 0, 0, clampf(1.0 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

func _build_cold() -> void:
	_cold_layer = CanvasLayer.new()
	_cold_layer.layer = 6
	add_child(_cold_layer)
	_cold = ColorRect.new()
	_cold.color = Color(0.10, 0.12, 0.20, 0.0)
	_cold.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cold_layer.add_child(_cold)

# ---------------------------------------------------------------- quest UI
func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 20
	add_child(_ui_layer)

	# drop shadow panel (gives the pixel UI some depth)
	var shadow := Panel.new()
	shadow.position = Vector2(28, 28)
	shadow.size = Vector2(300, 168)
	shadow.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0)))
	shadow.modulate.a = 0.0
	_ui_layer.add_child(shadow)
	_shadow_panel = shadow

	var panel := Panel.new()
	panel.position = Vector2(24, 24)
	panel.size = Vector2(300, 168)
	panel.add_theme_stylebox_override("panel",
		_box(Color(0.07, 0.07, 0.09, 0.94), Color(0.82, 0.79, 0.70, 1.0)))
	panel.modulate.a = 0.0
	_ui_layer.add_child(panel)
	_panel = panel

	var vb := VBoxContainer.new()
	vb.position = Vector2(18, 14)
	vb.custom_minimum_size = Vector2(266, 0)
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "T O   D O"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.95, 0.92, 0.82))
	vb.add_child(title)

	var rule := ColorRect.new()
	rule.color = Color(0.82, 0.79, 0.70, 0.6)
	rule.custom_minimum_size = Vector2(264, 2)
	vb.add_child(rule)

	for i in _quests.size():
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 18)
		row.text = _row_text(i)
		row.add_theme_color_override("font_color", Color(0.62, 0.62, 0.66))
		vb.add_child(row)
		_rows.append(row)

func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.set_corner_radius_all(0)       # hard pixel corners
	if border.a > 0.0:
		b.set_border_width_all(3)
		b.border_color = border
	b.content_margin_left = 10
	b.content_margin_right = 10
	b.content_margin_top = 8
	b.content_margin_bottom = 8
	return b

func _row_text(i: int) -> String:
	var q = _quests[i]
	match int(q["state"]):
		0: return "[  ]  " + q["title"]
		1: return "[ x ]  " + q["title"]
		2: return "[ ! ]  " + q["title"] + "   ...no"
	return q["title"]

func _set_row(i: int) -> void:
	if i < _rows.size():
		_rows[i].text = _row_text(i)
		if int(_quests[i]["state"]) == 2:
			_rows[i].add_theme_color_override("font_color", Color(0.85, 0.36, 0.32))

func _set_row_breaking() -> void:
	# the final line scrawls into something furious
	if _qi < _rows.size():
		_rows[_qi].text = "[ x ]  WASH THE M—"
		_rows[_qi].add_theme_color_override("font_color", Color(0.9, 0.3, 0.26))

func _highlight_row() -> void:
	for i in _rows.size():
		var active := i == _qi and int(_quests[i]["state"]) == 0
		var c := Color(0.96, 0.93, 0.84) if active else Color(0.6, 0.6, 0.64)
		if int(_quests[i]["state"]) == 2:
			c = Color(0.85, 0.36, 0.32)
		_rows[i].add_theme_color_override("font_color", c)
		var mark := "› " if active else "  "
		var base := _row_text(i)
		_rows[i].text = mark + base

func _show_ui() -> void:
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_panel, "modulate:a", 1.0, 0.6)
	t.tween_property(_shadow_panel, "modulate:a", 1.0, 0.6)

func _hide_ui() -> void:
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_panel, "modulate:a", 0.0, 1.2)
	t.tween_property(_shadow_panel, "modulate:a", 0.0, 1.2)
