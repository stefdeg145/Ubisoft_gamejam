extends Area2D

## Which grief stage this memory belongs to.
@export var stage_name: String = "Denial"

## Only the currently-active memory can be entered. The rest stay locked.
@export var is_ready: bool = false

## The line shown when the player tries a memory they're not ready for yet.
@export_multiline var locked_line: String = "...Not yet. I can't look at that one yet."

## Fires when the player successfully enters this memory.
signal entered_memory(stage_name)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.nearby_object = self

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player") and body.nearby_object == self:
		body.nearby_object = null

func interact() -> void:
	if is_ready:
		print("Entering memory: ", stage_name)
		entered_memory.emit(stage_name)
		# Later: play the drift-to-sleep transition, then load the level scene.
	else:
		print(locked_line)
		# Later: show this line on screen instead of printing to the console.
