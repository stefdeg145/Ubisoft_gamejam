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

## While true, every prop steers the player to the sympathy cards first instead of
## its usual weary line. The house sets this on a fresh start and clears it once
## the cards have been read.
var gated := false
@export var gated_lines: PackedStringArray = [
	"...Not now. Those cards on the table. I should read them first.",
	"Later. I can't look at this yet — not before I've read them.",
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
	if gated:
		if gated_lines.size() > 0:
			Game.flash(gated_lines[randi() % gated_lines.size()], 2.8)
		return
	if lines.size() > 0:
		Game.flash(lines[randi() % lines.size()], 2.4)
