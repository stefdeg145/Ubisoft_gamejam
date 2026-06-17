class_name DialogicChoiceIconButton
extends DialogicNode_ChoiceButton
## Dialogic choice button with an Xbox face-button (or keyboard-number) badge
## displayed to the left of the choice text.
##
## Set choices_custom_button = "res://scenes/dialogic_choice_icon_button.tscn"
## in the VN_ChoiceLayer node to activate.

## Face-button labels and Xbox colours (A/B/X/Y).
const CTRL_LABELS := ["A",    "B",    "X",    "Y"   ]
const CTRL_COLORS := [
	Color(0.0,  0.64, 0.24),  # A — Xbox green
	Color(0.82, 0.0,  0.0 ),  # B — Xbox red
	Color(0.0,  0.47, 0.84),  # X — Xbox blue
	Color(1.0,  0.72, 0.0 ),  # Y — Xbox yellow
]
const KB_LABELS := ["1", "2", "3", "4"]
const JOY_BTNS  := [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y]

## Badge visual size — matches the player interaction hint aesthetic.
const ICON_SIZE := 16           # font size inside the badge
const ICON_DIAM := ICON_SIZE + 10  # outer diameter of the circle (26 px)

var _badge: Label               # the coloured circle showing A/B/X/Y or 1/2/3/4
var _choice_text: Label         # the choice text label (used as text_node)
var _choice_idx: int = 0        # 0-based index for current question slot

func _ready() -> void:
	super._ready()
	text = ""                   # suppress built-in Button label; use text_node
	alignment = HORIZONTAL_ALIGNMENT_LEFT

	# Wire the badge and text label from the PackedScene's HBox children.
	var hbox := get_node_or_null("HBox")
	if hbox:
		_badge       = hbox.get_node_or_null("Badge")
		_choice_text = hbox.get_node_or_null("ChoiceText")
		text_node    = _choice_text

	_refresh_badge()
	InputManager.device_changed.connect(func(_d: String) -> void: _refresh_badge())


## Called by Dialogic subsystem_choices before showing each question.
## choice_info keys: button_index (1-based), text, visible, disabled.
func _load_info(choice_info: Dictionary) -> void:
	_choice_idx = clamp((choice_info.get("button_index", 1) as int) - 1, 0, 3)
	_setup_shortcut()
	_refresh_badge()
	super._load_info(choice_info)


## Assign keyboard (1/2/3/4) shortcut. Joypad input is handled by the scene's
## _unhandled_input to avoid conflict with Dialogic's own A-button binding.
func _setup_shortcut() -> void:
	var sc := Shortcut.new()
	var key_ev := InputEventKey.new()
	key_ev.keycode = [KEY_1, KEY_2, KEY_3, KEY_4][_choice_idx]
	sc.events = [key_ev]
	shortcut = sc
	shortcut_feedback = false


## Rebuild the badge style to match the current input device.
## Identical circle/rect aesthetic to the player interaction hint (player.gd).
func _refresh_badge() -> void:
	if not is_instance_valid(_badge):
		return

	var ctrl := InputManager.is_controller()
	_badge.text = (CTRL_LABELS[_choice_idx] as String) if ctrl else (KB_LABELS[_choice_idx] as String)
	var font_col: Color = CTRL_COLORS[_choice_idx] if ctrl else Color(0.92, 0.90, 0.84)

	_badge.add_theme_font_size_override("font_size", ICON_SIZE)
	_badge.add_theme_color_override("font_color", font_col)
	_badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_badge.add_theme_constant_override("shadow_offset_x", 1)
	_badge.add_theme_constant_override("shadow_offset_y", 1)
	_badge.custom_minimum_size = Vector2(ICON_DIAM, ICON_DIAM)

	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.08, 0.10, 0.88)
	box.set_corner_radius_all(ICON_DIAM / 2)  # full circle
	box.content_margin_left   = 3
	box.content_margin_right  = 3
	box.content_margin_top    = 3
	box.content_margin_bottom = 3
	_badge.add_theme_stylebox_override("normal", box)
