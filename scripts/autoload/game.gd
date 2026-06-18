extends CanvasLayer
## Cinematic + transition + on-screen-text manager. Autoloaded as `Game`.
## Owns a top-most overlay: a black fade, a drift-to-sleep vignette, a caption
## line for thoughts/dialogue, and the title card. Every scene transition in the
## game flows through here so the "fall asleep -> dream -> wake" grammar is shared.

const VIGNETTE := preload("res://assets/art/fx/vignette.png")
const FONT_PATH := "res://assets/fonts/merchant-copy/Merchant Copy.ttf"
const TITLE_HIT := "res://assets/Sound/Titlecard_hit_sound.mp3"
const GLITCH_SHADER := "res://shaders/glitch.gdshader"

const _CAPTION_FONT_SIZE  := 34
const _CAPTION_LINE_H     := _CAPTION_FONT_SIZE * 1.35   # px per wrapped line
const _CAPTION_MAX_W_FRAC := 0.8                          # fraction of viewport width
const _CAPTION_PAD        := 16.0                         # padding inside the bg box

var _font: Font
var _fade: ColorRect
var _vig: TextureRect
var _caption_bg: Panel   # dark panel behind every say()/flash() line
var _caption: Label
var _title: Label
var _subtitle: Label
var _title_img: TextureRect   ## image title card (e.g. AFTER_title) with glitch
var _logo_img: TextureRect    ## full-screen logo card (e.g. AFTER_logo) with glitch
var _prompt: Label
var _prompt_tween: Tween
var _prompt_row: HBoxContainer   ## holds badge + text side by side
var _prompt_badge: Label         ## green circle letter for controller
var _caption_tween: Tween
## True while a blocking say() line is on screen. Lets flash() know not to stomp
## cinematic dialogue, and gives say()'s timer-based wait something to clear.
var _saying := false
## Bumped on every say(); only the most recent say() is allowed to clear _saying.
var _say_token := 0
var _title_hit: AudioStreamPlayer

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

	# Background panel added BEFORE the caption label so it renders behind the text.
	_caption_bg = _make_caption_bg()
	_caption_bg.modulate.a = 0.0
	add_child(_caption_bg)

	_caption = _make_label(_CAPTION_FONT_SIZE, Color(0.92, 0.90, 0.84))
	_caption.modulate.a = 0.0
	add_child(_caption)

	_title = _make_label(72, Color(0.95, 0.93, 0.86))
	_title.modulate.a = 0.0
	add_child(_title)

	_subtitle = _make_label(26, Color(0.78, 0.76, 0.70))
	_subtitle.modulate.a = 0.0
	add_child(_subtitle)

	# Image title card (e.g. AFTER_title) — sits where the text title is, glitching.
	_title_img = TextureRect.new()
	_title_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title_img.modulate.a = 0.0
	_title_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_img.material = _make_glitch_material()
	add_child(_title_img)

	# Full-screen logo card (e.g. AFTER_logo) shown on its own black screen.
	_logo_img = TextureRect.new()
	_logo_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo_img.modulate.a = 0.0
	_logo_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_img.material = _make_glitch_material()
	add_child(_logo_img)

	# Prompt row: [badge] [text] — side by side
	_prompt_row = HBoxContainer.new()
	_prompt_row.modulate.a = 0.0
	_prompt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_row.add_theme_constant_override("separation", 8)
	add_child(_prompt_row)

	# Styled badge (circle, green letter) — only visible when controller is active
	_prompt_badge = Label.new()
	_prompt_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_badge.add_theme_font_size_override("font_size", 18)
	_prompt_badge.add_theme_color_override("font_color", Color(0.11, 0.85, 0.23))
	_prompt_badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_prompt_badge.add_theme_constant_override("shadow_offset_x", 1)
	_prompt_badge.add_theme_constant_override("shadow_offset_y", 1)
	_prompt_badge.custom_minimum_size = Vector2(28, 28)
	_prompt_badge.visible = false
	var _badge_box := StyleBoxFlat.new()
	_badge_box.bg_color = Color(0.08, 0.08, 0.1, 0.85)
	_badge_box.set_corner_radius_all(14)
	_badge_box.content_margin_left   = 4
	_badge_box.content_margin_right  = 4
	_badge_box.content_margin_top    = 4
	_badge_box.content_margin_bottom = 4
	_prompt_badge.add_theme_stylebox_override("normal", _badge_box)
	# Prompt text label — added FIRST so it appears on the left
	_prompt = _make_label(22, Color(0.7, 0.7, 0.74))
	_prompt.autowrap_mode = TextServer.AUTOWRAP_OFF
	_prompt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_prompt_row.add_child(_prompt)

	# Badge added AFTER so it appears on the right of the text
	_prompt_row.add_child(_prompt_badge)

	_title_hit = AudioStreamPlayer.new()
	if ResourceLoader.exists(TITLE_HIT):
		_title_hit.stream = load(TITLE_HIT)
	_title_hit.bus = "Master"
	add_child(_title_hit)


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

## Builds a ShaderMaterial running the RGB-split glitch shader (if present).
func _make_glitch_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	if ResourceLoader.exists(GLITCH_SHADER):
		m.shader = load(GLITCH_SHADER)
	return m

## Set the glitch strength on one of the image cards.
func _set_glitch(node: CanvasItem, strength: float) -> void:
	if node == null:
		return
	var m := node.material as ShaderMaterial
	if m and m.shader:
		m.set_shader_parameter("intensity", strength)

## Same dark style as the bargaining dialogue box.
func _make_caption_bg() -> Panel:
	var p := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.05, 0.10, 0.91)
	box.set_corner_radius_all(10)
	box.set_border_width_all(2)
	box.border_color = Color(0.68, 0.58, 0.36, 0.88)
	box.shadow_color = Color(0, 0, 0, 0.50)
	box.shadow_size = 6
	box.set_content_margin_all(0)
	p.add_theme_stylebox_override("panel", box)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## Resize _caption_bg to hug the current caption text tightly.
## Must be called after at least one layout frame so get_line_count() is valid.
func _fit_caption_bg() -> void:
	if _caption == null or _caption_bg == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var max_w := vs.x * _CAPTION_MAX_W_FRAC

	# Width: natural single-line width of the text, capped at the max allowed.
	var raw_w := 0.0
	if _font:
		raw_w = _font.get_string_size(
				_caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _CAPTION_FONT_SIZE).x
	var content_w := minf(raw_w, max_w)

	# Height: number of wrapped lines × line height.
	var lines := maxf(float(_caption.get_line_count()), 1.0)
	var content_h := lines * _CAPTION_LINE_H

	var bg_w := content_w + _CAPTION_PAD * 2.0
	var bg_h := content_h + _CAPTION_PAD * 2.0

	# Keep the box centred at the same vertical midpoint as the caption label.
	var mid_x := _caption.position.x + _caption.size.x * 0.5
	var mid_y := _caption.position.y + _caption.size.y * 0.5
	_caption_bg.size     = Vector2(bg_w, bg_h)
	_caption_bg.position = Vector2(mid_x - bg_w * 0.5, mid_y - bg_h * 0.5)

func _resize() -> void:
	var vs := get_viewport().get_visible_rect().size
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# caption: lower third — fixed rect so autowrap has a known width to work with.
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_caption.position = Vector2(vs.x * 0.5 - vs.x * _CAPTION_MAX_W_FRAC * 0.5, vs.y * 0.72)
	_caption.size = Vector2(vs.x * _CAPTION_MAX_W_FRAC, 120)
	# Refit the background for the current text (no-op when caption is invisible).
	_fit_caption_bg()
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_title.position = Vector2(vs.x * 0.5 - vs.x * 0.45, vs.y * 0.42)
	_title.size = Vector2(vs.x * 0.9, 120)
	# Subtitle: centred low on the screen, under both images.
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_subtitle.position = Vector2(vs.x * 0.5 - vs.x * 0.45, vs.y * 0.74)
	_subtitle.size = Vector2(vs.x * 0.9, 60)
	# Logo (left) and title (right) share the same vertical band so they line up.
	# Boxes don't overlap: logo 0.06-0.22, title 0.54-0.70.
	var _img_top := vs.y * 0.1
	var _img_h := vs.y * 0.14
	if _logo_img:
		_logo_img.position = Vector2(vs.x * 0.02, _img_top)
		_logo_img.size = Vector2(vs.x * 0.16, _img_h)
	if _title_img:
		_title_img.position = Vector2(vs.x * 0.45, _img_top)
		_title_img.size = Vector2(vs.x * 0.16, _img_h)
	# Position the whole row centred at the bottom
	if _prompt_row:
		_prompt_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_prompt_row.position = Vector2(vs.x * 0.5 - 100, vs.y * 0.85)
		_prompt_row.size = Vector2(200, 40)
		_prompt_row.alignment = BoxContainer.ALIGNMENT_CENTER

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
	hold = hold * 0.5   # global display-time scale — halves every caption in the game
	if _caption_tween and _caption_tween.is_valid():
		_caption_tween.kill()
	_caption.text = text
	_caption.modulate.a = 0.0
	_caption_bg.modulate.a = 0.0
	_say_token += 1
	var my_token := _say_token
	_saying = true
	# Wait one frame so the label's line-wrap has been computed, then fit the box.
	await get_tree().process_frame
	_fit_caption_bg()
	_caption_tween = create_tween()
	# fade in — caption and background in parallel
	_caption_tween.tween_property(_caption, "modulate:a", 1.0, fade)
	_caption_tween.parallel().tween_property(_caption_bg, "modulate:a", 1.0, fade)
	_caption_tween.tween_interval(hold)
	# fade out — parallel
	_caption_tween.tween_property(_caption, "modulate:a", 0.0, fade)
	_caption_tween.parallel().tween_property(_caption_bg, "modulate:a", 0.0, fade)
	# IMPORTANT: wait on a real timer, NOT on _caption_tween.finished. If another
	# say()/flash() kills this tween mid-line, Tween.kill() does NOT emit finished,
	# so awaiting the signal would hang this coroutine forever — and with it, any
	# can_move/_busy lock the caller is holding (this was the game-wide freeze).
	await get_tree().create_timer(fade + hold + fade).timeout
	# Only the most recent say() clears the flag, so overlapping lines stay correct.
	if my_token == _say_token:
		_saying = false

## Non-blocking caption that stays until cleared (for locked-line flashes).
func flash(text: String, hold := 2.2) -> void:
	hold = hold * 0.5   # global display-time scale — matches say()
	# Never let an incidental proximity prompt overwrite a blocking spoken line.
	if _saying:
		return
	# Cancel any in-flight caption fade so this line shows for its full duration.
	if _caption_tween and _caption_tween.is_valid():
		_caption_tween.kill()
	_caption.text = text
	_caption.modulate.a = 0.0
	_caption_bg.modulate.a = 0.0
	# Fit the background after the layout frame, then kick off the tween.
	await get_tree().process_frame
	_fit_caption_bg()
	_caption_tween = create_tween()
	_caption_tween.tween_property(_caption, "modulate:a", 1.0, 0.35)
	_caption_tween.parallel().tween_property(_caption_bg, "modulate:a", 1.0, 0.35)
	_caption_tween.tween_interval(hold)
	_caption_tween.tween_property(_caption, "modulate:a", 0.0, 0.6)
	_caption_tween.parallel().tween_property(_caption_bg, "modulate:a", 0.0, 0.6)

func show_prompt(text: String, badge: String = "") -> void:
	_prompt.text = text
	# Show/hide the badge circle
	if _prompt_badge:
		if badge != "":
			_prompt_badge.text = badge
			_prompt_badge.visible = true
		else:
			_prompt_badge.visible = false
	if _prompt_tween and _prompt_tween.is_valid():
		_prompt_tween.kill()
	_prompt_row.modulate.a = 1.0
	_prompt_tween = create_tween().set_loops()
	_prompt_tween.tween_property(_prompt_row, "modulate:a", 0.35, 0.9)
	_prompt_tween.tween_property(_prompt_row, "modulate:a", 1.0, 0.9)

func hide_prompt() -> void:
	if _prompt_tween and _prompt_tween.is_valid():
		_prompt_tween.kill()
	_prompt_row.modulate.a = 0.0
	if _prompt_badge:
		_prompt_badge.visible = false

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
	# Cinematic hit lands as the title slams in — sound + a sharp controller jolt.
	if _title_hit and _title_hit.stream:
		_title_hit.play()
	Haptics.rumble("slam")
	# Title rises first; the subtitle follows a beat later, then both hold and fade.
	var t := create_tween()
	t.tween_property(_title, "modulate:a", 1.0, 1.4)
	t.parallel().tween_property(_subtitle, "modulate:a", 1.0, 1.4).set_delay(0.6)
	t.tween_interval(hold)
	t.tween_property(_subtitle, "modulate:a", 0.0, 1.3)
	t.parallel().tween_property(_title, "modulate:a", 0.0, 1.5)
	await t.finished

## The "After" title screen: AFTER_title on the left and AFTER_logo on the right,
## at the same level, with the subtitle ("Ubisoft Gamejam 2026") centred near the
## bottom. Both carry the digital-glitch twitch, but the title starts twitching
## first and the logo's twitch kicks in ~0.5s later.
func show_after_card(title_tex_path: String, logo_tex_path: String, subtitle: String, hold := 3.2, glitch := 0.9) -> void:
	if ResourceLoader.exists(title_tex_path):
		_title_img.texture = load(title_tex_path)
	if ResourceLoader.exists(logo_tex_path):
		_logo_img.texture = load(logo_tex_path)
	_subtitle.text = subtitle
	_set_glitch(_title_img, glitch)      # title twitches from the start
	_set_glitch(_logo_img, 0.0)          # logo holds still for the first half second
	# Cinematic hit lands as the card slams in.
	if _title_hit and _title_hit.stream:
		_title_hit.play()
	# The logo's twitch joins in 0.5s after the title's.
	get_tree().create_timer(0.5).timeout.connect(func() -> void: _set_glitch(_logo_img, glitch))
	var t := create_tween()
	t.tween_property(_title_img, "modulate:a", 1.0, 1.4)
	t.parallel().tween_property(_logo_img, "modulate:a", 1.0, 1.4)
	t.parallel().tween_property(_subtitle, "modulate:a", 1.0, 1.4).set_delay(0.6)
	t.tween_interval(hold)
	t.tween_property(_subtitle, "modulate:a", 0.0, 1.3)
	t.parallel().tween_property(_title_img, "modulate:a", 0.0, 1.5)
	t.parallel().tween_property(_logo_img, "modulate:a", 0.0, 1.5)
	await t.finished
