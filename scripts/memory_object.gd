extends Area2D
## An interactable memory-object in the house hub. Most are sealed behind
## "I'm not ready" until they become the active memory; the active one glows
## warmly and, when entered, drifts the player into that stage's dream.

@export var stage_name: String = "Denial"
@export_file("*.tscn") var stage_scene: String = ""
## Shown when the player tries a memory they're not ready for yet.
@export_multiline var locked_line: String = "...Not yet. I can't look at that one yet."
## A single melancholy thought for ambient (non-stage) props.
@export_multiline var idle_line: String = ""
## If true this is just flavour scenery, never a stage entrance.
@export var ambient: bool = false

signal chosen(node)

var _in_range := false

func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	_refresh_glow()
	var glow := get_node_or_null("Glow")
	if glow:
		var t := create_tween().set_loops()
		t.tween_property(glow, "modulate:a", 0.45, 1.1)
		t.tween_property(glow, "modulate:a", 1.0, 1.1)

func _process(_dt: float) -> void:
	# keep glow in sync as progress changes the active memory
	_refresh_glow()

func _refresh_glow() -> void:
	var glow := get_node_or_null("Glow")
	if glow:
		glow.visible = _is_active()

func _is_active() -> bool:
	return not ambient and GameState.is_active(stage_name)

func _on_enter(body: Node) -> void:
	if body.is_in_group("player"):
		body.nearby_object = self
		_in_range = true
		if _is_active():
			Game.flash("Something here is awake. (press E / Enter)")
		elif ambient and idle_line != "":
			pass # thought only shown on interact, to teach the verb gently

func _on_exit(body: Node) -> void:
	if body.is_in_group("player"):
		_in_range = false
		Game.hide_prompt()
		if body.nearby_object == self:
			body.nearby_object = null

func interact() -> void:
	if _is_active():
		chosen.emit(self)
	elif ambient and idle_line != "":
		Game.flash(idle_line)
	else:
		Game.flash(locked_line)
