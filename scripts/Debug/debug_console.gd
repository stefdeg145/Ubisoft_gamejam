extends CanvasLayer
## ─────────────────────────────────────────────
##  DEBUG CONSOLE  (admin / developer only)
##  Toggle with:  F1  (or ` backtick)
##  Only active in debug builds — stripped in export.
## ─────────────────────────────────────────────

const SCENES := {
	"house":       "res://scenes/house/house.tscn",
	"cold_open":   "res://scenes/intro/cold_open.tscn",
	"denial":      "res://scenes/stages/stage_denial.tscn",
	"bargaining":  "res://scenes/stages/stage_bargaining.tscn",
	# depression runs inside house — use "goto depression" which triggers debug_trigger_depression()
	"acceptance":  "res://scenes/stages/stage_acceptance.tscn",
}

## Trigger anger sequence directly from console
## (anger runs inside house, so we goto house then fire it)
const ANGER_CMD := "anger"

var _visible   := false
var _panel     : Window
var _log       : RichTextLabel
var _line_edit : LineEdit


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return

	# FIX 1: persist across scene changes since this is an autoload
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide_console()


func _build_ui() -> void:
	_panel = Window.new()
	_panel.title         = "▶ DEBUG CONSOLE  (F1 to close)"
	_panel.size          = Vector2i(700, 380)
	_panel.min_size      = Vector2i(400, 260)
	_panel.position      = Vector2i(100, 60)
	_panel.unresizable   = false
	_panel.exclusive     = false
	_panel.always_on_top = true
	_panel.mouse_passthrough = false
	_panel.close_requested.connect(hide_console)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	var hint := Label.new()
	hint.text = "  type a command below — 'help' for the full list"
	hint.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	hint.add_theme_font_size_override("font_size", 12)
	vbox.add_child(hint)

	vbox.add_child(HSeparator.new())

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	vbox.add_child(_log)

	vbox.add_child(HSeparator.new())

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
		elif _visible:
			# FIX 2: swallow all keypresses so they never reach the game
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# FIX 3: while console is open, zero out all movement axes directly
	# This stops the player moving even though Input.get_vector is polled
	# in _physics_process (which ignores set_input_as_handled)
	if _visible:
		Input.action_release("ui_left")
		Input.action_release("ui_right")
		Input.action_release("ui_up")
		Input.action_release("ui_down")


func _toggle() -> void:
	_visible = !_visible
	if _visible:
		show_console()
	else:
		hide_console()


func show_console() -> void:
	_visible = true
	_panel.show()
	await get_tree().create_timer(0.05).timeout
	_regrab_focus()


func hide_console() -> void:
	_visible = false
	_panel.hide()
	# Release all movement keys so player doesn't drift after closing
	Input.action_release("ui_left")
	Input.action_release("ui_right")
	Input.action_release("ui_up")
	Input.action_release("ui_down")


func _regrab_focus() -> void:
	if _visible and _line_edit:
		_line_edit.grab_focus()
		_line_edit.clear()


# ── Command handler ───────────────────────────

func _on_command(raw: String) -> void:
	var text := raw.strip_edges().to_lower()
	_line_edit.clear()

	# FIX 4: always re-grab focus after every command
	_regrab_focus()

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
  [color=cyan]goto anger[/color]       — jump to house and immediately trigger the anger sequence
  [color=cyan]goto depression[/color]  — jump to house and immediately trigger the depression/voicemail sequence

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
			elif arg == "anger":
				_complete_prerequisites_for("anger")
				_log_ok("Loading house and triggering anger sequence...")
				Game.set_black(true)
				await get_tree().create_timer(0.1).timeout
				get_tree().change_scene_to_file(SCENES["house"])
				await get_tree().create_timer(0.8).timeout
				var house := get_tree().get_current_scene()
				if house and house.has_method("debug_trigger_anger"):
					house.debug_trigger_anger()
					_log_ok("Anger sequence triggered!")
				else:
					_log_error("House scene not ready yet — try again in a moment")
				_panel.show()
				_regrab_focus()
			elif arg == "depression":
				_complete_prerequisites_for("depression")
				_log_ok("Loading house and triggering depression sequence...")
				Game.set_black(true)
				await get_tree().create_timer(0.1).timeout
				get_tree().change_scene_to_file(SCENES["house"])
				await get_tree().create_timer(0.8).timeout
				var house := get_tree().get_current_scene()
				if house and house.has_method("debug_trigger_depression"):
					house.debug_trigger_depression()
					_log_ok("Depression sequence triggered!")
				else:
					_log_error("House scene not ready yet — try again in a moment")
				_panel.show()
				_regrab_focus()
			elif SCENES.has(arg):
				_complete_prerequisites_for(arg)
				_log_ok("Jumping to: " + arg)
				
				# --- FIX: Clear any hanging UI prompts before jumping ---
				if Game.has_method("hide_prompt"):
					Game.hide_prompt()
				# --------------------------------------------------------
				
				Game.set_black(true)
				await get_tree().create_timer(0.1).timeout
				get_tree().change_scene_to_file(SCENES[arg])
				await get_tree().create_timer(0.2).timeout
				# Re-show and re-focus after scene loads
				_panel.show()
				_regrab_focus()
			else:
				_log_error("Unknown scene: '" + arg + "'. Valid: " + ", ".join(SCENES.keys()))

		"complete":
			if arg == "all":
				for stage in GameState.STAGES:
					GameState.complete_stage(stage, "[debug] force-completed")
				_log_ok("All stages completed. Warmth: " + str(GameState.warmth()))
				_refresh_house_grade()
				_refresh_house_grade()
			else:
				var proper := arg.capitalize()
				if GameState.STAGES.has(proper):
					GameState.complete_stage(proper, "[debug] force-completed")
					_log_ok("Completed: " + proper + " | Progress: " + str(GameState.completed.size()) + "/" + str(GameState.STAGES.size()))
					_refresh_house_grade()
					_refresh_house_grade()
				else:
					_log_error("Unknown stage: '" + arg + "'. Valid: denial, bargaining, depression, acceptance")

		"reset":
			GameState.reset()
			_log_ok("GameState reset. Returning to cold open...")
			Game.set_black(true)
			await get_tree().create_timer(0.3).timeout
			get_tree().change_scene_to_file(SCENES["cold_open"])
			await get_tree().create_timer(0.2).timeout
			_panel.show()
			_regrab_focus()

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
			if Game.has_method("hide_prompt"):
				Game.hide_prompt()
			# FIX 6: re-grab focus explicitly after skip
			await get_tree().create_timer(0.05).timeout
			_regrab_focus()

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

## Auto-completes all prerequisite stages before jumping to a scene
func _complete_prerequisites_for(scene_name: String) -> void:
	var prerequisites := {
		"denial":      [],
		"anger":       ["Denial"],
		"bargaining":  ["Denial", "Anger"],
		"depression":  ["Denial", "Anger", "Bargaining"],
		"acceptance":  ["Denial", "Anger", "Bargaining", "Depression"],
	}
	if not prerequisites.has(scene_name):
		return
	for stage in prerequisites[scene_name]:
		if not GameState.completed.has(stage):
			GameState.complete_stage(stage, "[debug] skipped to " + scene_name)
	_refresh_house_grade()

## Refreshes the house warmth bar after completing stages via console
func _refresh_house_grade() -> void:
	var scene := get_tree().get_current_scene()
	if scene and scene.has_method("_update_grade"):
		scene._update_grade()
		_log_ok("Progression bar updated.")
	else:
		_log_line("[color=gray]Note: not in house scene, bar will update when you return.[/color]")

func _log_line(text: String) -> void:
	_log.append_text(text + "\n")

func _log_ok(text: String) -> void:
	_log_line("[color=lime]✔ " + text + "[/color]")

func _log_error(text: String) -> void:
	_log_line("[color=red]✘ " + text + "[/color]")
