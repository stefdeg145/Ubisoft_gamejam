extends CharacterBody2D
## 4-direction, code-animated player. The walk sheets the artist supplied were
## sliced into 4 frames per direction (down/left/up/right); right is the mirror
## of the supplied left walk. Animation is driven here so no SpriteFrames
## resource is needed and the whole thing stays data-light for git.

@export var speed: float = 120.0
@export var can_move: bool = true
## Side-view stages set this so the character only walks left/right.
@export var lock_vertical: bool = false
## Cinematic auto-walk. When can_move is false and this is non-zero, the player
## walks in this direction under full animation + footsteps (used by the
## Acceptance walk-away). Set back to Vector2.ZERO to stop.
@export var auto_walk: Vector2 = Vector2.ZERO

const FRAME_TIME := 0.14
const DIRS := ["down", "left", "up", "right"]

## Grief-grade shader: the MC starts as a dark silhouette with only a glowing
## outline visible, then the fill brightens one notch per resolved stage until,
## at Acceptance, it renders fully normal. `brightness` 0 = silhouette+outline,
## 1 = untouched art.
const GRADE_SHADER := """
shader_type canvas_item;
render_mode unshaded;

uniform float brightness : hint_range(0.0, 1.0) = 0.0;
uniform vec4 outline_color : source_color = vec4(0.82, 0.88, 1.0, 1.0);
uniform float outline_width = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Fill fades up from black silhouette to full colour as stages complete.
	vec3 fill = tex.rgb * brightness;

	// Sample the 8 neighbours' alpha to find the sprite's edge.
	vec2 ps = TEXTURE_PIXEL_SIZE * outline_width;
	float maxa = 0.0;
	maxa = max(maxa, texture(TEXTURE, UV + vec2( ps.x, 0.0)).a);
	maxa = max(maxa, texture(TEXTURE, UV + vec2(-ps.x, 0.0)).a);
	maxa = max(maxa, texture(TEXTURE, UV + vec2(0.0,  ps.y)).a);
	maxa = max(maxa, texture(TEXTURE, UV + vec2(0.0, -ps.y)).a);
	maxa = max(maxa, texture(TEXTURE, UV + vec2( ps.x,  ps.y)).a);
	maxa = max(maxa, texture(TEXTURE, UV + vec2(-ps.x,  ps.y)).a);
	maxa = max(maxa, texture(TEXTURE, UV + vec2( ps.x, -ps.y)).a);
	maxa = max(maxa, texture(TEXTURE, UV + vec2(-ps.x, -ps.y)).a);

	// Outline lives just outside the silhouette and fades as brightness rises.
	float edge = step(tex.a, 0.001) * step(0.001, maxa);
	float outline_a = edge * (1.0 - brightness) * outline_color.a;

	vec3 col = mix(fill, outline_color.rgb, outline_a);
	float out_a = max(tex.a, outline_a);
	COLOR = vec4(col, out_a) * COLOR;
}
"""

var _frames := {}
var _facing := "down"
var _frame := 0
var _timer := 0.0
var _grade_mat: ShaderMaterial
var _brightness := -1.0  # forced to snap to the real value on first frame
@onready var _sprite: Sprite2D = $Sprite
@onready var _walk_sound: AudioStreamPlayer2D = $WalkSound

var nearby_object: Node = null
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
	if best == null and is_instance_valid(nearby_object):
		best = nearby_object
	return best

## Floating hint shown above the closest interactable.
## Keyboard: white "E" on dark rounded rectangle
## Controller: green "A" on dark circle (Xbox aesthetic)
var _hint: Label

func _ready() -> void:
	add_to_group("player")
	for d in DIRS:
		var arr: Array = []
		for i in range(4):
			arr.append(load("res://assets/art/characters/walk_%s_%d.png" % [d, i]))
		_frames[d] = arr
	_apply_frame()
	_setup_grade()
	_make_hint()
	InputManager.device_changed.connect(_on_device_changed)

## Builds the silhouette/outline shader and snaps brightness to the current
## stage progress so re-entering a scene shows the right level immediately.
func _setup_grade() -> void:
	var sh := Shader.new()
	sh.code = GRADE_SHADER
	_grade_mat = ShaderMaterial.new()
	_grade_mat.shader = sh
	if _sprite:
		_sprite.material = _grade_mat
	_brightness = _target_brightness()
	_grade_mat.set_shader_parameter("brightness", _brightness)

## 0.0 with nothing resolved, +1/5 per completed grief stage, 1.0 at the end.
func _target_brightness() -> float:
	var n: int = GameState.STAGES.size()
	if n <= 0:
		return 1.0
	return float(GameState.completed.size()) / float(n)

func _update_grade(delta: float) -> void:
	if _grade_mat == null:
		return
	var target := _target_brightness()
	# Ease toward the target so a stage clearing within a scene reveals gently.
	_brightness = move_toward(_brightness, target, delta * 0.6)
	_grade_mat.set_shader_parameter("brightness", _brightness)

func _make_hint() -> void:
	_hint = Label.new()
	_hint.top_level = true
	_hint.z_index = 200
	_hint.visible = false
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.add_theme_constant_override("shadow_offset_x", 1)
	_hint.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_hint)
	_refresh_hint_style()

## Updates text, color and shape based on current input device
func _refresh_hint_style() -> void:
	if _hint == null:
		return
	var is_ctrl := InputManager.is_controller()
	_hint.text = "A" if is_ctrl else "E"
	# Controller: larger green circle; Keyboard: smaller white rounded rect
	var size := 16
	_hint.add_theme_font_size_override("font_size", size)
	_hint.custom_minimum_size = Vector2(size + 8, size + 8)
	# Font color: Xbox green for controller, warm white for keyboard
	var font_col := Color(0.11, 0.85, 0.23) if is_ctrl else Color(0.96, 0.94, 0.86)
	_hint.add_theme_color_override("font_color", font_col)
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	var box := StyleBoxFlat.new()
	if is_ctrl:
		# Xbox A button: dark circle, green text
		box.bg_color = Color(0.08, 0.08, 0.1, 0.7)
		var r := int((size + 8) / 2)
		box.set_corner_radius_all(r)
		box.content_margin_left   = 4
		box.content_margin_right  = 4
		box.content_margin_top    = 4
		box.content_margin_bottom = 4
	else:
		# Keyboard E: dark rounded rectangle, white text
		box.bg_color = Color(0.08, 0.08, 0.1, 0.7)
		box.set_corner_radius_all(4)
		box.content_margin_left   = 5
		box.content_margin_right  = 5
		box.content_margin_top    = 2
		box.content_margin_bottom = 2
	_hint.add_theme_stylebox_override("normal", box)

func _on_device_changed(_device: String) -> void:
	_refresh_hint_style()

func _update_hint() -> void:
	if _hint == null:
		return
	var target := _closest_interactable()
	if can_move and target != null and target is Node2D:
		var bob := sin(Time.get_ticks_msec() / 200.0) * 2.0
		var anchor := _hint_anchor(target)
		var half_w: float = max(_hint.size.x, 16.0) * 0.5
		_hint.global_position = anchor + Vector2(-half_w, bob)
		_hint.visible = true
	else:
		_hint.visible = false

func _hint_anchor(target: Node) -> Vector2:
	var spr = target.get("follow_target")
	if spr == null or not is_instance_valid(spr):
		spr = target.get("source_sprite")
	if spr != null and is_instance_valid(spr) and spr is Sprite2D and (spr as Sprite2D).texture != null:
		return _sprite_top_center(spr) + Vector2(0, -10)
	return (target as Node2D).global_position + Vector2(0, -44)

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
	elif auto_walk != Vector2.ZERO:
		dir = auto_walk
	if lock_vertical:
		dir.y = 0.0
	velocity = dir * speed
	move_and_slide()

	var moving := dir.length() > 0.1
	if moving:
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
	_update_grade(delta)

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
