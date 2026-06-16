extends CanvasLayer
## ─────────────────────────────────────────────
##  DEBUG CONSOLE  (admin / developer only)
##  Toggle with:  F1  (or ` backtick)
##  Type a command and press Enter.
##  Only active in debug builds — stripped in export.
## ─────────────────────────────────────────────

const SCENES := {
	"house":       "res://scenes/house/house.tscn",
	"cold_open":   "res://scenes/intro/cold_open.tscn",
	"denial":      "res://scenes/stages/stage_denial.tscn",
	"bargaining":  "res://scenes/stages/stage_bargaining.tscn",
	"depression":  "res://scenes/stages/stage_depression.tscn",
	"acceptance":  "res://scenes/stages/stage_acceptance.tscn",
}

var _visible   := false
var _panel     : Window
var _log       : RichTextLabel
var _line_edit : LineEdit


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return

	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide_console()


func _build_ui() -> void:
	# Window node gives us free dragging + resizing built in
	_panel = Window.new()
	_panel.title         = "▶ DEBUG CONSOLE  (F1 to close)"
	_panel.size          = Vector2i(700, 380)
	_panel.min_size      = Vector2i(400, 260)
	_panel.position      = Vector2i(100, 60)
	_panel.unresizable   = false
	_panel.exclusive     = false
	_panel.always_on_top = true
	_panel.close_requested.connect(hide_console)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	# Hint label
	var hint := Label.new()
	hint.text = "  type a command below — 'help' for the full list"
	hint.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	hint.add_theme_font_size_override("font_size", 12)
	vbox.add_child(hint)

	vbox.add_child(HSeparator.new())

	# Log output
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	vbox.add_child(_log)

	vbox.add_child(HSeparator.new())

	# Input row
	var hbox := HBoxContainer.new()
	vbox.add_child(hbox)

	var arrow := Label.new()
	arrow.text = " > "
	arrow.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	hbox.add_child(arrow)

	_line_edit = LineEdit.new()
	_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line_edit.placeholder_text = "type a command... (help for list)"
	_line_edit.text_submitted.connect(_on_command)
	hbox.add_child(_line_edit)

	_log_line("[color=gray]Console ready. Type [color=white]help[/color] for commands.[/color]")


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1 or event.keycode == KEY_QUOTELEFT:
			_toggle()
			get_viewport().set_input_as_handled()


func _toggle() -> void:
	_visible = !_visible
	if _visible:
		show_console()
	else:
		hide_console()


func show_console() -> void:
	_visible = true
	_panel.show()
	_line_edit.grab_focus()
	_line_edit.clear()


func hide_console() -> void:
	_visible = false
	_panel.hide()


# ── Command handler ───────────────────────────

func _on_command(raw: String) -> void:
	var text := raw.strip_edges().to_lower()
	_line_edit.clear()

	if text == "":
		return

	_log_line("[color=white]> " + raw + "[/color]")

	var parts := text.split(" ", false)
	var cmd   := parts[0]
	var arg   := parts[1] if parts.size() > 1 else ""

	match cmd:

		"help":
			_log_line("""[color=yellow]── SCENES ──[/color]
  [color=cyan]goto <scene>[/color]     — jump to a scene instantly
       scenes: [color=white]house, cold_open, denial, bargaining, depression, acceptance[/color]

[color=yellow]── GAME STATE ──[/color]
  [color=cyan]complete <stage>[/color] — mark a stage as done (denial/bargaining/depression/acceptance)
  [color=cyan]complete all[/color]     — complete every stage at once
  [color=cyan]reset[/color]            — wipe all progress and restart
  [color=cyan]state[/color]            — show current GameState

[color=yellow]── CUTSCENES ──[/color]
  [color=cyan]skip[/color]             — skip the current intro / wake sequence (enables player movement)
  [color=cyan]nowake[/color]           — mark first_wake as false (skips intro on next house load)

[color=yellow]── MISC ──[/color]
  [color=cyan]warmth[/color]           — show current house warmth value
  [color=cyan]clear[/color]            — clear the log
  [color=cyan]close[/color]            — hide this console""")

		"goto":
			if arg == "":
				_log_error("Usage: goto <scene_name>")
			elif SCENES.has(arg):
				_log_ok("Jumping to: " + arg)
				hide_console()
				Game.set_black(true)
				get_tree().change_scene_to_file(SCENES[arg])
			else:
				_log_error("Unknown scene: '" + arg + "'. Valid: " + ", ".join(SCENES.keys()))

		"complete":
			if arg == "all":
				for stage in GameState.STAGES:
					GameState.complete_stage(stage, "[debug] force-completed")
				_log_ok("All stages completed. Warmth: " + str(GameState.warmth()))
			else:
				var proper := arg.capitalize()
				if GameState.STAGES.has(proper):
					GameState.complete_stage(proper, "[debug] force-completed")
					_log_ok("Completed: " + proper + " | Progress: " + str(GameState.completed.size()) + "/" + str(GameState.STAGES.size()))
				else:
					_log_error("Unknown stage: '" + arg + "'. Valid: denial, bargaining, depression, acceptance")

		"reset":
			GameState.reset()
			_log_ok("GameState reset. Returning to cold open...")
			hide_console()
			await get_tree().create_timer(0.3).timeout
			Game.set_black(true)
			get_tree().change_scene_to_file(SCENES["cold_open"])

		"state":
			_log_line("[color=yellow]── GameState ──[/color]")
			_log_line("  current_stage : " + GameState.current_stage())
			_log_line("  completed     : " + str(GameState.completed))
			_log_line("  fragments     : " + str(GameState.fragments))
			_log_line("  first_wake    : " + str(GameState.first_wake))
			_log_line("  title_shown   : " + str(GameState.title_shown))
			_log_line("  warmth        : " + str(GameState.warmth()))

		"skip":
			var players := get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				players[0].can_move = true
				_log_ok("Player movement unlocked.")
			else:
				_log_error("No player found in scene.")
			Game.hide_prompt()

		"nowake":
			GameState.first_wake = false
			_log_ok("first_wake set to false — intro will be skipped on next house load.")

		"warmth":
			_log_line("Warmth: [color=yellow]" + str(GameState.warmth()) + "[/color] (" + str(GameState.completed.size()) + "/" + str(GameState.STAGES.size()) + " stages)")

		"clear":
			_log.clear()

		"close":
			hide_console()

		_:
			_log_error("Unknown command: '" + cmd + "'. Type [color=white]help[/color].")


# ── Log helpers ───────────────────────────────

func _log_line(text: String) -> void:
	_log.append_text(text + "\n")

func _log_ok(text: String) -> void:
	_log_line("[color=lime]✔ " + text + "[/color]")

func _log_error(text: String) -> void:
	_log_line("[color=red]✘ " + text + "[/color]")
