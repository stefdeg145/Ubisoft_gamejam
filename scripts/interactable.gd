extends Area2D
## Lightweight interactable used inside the stage levels. Emits `used` when the
## player presses interact while in range. Scenes wire up what that means.

signal used(node)
@export var prompt: String = ""

func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func _on_enter(body: Node) -> void:
	if body.is_in_group("player"):
		body.nearby_object = self
		if prompt != "":
			Game.flash(prompt, 1.6)

func _on_exit(body: Node) -> void:
	if body.is_in_group("player"):
		Game.hide_prompt()
		if body.nearby_object == self:
			body.nearby_object = null

func interact() -> void:
	used.emit(self)
