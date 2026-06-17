extends Node2D

const PARK_TIMELINE := "res://dialogic/timelines/bargaining_park.dtl"
const FX := "res://assets/art/fx/"
const PARK_AMBIENCE := "res://assets/Sound/Park ambience sound  (Royalty Free).mp3"

const PROT_NAME := "Me"
const DEAD_NAME := "Sam"

const TARGET_H := 225.0
const PROT_POS := Vector2(300, 540)
const DEAD_POS := Vector2(1000, 535)

var _prot: Sprite2D
var _dead: Sprite2D
var _portrait: TextureRect
var _portrait_frame: Panel
var _prot_tex: Texture2D
var _dead_tex: Texture2D
var _prot_portrait_tex: Texture2D
var _ambience: AudioStreamPlayer
var _finished := false

var _choice_buttons: Array[Button] = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Crucial: Forces this script to process inputs even if Dialogic pauses the game
	process_mode = Node.PROCESS_MODE_ALWAYS 
	
	_build_background()
	_build_characters()
	_build_speaker_portrait()
	_start_park_ambience()

	await Game.wake(1.8)
	await Game.say("The park. That grey afternoon. It's happening again.", 3.0)

	Dialogic.Text.speaker_updated.connect(_on_speaker_updated)
	Dialogic.timeline_ended.connect(_on_timeline_ended, CONNECT_ONE_SHOT)

	Dialogic.start(_load_timeline(PARK_TIMELINE))
	
	for _i in range(5):
		await get_tree().process_frame
	_style_dialog_box()

# --- RADAR: Detects Dialogic choices dynamically ---
func _process(_delta: float) -> void:
	var current_choices := _find_active_choice_buttons()
	if current_choices.size() > 0:
		var needs_styling := false
		for c in current_choices:
			if not c.has_meta("arcade_styled"):
				needs_styling = true
				break
		if needs_styling:
			_choice_buttons = current_choices
			_format_choice_button_styles()

func _find_active_choice_buttons() -> Array[Button]:
	var btns: Array[Button] = []
	if not is_inside_tree(): return btns
	
	var all_buttons = get_tree().root.find_children("*", "BaseButton", true, false)
	for b in all_buttons:
		if b is Button and b.is_visible_in_tree():
			var p = b.get_parent()
			var p_name = p.name.to_lower() if p else ""
			if "choice" in b.name.to_lower() or "choice" in p_name or b.has_method("_on_choice_selected"):
				btns.append(b)
	return btns

# --- VISUALS: Builds the modern, sleek Xbox icons ---
func _format_choice_button_styles() -> void:
	# Xbox Colors: Green (A), Red (B), Blue (X), Yellow (Y)
	var btn_colors := [Color(0.2, 0.8, 0.2), Color(0.8, 0.15, 0.15), Color(0.15, 0.5, 0.9), Color(0.9, 0.7, 0.1)]
	var btn_letters := ["A", "B", "X", "Y"]
	
	var visible_box := StyleBoxFlat.new()
	visible_box.bg_color = Color(0.08, 0.07, 0.13, 0.88)
	visible_box.set_border_width_all(2)
	visible_box.border_color = Color(0.68, 0.58, 0.36, 0.6)
	visible_box.set_corner_radius_all(6)
	visible_box.set_content_margin_all(12)

	for i in range(_choice_buttons.size()):
		var btn := _choice_buttons[i]
		if not btn.has_meta("arcade_styled"):
			btn.set_meta("arcade_styled", true)
			
			btn.add_theme_stylebox_override("normal", visible_box)
			btn.add_theme_stylebox_override("hover", visible_box)
			btn.add_theme_stylebox_override("focus", visible_box)
			btn.focus_mode = Control.FOCUS_NONE
			
			if i < btn_letters.size():
				_inject_modern_xbox_icon(btn, btn_letters[i], btn_colors[i])

func _inject_modern_xbox_icon(btn: Button, letter: String, color: Color) -> void:
	# 1. Create the dark, semi-transparent circular background
	var bg_panel = Panel.new()
	bg_panel.custom_minimum_size = Vector2(28, 28)
	bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var circle_style = StyleBoxFlat.new()
	circle_style.bg_color = Color(0.05, 0.05, 0.05, 0.85) # Dark/Black transparent
	circle_style.set_corner_radius_all(14) # Perfect circle
	bg_panel.add_theme_stylebox_override("panel", circle_style)
	
	# Position it cleanly on the left side of the button
	bg_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	bg_panel.position = Vector2(12, -14)
	
	# 2. Add the colored letter in the center of the circle
	var letter_label = Label.new()
	letter_label.text = letter
	letter_label.add_theme_color_override("font_color", color)
	letter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 3. Assemble the icon and indent the button's text to make room for it
	bg_panel.add_child(letter_label)
	btn.add_child(bg_panel)
	if not btn.text.begins_with("       "):
		btn.text = "       " + btn.text

# --- INPUT: Aggressively captures controller face buttons ---
func _input(event: InputEvent) -> void:
	_choice_buttons = _choice_buttons.filter(func(btn): return is_instance_valid(btn) and btn.is_visible_in_tree())
	
	if _choice_buttons.is_empty():
		return
		
	if event is InputEventJoypadButton and event.pressed:
		var idx := -1
		match event.button_index:
			JOY_BUTTON_A: idx = 0
			JOY_BUTTON_B: idx = 1
			JOY_BUTTON_X: idx = 2
			JOY_BUTTON_Y: idx = 3
			
		if idx != -1 and idx < _choice_buttons.size():
			get_viewport().set_input_as_handled()
			_force_select_choice(idx)

func _force_select_choice(idx: int) -> void:
	var chosen_btn := _choice_buttons[idx]
	_choice_buttons.clear() 
	
	# Brute-force the click through Godot's UI system to guarantee Dialogic hears it
	chosen_btn.emit_signal("button_down")
	chosen_btn.emit_signal("button_up")
	chosen_btn.emit_signal("pressed")
	
	# Failsafe: Direct Dialogic Choice Execution
	if chosen_btn.has_method("_on_choice_selected"):
		chosen_btn.call("_on_choice_selected")
	else:
		var parent = chosen_btn.get_parent()
		if parent and parent.has_method("_on_choice_selected"):
			parent.call("_on_choice_selected", chosen_btn.get_index())

# ---------------------------------------------------------------- background & system
func _start_park_ambience() -> void:
	if not ResourceLoader.exists(PARK_AMBIENCE): return
	_ambience = AudioStreamPlayer.new()
	var stream: Resource = load(PARK_AMBIENCE)
	if stream is AudioStreamMP3: stream.loop = true
	_ambience.stream = stream as AudioStream
	_ambience.volume_db = -12.0
	_ambience.bus = "Master"
	add_child(_ambience)
	_ambience.play()

func _load_timeline(path: String) -> DialogicTimeline:
	var tl := DialogicTimeline.new()
	var f := FileAccess.open(path, FileAccess.READ)
	if f:
		tl.from_text(f.get_as_text())
		f.close()
	return tl

const PARK_BG := "res://scenes/stages/Bargaining_bg.jpg"

func _build_background() -> void:
	var cl := CanvasLayer.new()
	cl.layer = -10
	add_child(cl)

	var bg := TextureRect.new()
	bg.texture = load(PARK_BG) as Texture2D
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(bg)

	if ResourceLoader.exists(FX + "vignette.png"):
		var vig := TextureRect.new()
		vig.texture = load(FX + "vignette.png") as Texture2D
		vig.stretch_mode = TextureRect.STRETCH_SCALE
		vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vig.modulate = Color(1, 1, 1, 0.22)
		vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cl.add_child(vig)

func _ground_shadow(center: Vector2, rx: float, ry: float) -> void:
	var pts := PackedVector2Array()
	for i in range(24):
		var a := TAU * i / 24.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = Color(0.0, 0.0, 0.0, 0.318)
	add_child(p)

func _build_characters() -> void:
	_ground_shadow(PROT_POS + Vector2(0, TARGET_H * 0.5), 78, 16)
	_ground_shadow(DEAD_POS + Vector2(0, TARGET_H * 0.5), 78, 16)

	_prot_tex = load("res://assets/art/characters/walk_right_0.png") as Texture2D
	_prot_portrait_tex = load("res://assets/art/characters/walk_down_0.png") as Texture2D
	_prot = _big_sprite(_prot_tex, PROT_POS, false)
	add_child(_prot)

	# --- FIXED: Locating the node instance correctly ---
	# We search for the child node by name inside the current scene
	var dead_node = get_node_or_null("DeadOne")
	
	if dead_node and dead_node.has_method("front"):
		_dead_tex = dead_node.front() as Texture2D
	else:
		# FALLBACK: If the node isn't found, load the texture directly to prevent crashing
		# Adjust the path below if your sam_front.png is located elsewhere
		_dead_tex = load("res://assets/art/characters/Dead_one.png") as Texture2D
		
	_dead = _big_sprite(_dead_tex, DEAD_POS, true)
	add_child(_dead)
	# ----------------------------------------------------

	_prot.modulate = Color(0.7, 0.7, 0.74)
	_dead.modulate = Color(0.7, 0.7, 0.74)

func _big_sprite(tex: Texture2D, pos: Vector2, flip: bool) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = true
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var th: float = max(1.0, tex.get_height()) if tex else 1.0
	var s: float = TARGET_H / th
	sp.scale = Vector2(s, s)
	if flip: sp.scale.x *= -1
	sp.position = pos
	return sp

func _build_speaker_portrait() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 80
	add_child(cl)

	_portrait_frame = Panel.new()
	_portrait_frame.position = Vector2(24, 488)
	_portrait_frame.size = Vector2(175, 195)

	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.05, 0.10, 0.93)
	box.set_corner_radius_all(10)
	box.set_border_width_all(2)
	box.border_color = Color(0.68, 0.58, 0.36, 0.88)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 4
	box.set_content_margin_all(6)
	_portrait_frame.add_theme_stylebox_override("panel", box)
	cl.add_child(_portrait_frame)

	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait.offset_left = 6
	_portrait.offset_top = 6
	_portrait.offset_right = -6
	_portrait.offset_bottom = -6
	_portrait_frame.add_child(_portrait)

	_portrait_frame.visible = false

func _find_dialogic_node(node_name: String) -> Node:
	return get_tree().root.find_child(node_name, true, false)

func _style_dialog_box() -> void:
	var dialog_panel := _find_dialogic_node("DialogTextPanel") as PanelContainer
	var name_panel   := _find_dialogic_node("NameLabelPanel")  as PanelContainer
	var name_label   := _find_dialogic_node("DialogicNode_NameLabel") as Label

	var main_style := StyleBoxFlat.new()
	main_style.bg_color = Color(0.06, 0.05, 0.10, 0.91)
	main_style.set_corner_radius_all(10)
	main_style.set_border_width_all(2)
	main_style.border_color = Color(0.68, 0.58, 0.36, 0.88)
	main_style.shadow_color = Color(0, 0, 0, 0.50)
	main_style.shadow_size = 6
	main_style.set_content_margin_all(16)

	if dialog_panel:
		dialog_panel.self_modulate = Color(1, 1, 1, 1)
		dialog_panel.add_theme_stylebox_override("panel", main_style)

	var name_style := StyleBoxFlat.new()
	name_style.bg_color = Color(0.12, 0.09, 0.20, 0.96)
	name_style.set_corner_radius_all(8)
	name_style.set_border_width_all(2)
	name_style.border_color = Color(0.68, 0.58, 0.36, 0.88)
	name_style.set_content_margin_all(8)
	name_style.content_margin_left = 14
	name_style.content_margin_right = 14

	if name_panel:
		name_panel.self_modulate = Color(1, 1, 1, 1)
		name_panel.add_theme_stylebox_override("panel", name_style)

	if name_label:
		name_label.add_theme_color_override("font_color", Color.WHITE)

func _on_speaker_updated(character: Variant) -> void:
	var speaker_name := ""
	if character != null and "display_name" in character:
		speaker_name = character.display_name
	if speaker_name == DEAD_NAME:
		_focus(_dead, _prot)
		_set_portrait(_dead_tex, true)
	else:
		_focus(_prot, _dead)
		_set_portrait(_prot_portrait_tex, false)

func _focus(speaker: Sprite2D, listener: Sprite2D) -> void:
	var base_s: float = abs(speaker.scale.x)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(speaker, "modulate", Color(1, 1, 1), 0.25)
	t.tween_property(listener, "modulate", Color(0.55, 0.55, 0.6), 0.25)
	var pop := create_tween()
	pop.tween_property(speaker, "scale:y", base_s * 1.04, 0.12)
	pop.tween_property(speaker, "scale:y", base_s, 0.12)

func _set_portrait(tex: Texture2D, flip: bool) -> void:
	_portrait.texture = tex
	_portrait.flip_h = flip
	_portrait_frame.visible = true

func _on_timeline_ended() -> void:
	if _finished: return
	_finished = true
	if _portrait_frame: _portrait_frame.visible = false
	await Game.say("Some doors only close once.", 3.0)
	GameState.complete_stage("Bargaining", "The meeting — some doors only close once.")
	if _ambience and is_instance_valid(_ambience):
		create_tween().tween_property(_ambience, "volume_db", -40.0, 1.6)
	await Game.fade_out(1.6)
	Game.change_scene("res://scenes/house/house.tscn")
