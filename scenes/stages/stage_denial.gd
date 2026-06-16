@tool
extends StageBase
## STAGE 1 — DENIAL · "The Ordinary Morning" (side-view kitchen).
## The room won't let things be wrong: every object you straighten quietly undoes
## itself, and the door stays sealed. The way through is to stop fixing — sit at
## the table and let the broken morning be broken.

# Adding 'set(value)' forces the editor to redraw immediately when changed
@export var background_texture: Texture2D:
	set(value):
		background_texture = value
		_setup_editor_visuals()

@export var background_scale := 8.0:
	set(value):
		background_scale = value
		_setup_editor_visuals()

@export_group("Fixable Objects")
@export var mug_sprite: Sprite2D:
	set(value):
		mug_sprite = value
		_setup_editor_visuals()
@export var mug_trigger: Area2D
@export var mug_tilt := -0.6:
	set(value):
		mug_tilt = value
		_setup_editor_visuals()

@export var plate_sprite: Sprite2D:
	set(value):
		plate_sprite = value
		_setup_editor_visuals()
@export var plate_trigger: Area2D

@export var chair_sprite: Sprite2D:
	set(value):
		chair_sprite = value
		_setup_editor_visuals()
@export var chair_trigger: Area2D

@export var painting_sprite: Sprite2D:
	set(value):
		painting_sprite = value
		_setup_editor_visuals()
@export var painting_trigger: Area2D
@export var painting_tilt := 0.3:
	set(value):
		painting_tilt = value
		_setup_editor_visuals()

@export_group("Interaction")
@export var sit_trigger: Area2D

var _tries := 0
var _resolved := false
var _fix_objects := {}

func _ready() -> void:
	if Engine.is_editor_hint():
		_setup_editor_visuals()
		return

	# RUNNING GAMEPLAY LOOP
	spawn_player(Vector2(230, 600), true)
	
	if player:
		player.face("right")

	# Ensure the scene tree is completely loaded before registering props
	await get_tree().process_frame

	_register_fix(mug_trigger, mug_sprite, mug_tilt)
	_register_fix(plate_trigger, plate_sprite, 0.0)
	_register_fix(chair_trigger, chair_sprite, 0.0)
	_register_fix(painting_trigger, painting_sprite, painting_tilt)

	if sit_trigger:
		sit_trigger.used.connect(_on_sit)

	await Game.wake(1.8)
	await Game.say("It's that morning again. An ordinary breakfast.", 3.0)
	await Game.say("But everything is a little out of place. Fix it. Make it normal.", 3.4)
	player.can_move = true

# This function updates your 2D editor view in real-time
func _setup_editor_visuals() -> void:
	# 1. Handle background generation inside the editor viewport
	var existing_bg = get_node_or_null("EditorBackgroundPreview")
	if existing_bg:
		existing_bg.queue_free()
		
	if background_texture:
		var bg_preview := Sprite2D.new()
		bg_preview.name = "EditorBackgroundPreview"
		bg_preview.texture = background_texture
		bg_preview.centered = false
		bg_preview.scale = Vector2(background_scale, background_scale)
		bg_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bg_preview.z_index = -100
		add_child(bg_preview)
		
	# 2. Handle object rotations inside the editor viewport
	if mug_sprite: 
		mug_sprite.rotation = mug_tilt
	if painting_sprite: 
		painting_sprite.rotation = painting_tilt

func _register_fix(area: Area2D, sp: Sprite2D, tilt: float) -> void:
	if not area or not sp: return
	sp.rotation = tilt
	area.used.connect(_on_fix)
	_fix_objects[area] = {"sprite": sp, "home_rot": tilt, "home_pos": sp.position}

func _on_fix(area: Area2D) -> void:
	if _resolved:
		return
	var d = _fix_objects.get(area)
	if d == null:
		return
	var sp: Sprite2D = d["sprite"]
	_tries += 1
	
	var t := create_tween()
	t.tween_property(sp, "rotation", 0.0, 0.25)
	if sp.rotation != 0:
		t.tween_property(sp, "position:y", sp.position.y - 6, 0.15)
	
	await t.finished
	await get_tree().create_timer(0.7).timeout
	
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
	
	for area in _fix_objects.keys():
		var sp: Sprite2D = _fix_objects[area]["sprite"]
		create_tween().tween_property(sp, "modulate:a", 0.5, 1.2)
	await Game.say("It was the last normal day. And it mattered.", 3.2)
	await finish("Denial", "The ordinary — the last normal morning mattered.")
