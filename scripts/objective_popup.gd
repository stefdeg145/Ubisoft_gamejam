extends CanvasLayer
class_name ObjectivePopup
## A small reusable "objective" card that slides in from the top-right corner.
## Used for the grief-stage prompts (go to sleep, rest on the couch, ...). Create
## one, add it to the tree, call show_objective(); call dismiss() to fade it out.

const CARD_W := 430.0
const MARGIN := 24.0

## Objective/TODO UI uses the wider Merchant Copy variant for at-a-glance legibility.
const WIDE_FONT := "res://assets/fonts/merchant-copy/Merchant Copy Wide.ttf"

var _panel: Panel
var _dismissing := false
var _wide: Font

func _init() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_objective(title_text: String, body_text: String) -> void:
	if ResourceLoader.exists(WIDE_FONT):
		_wide = load(WIDE_FONT)
	_panel = Panel.new()
	_panel.position = Vector2(1280 - CARD_W - MARGIN, MARGIN)
	# Height is unconstrained — we resize to fit content after the first layout frame.
	_panel.custom_minimum_size = Vector2(CARD_W, 0)
	_panel.size = Vector2(CARD_W, 120)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.10, 0.09, 0.12, 0.92)
	box.set_corner_radius_all(8)
	box.set_border_width_all(2)
	box.border_color = Color(0.85, 0.78, 0.62, 0.85)
	box.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", box)
	add_child(_panel)

	# VBoxContainer is NOT anchor-stretched — it sizes freely to its children so we
	# can read its minimum height and apply it to the panel.
	var vb := VBoxContainer.new()
	vb.position = Vector2(14, 12)
	vb.size = Vector2(CARD_W - 28, 0)
	vb.custom_minimum_size = Vector2(CARD_W - 28, 0)
	vb.add_theme_constant_override("separation", 4)
	_panel.add_child(vb)

	var title := Label.new()
	title.text = title_text
	if _wide:
		title.add_theme_font_override("font", _wide)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62))
	vb.add_child(title)

	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(CARD_W - 28, 0)
	if _wide:
		body.add_theme_font_override("font", _wide)
	body.add_theme_font_size_override("font_size", 26)
	body.add_theme_color_override("font_color", Color(0.93, 0.91, 0.86))
	vb.add_child(body)

	# slide + fade in
	_panel.modulate.a = 0.0
	var rest := _panel.position
	_panel.position = rest + Vector2(30, 0)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_panel, "modulate:a", 1.0, 0.5)
	t.tween_property(_panel, "position", rest, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Wait two frames for the layout system to compute label wrap heights, then
	# resize the panel so it fits the content exactly.
	await get_tree().process_frame
	await get_tree().process_frame
	var needed_h: float = vb.get_combined_minimum_size().y + 24.0
	_panel.custom_minimum_size = Vector2(CARD_W, needed_h)
	_panel.size = Vector2(CARD_W, needed_h)

func dismiss() -> void:
	if _dismissing:
		return
	_dismissing = true
	if _panel == null:
		queue_free()
		return
	var t := create_tween()
	t.tween_property(_panel, "modulate:a", 0.0, 0.4)
	await t.finished
	queue_free()
