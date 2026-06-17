extends Area2D
## A bed the player can try to sleep in. Only their own bed (is_my_bed) lets them
## drift off into the dream; every other bed is met with quiet grief.

signal chosen(node)

## The furniture sprite this zone wraps; lets the floating "E" anchor to the
## object's real position so it stays correct when the furniture is moved.
var source_sprite: Node2D = null

@export var is_my_bed := false
@export_file("*.tscn") var stage_scene: String = "res://scenes/stages/stage_denial.tscn"
@export var not_my_bed_lines: PackedStringArray = [
	"...This isn't my bed. I can't sleep here.",
	"Not this one. It still smells like them.",
	"This was never mine. I shouldn't be lying here.",
]
## When true, even your own bed won't let you sleep yet (e.g. the sympathy cards
## still need reading first). The house flips this off once that's done.
@export var sleep_locked := false
@export var locked_sleep_lines: PackedStringArray = [
	"Not yet. I can't close my eyes. ...Those cards on the table. I should read them first.",
	"I can't sleep. Not until I've read what they left.",
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
	if sleep_locked:
		if locked_sleep_lines.size() > 0:
			Game.flash(locked_sleep_lines[randi() % locked_sleep_lines.size()], 3.2)
		return
	if _used:
		return
	_used = true
	chosen.emit(self)
