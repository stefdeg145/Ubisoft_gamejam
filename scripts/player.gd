extends CharacterBody2D

## Top-down movement speed, in pixels per second.
@export var speed: float = 130.0

## The memory-object the player is currently standing in range of, or null.
var nearby_object: Node = null

func _ready() -> void:
	add_to_group("player")

func _physics_process(_delta: float) -> void:
	# Arrow keys work out of the box. (Add WASD later in Project > Input Map.)
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	# Enter or Space interacts with whatever object you're standing next to.
	if event.is_action_pressed("ui_accept") and nearby_object != null:
		nearby_object.interact()
