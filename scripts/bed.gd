extends Area2D
## A bed the player can try to sleep in. Only their own bed (is_my_bed) lets them
## drift off into the dream; every other bed is met with quiet grief.

signal chosen(node)

@export var is_my_bed := false
@export_file("*.tscn") var stage_scene: String = "res://scenes/stages/stage_denial.tscn"
@export var not_my_bed_lines: PackedStringArray = [
	"...This isn't my bed. I can't sleep here.",
	"Not this one. It still smells like them.",
	"This was never mine. I shouldn't be lying here.",
]

var _used := false

func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func _on_enter(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("add_interactable"):
		body.add_interactable(self)

func _on_exit(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("remove_interactable"):
		body.remove_interactable(self)

func interact() -> void:
	if not is_my_bed:
		if not_my_bed_lines.size() > 0:
			Game.flash(not_my_bed_lines[randi() % not_my_bed_lines.size()], 2.8)
		return
	if _used:
		return
	_used = true
	chosen.emit(self)
