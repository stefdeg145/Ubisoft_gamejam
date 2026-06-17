extends Node2D
## FINAL — ACCEPTANCE · "The Last Morning" (cinematic ending).
## The one true awakening. No mechanic, no fixing — only presence. The line from
## the cold open ("Stay with me") finally lands, the loved one is let go, and the
## protagonist wakes for real into a warm, rain-stopped morning.

const FX := "res://assets/art/fx/"
const A := "res://assets/art/house/"
const CH := "res://assets/art/characters/"

var _white: ColorRect
var _sun: TextureRect
var _tableau: Node2D
var _loved: Sprite2D
var _accept_done := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_dawn()
	_build_table_scene()
	var cam := Camera2D.new(); cam.position = Vector2(640, 360); cam.make_current(); add_child(cam)
	# open from the white pass-out
	_white = ColorRect.new(); _white.color = Color(1, 1, 1, 1)
	_white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cl := CanvasLayer.new(); cl.layer = 50; add_child(cl); cl.add_child(_white)
	Game.set_black(false)
	_run()

# ---- backgrounds ----------------------------------------------------
func _build_dawn() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.96, 0.84, 0.62))     # warm sky
	grad.set_color(1, Color(0.86, 0.66, 0.50))     # warm floor light
	var gt := GradientTexture2D.new()
	gt.gradient = grad; gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(0, 1)
	gt.width = 64; gt.height = 64
	var tr := TextureRect.new(); tr.texture = gt
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cl := CanvasLayer.new(); cl.layer = -20; add_child(cl); cl.add_child(tr)
	_sun = TextureRect.new(); _sun.texture = load(FX + "glow_warm.png")
	_sun.position = Vector2(420, 60); _sun.size = Vector2(440, 440)
	_sun.modulate = Color(1, 1, 1, 0.0)
	cl.add_child(_sun)

func _build_table_scene() -> void:
	_tableau = Node2D.new(); add_child(_tableau)
	_prop(_tableau, A + "dining_table.png", 640, 470, 4.5)
	_prop(_tableau, CH + "walk_right_0.png", 470, 430, 4.0)               # you
	_loved = _prop(_tableau, CH + "walk_left_0.png", 810, 420, 4.0)        # the loved one
	_loved.modulate = Color(1.0, 0.96, 0.88)

func _prop(parent: Node, tex: String, x: float, y: float, s: float) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = load(tex); sp.position = Vector2(x, y); sp.scale = Vector2(s, s)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(sp)
	return sp

# ---- the sequence ---------------------------------------------------
func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	create_tween().tween_property(_sun, "modulate:a", 0.7, 4.0)
	await _tween_a(_white, 0.0, 3.5)                      # reveal from white

	await Game.say("You wake. But this time you don't try to fix the morning.", 3.4)
	await Game.say("You don't bargain. You don't look away.", 3.0)
	await Game.say("You just sit with them, in the light, one more time.", 3.4)
	await get_tree().create_timer(0.6).timeout
	await Game.say("\"You stayed with me,\" they say. \"All the way to the end.\"", 3.8)
	await Game.say("There is nothing left unsaid. Only this.", 3.0)
	await get_tree().create_timer(0.4).timeout
	await Game.say("\"...Stay with me.\"", 3.2)
	await Game.say("And then — gently — you let them go.", 3.2)

	# light blooms; the loved one fades into it
	create_tween().tween_property(_loved, "modulate:a", 0.0, 3.0)
	await _tween_a(_white, 1.0, 3.0)
	await get_tree().create_timer(0.8).timeout

	# the true awakening: the chair by the window, present day
	_tableau.queue_free()
	_build_window_scene()
	await _tween_a(_white, 0.0, 3.0)
	await Game.say("Morning. The real one. The rain has stopped.", 3.2)
	await Game.say("The house is warm again.", 2.6)
	await Game.say("You set the photograph down in your lap, and breathe.", 3.4)
	await get_tree().create_timer(0.8).timeout

	GameState.complete_stage("Acceptance", "The morning — you stayed until the end, and that was enough.")
	await Game.show_title("THE LAST MORNING", 3.5)
	await Game.say("thank you for staying.", 3.0)
	_accept_done = true
	_update_accept_prompt()
	InputManager.device_changed.connect(_on_device_changed)

func _build_window_scene() -> void:
	var s := Node2D.new(); add_child(s)
	# soft interior light
	var floor := ColorRect.new(); floor.color = Color(0.80, 0.70, 0.58)
	floor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cl := CanvasLayer.new(); cl.layer = -15; add_child(cl); cl.add_child(floor)
	_prop(s, A + "wall_window.png", 560, 150, 4.0)
	_prop(s, A + "armchair.png", 600, 470, 4.0)
	var you := _prop(s, CH + "walk_left_0.png", 660, 410, 4.0)
	you.modulate = Color(1, 1, 1)
	_prop(s, "res://assets/art/props/photo.png", 648, 470, 3.0)

func _tween_a(node: CanvasItem, to: float, dur: float) -> void:
	var t := create_tween()
	if node is ColorRect:
		t.tween_property(node, "color:a", to, dur)
	else:
		t.tween_property(node, "modulate:a", to, dur)
	await t.finished

func _update_accept_prompt() -> void:
	if InputManager.is_controller():
		Game.show_prompt("press", "A")
	else:
		Game.show_prompt("press E")

func _on_device_changed(_device: String) -> void:
	if _accept_done:
		_update_accept_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if not _accept_done:
		return
	if event.is_action_pressed("ui_accept"):
		_accept_done = false
		Game.hide_prompt()
		GameState.reset()
		await Game.fade_out(1.2)
		Game.change_scene("res://scenes/intro/cold_open.tscn")
