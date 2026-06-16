extends CanvasLayer
class_name ObjectivePopup
## A small reusable "objective" card that slides in from the top-right corner.
## Used for the grief-stage prompts (go to sleep, rest on the couch, ...). Create
## one, add it to the tree, call show_objective(); call dismiss() to fade it out.

const CARD_W := 348.0
const MARGIN := 24.0

var _panel: Panel
var _dismissing := false

func _init() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_objective(title_text: String, body_text: String) -> void:
	_panel = Panel.new()
	_panel.position = Vector2(1280 - CARD_W - MARGIN, MARGIN)
	_panel.custom_minimum_size = Vector2(CARD_W, 92)
	_panel.size = Vector2(CARD_W, 92)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.10, 0.09, 0.12, 0.92)
	box.set_corner_radius_all(8)
	box.set_border_width_all(2)
	box.border_color = Color(0.85, 0.78, 0.62, 0.85)
	box.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", box)
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 14
	vb.offset_top = 12
	vb.offset_right = -14
	vb.offset_bottom = -12
	vb.add_theme_constant_override("separation", 4)
	_panel.add_child(vb)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62))
	vb.add_child(title)

	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 18)
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
