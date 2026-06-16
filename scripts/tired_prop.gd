extends Area2D
## A piece of furniture the grieving player is too exhausted to engage with.
## Interacting just surfaces a weary thought that nudges them toward sleep.

## The furniture sprite this zone wraps; lets the floating "E" anchor to the
## object's real position so it stays correct when the furniture is moved.
var source_sprite: Node2D = null

@export var lines: PackedStringArray = [
	"I'm so tired. I should just sleep.",
	"I can't... I can barely keep my eyes open.",
	"Not now. I just need to lie down.",
	"My head's too heavy for any of this.",
]

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
	if lines.size() > 0:
		Game.flash(lines[randi() % lines.size()], 2.4)
