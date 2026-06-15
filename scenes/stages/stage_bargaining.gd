extends Node2D
## STAGE 2 — BARGAINING · "The Last Meeting" (front-on dialogue memory).
## A different camera: the protagonist sits across from the relative they lost,
## the meeting that went wrong. "What if I said this instead?" Every choice is a
## new attempt to fix it — and every one still ends the same way. The exit is
## realising it can't be fixed: "I was the one at fault."

const FX := "res://assets/art/fx/"

var _attempts := 0
var _panel: Panel
var _line: Label
var _choices: VBoxContainer
var _done := false

# each option -> the relative's cold reply
const OPTIONS := [
	["\"I'm sorry. I didn't mean what I said.\"", "\"You never do. It's a little late, isn't it.\""],
	["\"Can we just start over? Please.\"", "\"We always start over. Nothing ever changes.\""],
	["\"I love you. Don't go like this.\"", "\"...I have to catch my train.\""],
	["\"Stay. Just five more minutes.\"", "\"I really can't. Take care of yourself.\""],
]

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_room()
	_build_ui()
	await Game.wake(1.8)
	await Game.say("You put the photograph back in your pocket. Then you sit down.", 3.2)
	await Game.say("It's the last time you saw them. It didn't go well.", 3.0)
	await Game.say("What if you said it differently? What if you could fix it?", 3.2)
	_show_choices()

func _build_room() -> void:
	# warm, dim memory room (a soft gradient + two silhouettes facing each other)
	var bg := ColorRect.new()
	bg.color = Color(0.20, 0.15, 0.13)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cl := CanvasLayer.new(); cl.layer = -10; add_child(cl); cl.add_child(bg)
	var glow := TextureRect.new()
	glow.texture = load(FX + "glow_warm.png")
	glow.position = Vector2(440, 120); glow.size = Vector2(400, 400)
	glow.modulate = Color(1, 1, 1, 0.5)
	cl.add_child(glow)
	# table
	var table := add_prop("res://assets/art/house/dining_table.png", 640, 470, 4.5)
	# protagonist (you) on the left, the relative on the right
	_figure("res://assets/art/characters/walk_right_0.png", 470, 430, false, Color(1, 1, 1))
	_figure("res://assets/art/characters/walk_left_0.png", 810, 420, false, Color(0.75, 0.78, 0.86))

func _figure(tex: String, x: float, y: float, flip: bool, mod: Color) -> void:
	var sp := add_prop(tex, x, y, 4.0)
	sp.modulate = mod
	if flip:
		sp.scale.x *= -1

func add_prop(tex_path: String, x: float, y: float, s := 4.0) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = load(tex_path)
	sp.position = Vector2(x, y)
	sp.scale = Vector2(s, s)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)
	return sp

func _build_ui() -> void:
	var cl := CanvasLayer.new(); cl.layer = 10; add_child(cl)
	_panel = Panel.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.position.y -= 250
	_panel.custom_minimum_size = Vector2(0, 250)
	cl.add_child(_panel)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 8)
	vb.offset_left = 40; vb.offset_right = -40; vb.offset_top = 16; vb.offset_bottom = -16
	_panel.add_child(vb)
	_line = Label.new()
	_line.add_theme_font_size_override("font_size", 26)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(0, 70)
	vb.add_child(_line)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	vb.add_child(_choices)
	_panel.visible = false

func _show_choices() -> void:
	for c in _choices.get_children():
		c.queue_free()
	_panel.visible = true
	_line.text = "They are already standing to leave. You could say..."
	for i in OPTIONS.size():
		var b := Button.new()
		b.text = OPTIONS[i][0]
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(_on_choice.bind(i))
		_choices.add_child(b)

func _on_choice(i: int) -> void:
	if _done:
		return
	_attempts += 1
	for c in _choices.get_children():
		c.queue_free()
	_line.text = OPTIONS[i][1]
	await get_tree().create_timer(2.6).timeout
	if _attempts >= 3:
		await _conclude()
	else:
		_line.text = "It ends the same way. You try again. Maybe this time..."
		await get_tree().create_timer(2.0).timeout
		_show_choices()

func _conclude() -> void:
	_done = true
	_panel.visible = false
	await Game.say("No words change it. The train leaves. The door closes.", 3.2)
	await Game.say("Maybe it was never theirs to fix.", 3.0)
	await Game.say("...Maybe I was the one at fault.", 3.2)
	GameState.complete_stage("Bargaining", "The meeting — some doors only close once.")
	await Game.fade_out(1.6)
	Game.change_scene("res://scenes/house/house.tscn")
