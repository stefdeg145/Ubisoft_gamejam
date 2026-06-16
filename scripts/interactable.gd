extends Area2D
## Lightweight interactable used inside the stage levels. Emits `used` when the
## player presses interact while in range. Scenes wire up what that means.
##
## If `follow_target` is set (via `bind_to`), the trigger AND the floating "E"
## stay glued to that object every frame. Move the furniture wherever you like —
## now or later — and the interaction follows automatically, no re-aligning.

signal used(node)
@export var prompt: String = ""

## When set, this interactable snaps onto the target each frame.
var follow_target: Node2D = null
var follow_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	set_physics_process(follow_target != null)
	_snap()

## Glue this interactable to `target`. `offset` lets you nudge the trigger off the
## object's origin if needed (defaults to sitting right on it).
func bind_to(target: Node2D, offset: Vector2 = Vector2.ZERO) -> void:
	follow_target = target
	follow_offset = offset
	set_physics_process(true)
	if is_inside_tree():
		_snap()

func _physics_process(_delta: float) -> void:
	_snap()

func _snap() -> void:
	if follow_target == null:
		return
	if not is_instance_valid(follow_target):
		follow_target = null
		set_physics_process(false)
		return
	global_position = follow_target.global_position + follow_offset

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
