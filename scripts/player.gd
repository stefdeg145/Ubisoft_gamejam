extends CharacterBody2D

@export var speed: float = 130.0
var nearby_object: Node = null

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var walk_sound: AudioStreamPlayer2D = $walksound

var last_direction_animation: String = "Down"
var was_moving: bool = false

func _ready() -> void:
	add_to_group("player")

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("Left", "Right", "Up", "Down")
	velocity = direction * speed
	move_and_slide()
	
	update_animation(direction)
	update_walk_sound(direction != Vector2.ZERO)

func update_animation(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		# No movement: freeze animation on current frame (usually the first frame of the last animation)
		animated_sprite.stop()
		return
	
	# Determine which direction has the strongest influence
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			animated_sprite.play("Right")
			last_direction_animation = "Right"
		else:
			animated_sprite.play("Left")
			last_direction_animation = "Left"
	else:
		if direction.y > 0:
			animated_sprite.play("Down")
			last_direction_animation = "Down"
		else:
			animated_sprite.play("Up")
			last_direction_animation = "Up"

func update_walk_sound(is_moving: bool) -> void:
	if is_moving and not was_moving:
		walk_sound.play()
	elif not is_moving and was_moving:
		walk_sound.stop()
	
	was_moving = is_moving

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and nearby_object != null:
		nearby_object.interact()
