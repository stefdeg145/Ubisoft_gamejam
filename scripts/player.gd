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

## The memory object currently in range (set by memory_object.gd), or null.
var nearby_object: Node = null

func _ready() -> void:
	add_to_group("player")
	for d in DIRS:
		var arr: Array = []
		for i in range(4):
			arr.append(load("res://assets/art/characters/walk_%s_%d.png" % [d, i]))
		_frames[d] = arr
	_apply_frame()

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
	if event.is_action_pressed("ui_accept") and nearby_object != null:
		nearby_object.interact()

func face(dir: String) -> void:
	_facing = dir
	_frame = 0
	_apply_frame()
