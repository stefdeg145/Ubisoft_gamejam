extends Area2D
## An interactable door. Press E / Enter while standing next to it to open or
## close it; an open door stops blocking the doorway so the player can pass.
## The two textures are assigned in the scene (closed / open states).

@export var closed_tex: Texture2D
@export var open_tex: Texture2D

var is_open := false

func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	_refresh()

func _on_enter(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("add_interactable"):
		body.add_interactable(self)

func _on_exit(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("remove_interactable"):
		body.remove_interactable(self)

func interact() -> void:
	is_open = not is_open
	_refresh()
	if Engine.has_singleton("Game") or get_node_or_null("/root/Game"):
		var g := get_node_or_null("/root/Game")
		if g and g.has_method("flash"):
			g.flash("The door creaks %s." % ("open" if is_open else "shut"), 1.4)

func _refresh() -> void:
	var spr := get_node_or_null("Spr") as Sprite2D
	if spr:
		spr.texture = open_tex if is_open else closed_tex
	var col := get_node_or_null("Body/Col") as CollisionShape2D
	if col:
		col.set_deferred("disabled", is_open)
