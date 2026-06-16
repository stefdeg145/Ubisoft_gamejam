extends CanvasLayer
## Cinematic + transition + on-screen-text manager. Autoloaded as `Game`.
## Owns a top-most overlay: a black fade, a drift-to-sleep vignette, a caption
## line for thoughts/dialogue, and the title card. Every scene transition in the
## game flows through here so the "fall asleep -> dream -> wake" grammar is shared.

const VIGNETTE := preload("res://assets/art/fx/vignette.png")
const FONT_PATH := "res://assets/fonts/Lora.ttf"

var _font: Font
var _fade: ColorRect
var _vig: TextureRect
var _caption: Label
var _title: Label
var _subtitle: Label
var _prompt: Label
var _prompt_tween: Tween
var _caption_tween: Tween

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)        # start black; first scene fades in
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	_vig = TextureRect.new()
	_vig.texture = VIGNETTE
	_vig.stretch_mode = TextureRect.STRETCH_SCALE
	_vig.modulate = Color(1, 1, 1, 0)
	_vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vig)

	_caption = _make_label(34, Color(0.92, 0.90, 0.84))
	_caption.modulate.a = 0.0
	add_child(_caption)

	_title = _make_label(72, Color(0.95, 0.93, 0.86))
	_title.modulate.a = 0.0
	add_child(_title)

	_subtitle = _make_label(26, Color(0.78, 0.76, 0.70))
	_subtitle.modulate.a = 0.0
	add_child(_subtitle)

	_prompt = _make_label(22, Color(0.7, 0.7, 0.74))
	_prompt.modulate.a = 0.0
	add_child(_prompt)

	get_viewport().size_changed.connect(_resize)
	_resize()

func _make_label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _font:
		l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _resize() -> void:
	var vs := get_viewport().get_visible_rect().size
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# caption: lower third
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_caption.position = Vector2(vs.x * 0.5 - vs.x * 0.4, vs.y * 0.72)
	_caption.size = Vector2(vs.x * 0.8, 120)
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_title.position = Vector2(vs.x * 0.5 - vs.x * 0.45, vs.y * 0.42)
	_title.size = Vector2(vs.x * 0.9, 120)
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_subtitle.position = Vector2(vs.x * 0.5 - vs.x * 0.45, vs.y * 0.56)
	_subtitle.size = Vector2(vs.x * 0.9, 60)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prompt.position = Vector2(vs.x * 0.5 - vs.x * 0.4, vs.y * 0.85)
	_prompt.size = Vector2(vs.x * 0.8, 60)

# ---------------------------------------------------------------- fades
func fade_in(dur := 1.0) -> void:            # black -> clear
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, dur)
	await t.finished

func fade_out(dur := 1.0) -> void:           # clear -> black
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, dur)
	await t.finished

func set_black(on: bool) -> void:
	_fade.color.a = 1.0 if on else 0.0

# ------------------------------------------------ drift to sleep / wake
func drift_to_sleep(dur := 2.2) -> void:
	_vig.modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(false)
	t.tween_property(_vig, "modulate:a", 1.0, dur * 0.6)
	t.tween_property(_fade, "color:a", 1.0, dur * 0.5)
	await t.finished

func wake(dur := 1.8) -> void:
	_fade.color.a = 1.0
	_vig.modulate.a = 1.0
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, dur * 0.5)
	t.tween_property(_vig, "modulate:a", 0.0, dur * 0.6)
	await t.finished

## Drift to black, swap scenes; the destination scene calls wake() itself.
func transition_to(path: String, dur := 2.2) -> void:
	await drift_to_sleep(dur)
	get_tree().change_scene_to_file(path)

func change_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)

# ---------------------------------------------------------------- text
func say(text: String, hold := 2.6, fade := 0.6) -> void:
	if _caption_tween and _caption_tween.is_valid():
		_caption_tween.kill()
	_caption.text = text
	_caption_tween = create_tween()
	_caption_tween.tween_property(_caption, "modulate:a", 1.0, fade)
	_caption_tween.tween_interval(hold)
	_caption_tween.tween_property(_caption, "modulate:a", 0.0, fade)
	await _caption_tween.finished

## Non-blocking caption that stays until cleared (for locked-line flashes).
func flash(text: String, hold := 2.2) -> void:
	# cancel any in-flight caption fade so this line shows for its full duration
	if _caption_tween and _caption_tween.is_valid():
		_caption_tween.kill()
	_caption.text = text
	_caption.modulate.a = 0.0
	_caption_tween = create_tween()
	_caption_tween.tween_property(_caption, "modulate:a", 1.0, 0.35)
	_caption_tween.tween_interval(hold)
	_caption_tween.tween_property(_caption, "modulate:a", 0.0, 0.6)

func show_prompt(text: String) -> void:
	_prompt.text = text
	if _prompt_tween and _prompt_tween.is_valid():
		_prompt_tween.kill()
	_prompt.modulate.a = 1.0
	_prompt_tween = create_tween().set_loops()
	_prompt_tween.tween_property(_prompt, "modulate:a", 0.35, 0.9)
	_prompt_tween.tween_property(_prompt, "modulate:a", 1.0, 0.9)

func hide_prompt() -> void:
	if _prompt_tween and _prompt_tween.is_valid():
		_prompt_tween.kill()
	_prompt.modulate.a = 0.0

func show_title(text: String, hold := 3.0) -> void:
	_title.text = text
	var t := create_tween()
	t.tween_property(_title, "modulate:a", 1.0, 1.2)
	t.tween_interval(hold)
	t.tween_property(_title, "modulate:a", 0.0, 1.5)
	await t.finished

## Title card with a subtitle under it (e.g. "After" / "Ubisoft Gamejam 2026").
## Drawn over whatever is currently on screen (typically the closed-eyes black).
func show_title_card(title: String, subtitle: String, hold := 3.0) -> void:
	_title.text = title
	_subtitle.text = subtitle
	# Title rises first; the subtitle follows a beat later, then both hold and fade.
	var t := create_tween()
	t.tween_property(_title, "modulate:a", 1.0, 1.4)
	t.parallel().tween_property(_subtitle, "modulate:a", 1.0, 1.4).set_delay(0.6)
	t.tween_interval(hold)
	t.tween_property(_subtitle, "modulate:a", 0.0, 1.3)
	t.parallel().tween_property(_title, "modulate:a", 0.0, 1.5)
	await t.finished
