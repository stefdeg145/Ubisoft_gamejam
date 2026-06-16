extends CharacterBody2D
## 4-direction, code-animated player. The walk sheets the artist supplied were
## sliced into 4 frames per direction (down/left/up/right); right is the mirror
## of the supplied left walk. Animation is driven here so no SpriteFrames
## resource is needed and the whole thing stays data-light for git.

@export var speed: float = 120.0
@export var can_move: bool = true
## Side-view stages set this so the character only walks left/right.
@export var lock_vertical: bool = false

const FRAME_TIME := 0.14
const DIRS := ["down", "left", "up", "right"]

var _frames := {}                 # dir -> Array[Texture2D]
var _facing := "down"
var _frame := 0
var _timer := 0.0
@onready var _sprite: Sprite2D = $Sprite
@onready var _walk_sound: AudioStreamPlayer2D = $WalkSound

## The interactable currently in range (legacy single-target, e.g. stage props), or null.
var nearby_object: Node = null
## All interactables currently overlapping; on interact we pick the closest.
var _interactables: Array = []

func add_interactable(o: Node) -> void:
	if not _interactables.has(o):
		_interactables.append(o)

func remove_interactable(o: Node) -> void:
	_interactables.erase(o)
	if nearby_object == o:
		nearby_object = null

func _closest_interactable() -> Node:
	var best: Node = null
	var best_d := INF
	for o in _interactables:
		if not is_instance_valid(o):
			continue
		var d := global_position.distance_to(o.global_position)
		if d < best_d:
			best_d = d
			best = o
	# fall back to the legacy single-target system used by stage props
	if best == null and is_instance_valid(nearby_object):
		best = nearby_object
	return best

## Floating "E" shown above the closest interactable so the player can tell what
## responds. Lives in world space (top_level) and is repositioned each frame.
var _hint: Label

func _ready() -> void:
	add_to_group("player")
	for d in DIRS:
		var arr: Array = []
		for i in range(4):
			arr.append(load("res://assets/art/characters/walk_%s_%d.png" % [d, i]))
		_frames[d] = arr
	_apply_frame()
	_make_hint()

func _make_hint() -> void:
	_hint = Label.new()
	_hint.text = "E"
	_hint.top_level = true
	_hint.z_index = 200
	_hint.visible = false
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.custom_minimum_size = Vector2(16, 0)
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(0.96, 0.94, 0.86))
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_hint.add_theme_constant_override("shadow_offset_x", 1)
	_hint.add_theme_constant_override("shadow_offset_y", 1)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.08, 0.1, 0.6)
	box.set_corner_radius_all(4)
	box.content_margin_left = 5
	box.content_margin_right = 5
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	_hint.add_theme_stylebox_override("normal", box)
	add_child(_hint)

func _update_hint() -> void:
	if _hint == null:
		return
	var target := _closest_interactable()
	if can_move and target != null and target is Node2D:
		var bob := sin(Time.get_ticks_msec() / 200.0) * 2.0
		# Sit the "E" just above the actual object, centred on it, so it always
		# reads as belonging to that piece of furniture regardless of its size.
		var anchor := _hint_anchor(target)
		var half_w: float = max(_hint.size.x, 16.0) * 0.5
		_hint.global_position = anchor + Vector2(-half_w, bob)
		_hint.visible = true
	else:
		_hint.visible = false

## World-space point the "E" should hover over for a given interactable. Prefers
## the object's real sprite (top-centre of its drawn rect), so moving or resizing
## furniture keeps the pill correctly placed.
func _hint_anchor(target: Node) -> Vector2:
	var spr = target.get("follow_target")
	if spr == null or not is_instance_valid(spr):
		spr = target.get("source_sprite")
	if spr != null and is_instance_valid(spr) and spr is Sprite2D and (spr as Sprite2D).texture != null:
		return _sprite_top_center(spr) + Vector2(0, -10)
	return (target as Node2D).global_position + Vector2(0, -44)

## Top-centre of a Sprite2D's drawn rectangle in world space, handling both
## centred and offset sprites.
func _sprite_top_center(spr: Sprite2D) -> Vector2:
	var ts: Vector2 = spr.texture.get_size()
	var base_tl: Vector2 = spr.offset
	if spr.centered:
		base_tl -= ts * 0.5
	var world_tl: Vector2 = spr.global_position + base_tl * spr.scale
	return Vector2(world_tl.x + ts.x * spr.scale.x * 0.5, world_tl.y)

func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if can_move:
		dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if lock_vertical:
		dir.y = 0.0
	velocity = dir * speed
	move_and_slide()

	var moving := dir.length() > 0.1
	if moving:
		# choose facing by dominant axis (side-view stages stay left/right)
		if lock_vertical or abs(dir.x) > abs(dir.y):
			_facing = "right" if dir.x > 0 else "left"
		else:
			_facing = "down" if dir.y > 0 else "up"
		_timer += delta
		if _timer >= FRAME_TIME:
			_timer = 0.0
			_frame = (_frame + 1) % 4
			_apply_frame()
	else:
		if _frame != 0:
			_frame = 0
			_apply_frame()
	_update_walk_sound(moving)
	_update_hint()

func _update_walk_sound(moving: bool) -> void:
	if _walk_sound == null:
		return
	if moving:
		if not _walk_sound.playing:
			_walk_sound.play()
	elif _walk_sound.playing:
		_walk_sound.stop()

func _apply_frame() -> void:
	if _sprite and _frames.has(_facing):
		_sprite.texture = _frames[_facing][_frame]

func _unhandled_input(event: InputEvent) -> void:
	if not can_move:
		return
	if event.is_action_pressed("ui_accept"):
		var target := _closest_interactable()
		if target != null and target.has_method("interact"):
			target.interact()

func face(dir: String) -> void:
	_facing = dir
	_frame = 0
	_apply_frame()
