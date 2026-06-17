extends Area2D
class_name SympathyLetters
## A small stack of sympathy cards left on the table. The first thing the griever
## faces on waking: pressing E zooms into a close-up the player flips through one
## card at a time, each with a quiet inner reaction, before the rest of the
## morning (and Denial) can begin. Self-contained — the house just drops one in,
## connects `finished`, and waits.

signal finished

var source_sprite: Node2D = null     # so the floating "E" can anchor to the prop
var _player: Node = null
var _used := false
var _reading := false
var _input_ready := false
var _idx := 0
var _glow: Sprite2D
var _rustle: AudioStreamPlayer

const CARD_TEX := "res://assets/art/props/sympathy_cards.png"
const RUSTLE_SFX := "res://assets/Sound/paper_rustle.mp3"

# from = who wrote it (blank for an unsigned card); body = the message;
# thought = the protagonist's inner reaction shown beneath the card.
const LETTERS := [
	{
		"from": "Maggie",
		"body": "There are no words. Eli loved you more than anything in this world — you know that, don't you? I'm here. Any hour. Just call.",
		"thought": "Eli's sister. She even writes like them.",
	},
	{
		"from": "The Hendersons, next door",
		"body": "We left some supper on your step. Don't fret about the dish. Eli always waved on the morning walk. The street's too quiet now.",
		"thought": "The casseroles in the fridge. I haven't been able to open it.",
	},
	{
		"from": "Tom, from the shop",
		"body": "Eli never shut up about you, mate. Proud of you — always said so. Whatever you need, I'm one phone call away.",
		"thought": "They did talk too much. ...I'd give anything to hear it now.",
	},
	{
		"from": "",
		"body": "Thinking of you both.",
		"thought": "Both. People keep writing 'both'.",
	},
]

# reader overlay nodes
var _layer: CanvasLayer
var _dim: ColorRect
var _card: Panel
var _from_label: Label
var _body_label: Label
var _thought_label: Label
var _prompt_label: Label

func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	_build_visual()
	InputManager.device_changed.connect(_refresh_prompt)
	if ResourceLoader.exists(RUSTLE_SFX):
		_rustle = AudioStreamPlayer.new()
		_rustle.stream = load(RUSTLE_SFX)
		_rustle.bus = "Master"
		add_child(_rustle)

# ---------------------------------------------------------------- the prop
func _build_visual() -> void:
	# Draw the cards in front of the table. z_as_relative = false makes this an
	# absolute layer so the stack always sits ON the table top, never behind it,
	# regardless of the y-sorted furniture around it.
	z_as_relative = false
	z_index = 20         # well above all furniture (z 0)
	# warm pulse so the cards read as "the thing to face" in the grey room
	if ResourceLoader.exists("res://assets/art/fx/glow_warm.png"):
		_glow = Sprite2D.new()
		_glow.texture = load("res://assets/art/fx/glow_warm.png")
		_glow.scale = Vector2(2.3, 2.3)               # large enough to read as a clear beacon
		_glow.position = Vector2(0, -4)
		_glow.modulate = Color(1.0, 0.94, 0.78, 0.85) # warm, matches the objective glow
		_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_glow)
		var g := create_tween().set_loops()
		g.tween_property(_glow, "modulate:a", 0.55, 1.1).set_trans(Tween.TRANS_SINE)
		g.tween_property(_glow, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)

	# the stack of cards lying on the table
	var sp := Sprite2D.new()
	if ResourceLoader.exists(CARD_TEX):
		sp.texture = load(CARD_TEX)
	sp.scale = Vector2(2.0, 2.0)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)
	source_sprite = sp

	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 120.0    # generous reach so the prompt triggers from the table front, not only by walking around
	cs.shape = sh
	add_child(cs)

func _play_rustle() -> void:
	if _rustle:
		_rustle.play()

func _on_enter(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("add_interactable"):
		_player = body
		body.add_interactable(self)

func _on_exit(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("remove_interactable"):
		body.remove_interactable(self)

func interact() -> void:
	if _used or _reading:
		return
	_open()

# ---------------------------------------------------------------- reader
func _open() -> void:
	_reading = true
	_idx = 0
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player:
		_player.can_move = false
		_player.velocity = Vector2.ZERO
	Game.hide_prompt()
	_build_reader()
	_play_rustle()                       # picking the cards up off the table
	_show_letter(0)
	# swallow the very press that opened this, so it doesn't instantly flip a page
	await get_tree().create_timer(0.25).timeout
	_input_ready = true

func _build_reader() -> void:
	var vp := get_viewport().get_visible_rect().size
	_layer = CanvasLayer.new()
	_layer.layer = 95
	add_child(_layer)

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.0)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(_dim)

	var cw := 560.0
	var ch := 360.0
	_card = Panel.new()
	_card.size = Vector2(cw, ch)
	_card.position = (vp - Vector2(cw, ch)) * 0.5
	_card.pivot_offset = Vector2(cw, ch) * 0.5
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.95, 0.93, 0.87, 1.0)
	box.set_corner_radius_all(6)
	box.set_border_width_all(2)
	box.border_color = Color(0.60, 0.55, 0.45, 0.85)
	box.set_content_margin_all(28)
	_card.add_theme_stylebox_override("panel", box)
	_layer.add_child(_card)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 30
	vb.offset_top = 26
	vb.offset_right = -30
	vb.offset_bottom = -22
	vb.add_theme_constant_override("separation", 18)
	_card.add_child(vb)

	_from_label = Label.new()
	_from_label.add_theme_font_size_override("font_size", 20)
	_from_label.add_theme_color_override("font_color", Color(0.35, 0.30, 0.24))
	vb.add_child(_from_label)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 24)
	_body_label.add_theme_color_override("font_color", Color(0.18, 0.16, 0.14))
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_body_label)

	# the inner reaction, off-white, sitting just below the card on the dim
	_thought_label = Label.new()
	_thought_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thought_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_thought_label.add_theme_font_size_override("font_size", 22)
	_thought_label.add_theme_color_override("font_color", Color(0.87, 0.85, 0.80))
	_thought_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_thought_label.add_theme_constant_override("shadow_offset_y", 2)
	_thought_label.position = Vector2(vp.x * 0.12, _card.position.y + ch + 22)
	_thought_label.size = Vector2(vp.x * 0.76, 70)
	_layer.add_child(_thought_label)

	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 18)
	_prompt_label.add_theme_color_override("font_color", Color(0.70, 0.70, 0.72))
	_prompt_label.position = Vector2(vp.x * 0.5 - 160, vp.y - 54)
	_prompt_label.size = Vector2(320, 30)
	_layer.add_child(_prompt_label)

	# zoom the card in
	_card.scale = Vector2(0.7, 0.7)
	_card.modulate.a = 0.0
	_thought_label.modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_dim, "color:a", 0.78, 0.4)
	t.tween_property(_card, "modulate:a", 1.0, 0.4)
	t.tween_property(_card, "scale", Vector2(1, 1), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _show_letter(i: int) -> void:
	var l = LETTERS[i]
	_from_label.text = ("— " + String(l["from"])) if String(l["from"]) != "" else " "
	_body_label.text = "\"" + String(l["body"]) + "\""
	_thought_label.text = String(l["thought"])
	var last := i == LETTERS.size() - 1
	var btn := InputManager.hint("accept")
	_prompt_label.text = (btn + " — set it down") if last else (btn + " — next")
	# Style the prompt label like the controller badge when on controller
	_style_prompt_label()
	_thought_label.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_thought_label, "modulate:a", 1.0, 0.5)

func _refresh_prompt(_device: String = "") -> void:
	if _reading and _prompt_label:
		var last := _idx == LETTERS.size() - 1
		var btn := InputManager.hint("accept")
		_prompt_label.text = (btn + " — set it down") if last else (btn + " — next")
		_style_prompt_label()

func _style_prompt_label() -> void:
	if _prompt_label == null:
		return
	if InputManager.is_controller():
		_prompt_label.add_theme_color_override("font_color", Color(0.11, 0.85, 0.23))
	else:
		_prompt_label.add_theme_color_override("font_color", Color(0.70, 0.70, 0.72))

func _unhandled_input(event: InputEvent) -> void:
	if not _reading or not _input_ready:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_advance()

func _advance() -> void:
	if _idx >= LETTERS.size() - 1:
		_close()
		return
	_input_ready = false
	_idx += 1
	_play_rustle()                       # flipping to the next card
	# quick page-flip
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_card, "modulate:a", 0.0, 0.12)
	t.tween_property(_thought_label, "modulate:a", 0.0, 0.12)
	await t.finished
	_show_letter(_idx)
	var t2 := create_tween()
	t2.tween_property(_card, "modulate:a", 1.0, 0.16)
	await t2.finished
	_input_ready = true

func _close() -> void:
	_reading = false
	_input_ready = false
	_used = true
	# stop being interactable so the "E" hint doesn't linger over a read stack
	monitoring = false
	monitorable = false
	if _player and _player.has_method("remove_interactable"):
		_player.remove_interactable(self)
	if _glow and is_instance_valid(_glow):
		create_tween().tween_property(_glow, "modulate:a", 0.0, 0.6)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_dim, "color:a", 0.0, 0.4)
	t.tween_property(_card, "modulate:a", 0.0, 0.35)
	t.tween_property(_card, "scale", Vector2(0.7, 0.7), 0.35)
	if _thought_label:
		t.tween_property(_thought_label, "modulate:a", 0.0, 0.3)
	await t.finished
	if _layer and is_instance_valid(_layer):
		_layer.queue_free()
	if _player:
		_player.can_move = true
	emit_signal("finished")
