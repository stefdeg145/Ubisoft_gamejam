extends Node2D
## STAGE 2 — BARGAINING · "The Last Meeting" (park flashback, Dialogic-driven).
##
## A flashback the protagonist drifts into from the living-room couch. He stands
## across from the relative he lost, in the park, on the afternoon it went wrong.
## The scene plays once as it really happened, then loops back to the start and
## lets the player try to "fix" it with dialogue choices — but every path still
## ends with the same goodbye. Realising it can't be fixed ("I was the one at
## fault") resolves the stage and wakes back into the house.
##
## All dialogue runs through Dialogic (timelines in res://dialogic/timelines/).
## The two big characters on either side of the screen and the small speaker
## portrait by the dialogue box are this scene's own nodes; Dialogic only drives
## the textbox, the names and the choices. We listen to Dialogic's speaker_updated
## signal to know whose turn it is and light them up accordingly.

const PARK_TIMELINE := "res://dialogic/timelines/bargaining_park.dtl"
const FX := "res://assets/art/fx/"
const PARK_AMBIENCE := "res://assets/Sound/Park ambience sound  (Royalty Free).mp3"

# These names must match the speaker names used in bargaining_park.dtl.
const PROT_NAME := "Me"
const DEAD_NAME := "Sam"     # the lost relative — rename here AND in the .dtl to taste

const TARGET_H := 300.0      # on-screen height of the big character sprites
const PROT_POS := Vector2(300, 450)
const DEAD_POS := Vector2(980, 450)

var _prot: Sprite2D
var _dead: Sprite2D
var _portrait: TextureRect
var _portrait_frame: Panel
var _prot_tex: Texture2D
var _dead_tex: Texture2D
var _prot_portrait_tex: Texture2D    # front-facing face for the dialogue-box portrait
var _ambience: AudioStreamPlayer     # looping park background sound
var _finished := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_background()
	_build_characters()
	_build_speaker_portrait()
	_start_park_ambience()

	# Reveal the flashback, then let it play.
	await Game.wake(1.8)
	await Game.say("The park. That grey afternoon. It's happening again.", 3.0)

	# Listen for who is speaking so we can light up the right side + portrait.
	Dialogic.Text.speaker_updated.connect(_on_speaker_updated)
	Dialogic.timeline_ended.connect(_on_timeline_ended, CONNECT_ONE_SHOT)

	Dialogic.start(_load_timeline(PARK_TIMELINE))

func _exit_tree() -> void:
	if Dialogic.Text.speaker_updated.is_connected(_on_speaker_updated):
		Dialogic.Text.speaker_updated.disconnect(_on_speaker_updated)

# ---------------------------------------------------------------- ambience
## Quiet, looping park background (birds/wind). Kept low so it sits under the
## dialogue; faded out when the flashback resolves.
func _start_park_ambience() -> void:
	if not ResourceLoader.exists(PARK_AMBIENCE):
		return
	_ambience = AudioStreamPlayer.new()
	var stream = load(PARK_AMBIENCE)
	if stream is AudioStreamMP3:
		stream.loop = true
	_ambience.stream = stream
	_ambience.volume_db = -12.0
	_ambience.bus = "Master"
	add_child(_ambience)
	_ambience.play()

# ---------------------------------------------------------------- timeline io
## Reads the .dtl as plain text and builds the timeline in code. This avoids any
## dependence on the .dtl resource loader being registered at runtime, while the
## files stay fully editable in the Dialogic editor.
func _load_timeline(path: String) -> DialogicTimeline:
	var tl := DialogicTimeline.new()
	var f := FileAccess.open(path, FileAccess.READ)
	if f:
		tl.from_text(f.get_as_text())
		f.close()
	return tl

# ---------------------------------------------------------------- background
const PARK_BG := "res://scenes/stages/Bargaining_bg.jpg"

func _build_background() -> void:
	var cl := CanvasLayer.new()
	cl.layer = -10
	add_child(cl)

	# the park backdrop, stretched to fill the 1280x720 viewport
	var bg := TextureRect.new()
	bg.texture = load(PARK_BG)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(bg)

	# soft vignette for the flashback mood
	if ResourceLoader.exists(FX + "vignette.png"):
		var vig := TextureRect.new()
		vig.texture = load(FX + "vignette.png")
		vig.stretch_mode = TextureRect.STRETCH_SCALE
		vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vig.modulate = Color(1, 1, 1, 0.22)
		vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cl.add_child(vig)

## A flattened, semi-transparent ellipse that grounds a character's feet.
func _ground_shadow(center: Vector2, rx: float, ry: float) -> void:
	var pts := PackedVector2Array()
	for i in range(24):
		var a := TAU * i / 24.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = Color(0, 0, 0, 0.22)
	add_child(p)

# ---------------------------------------------------------------- characters
func _build_characters() -> void:
	# grounding shadows under each character's feet (added first so they sit behind)
	_ground_shadow(PROT_POS + Vector2(0, TARGET_H * 0.5), 78, 16)
	_ground_shadow(DEAD_POS + Vector2(0, TARGET_H * 0.5), 78, 16)

	# protagonist on the left, facing right toward the relative
	_prot_tex = load("res://assets/art/characters/walk_right_0.png")
	_prot_portrait_tex = load("res://assets/art/characters/walk_down_0.png")
	_prot = _big_sprite(_prot_tex, PROT_POS, false)
	add_child(_prot)

	# the lost relative on the right, front pose, mirrored to face the protagonist
	_dead_tex = DeadOne.front()
	_dead = _big_sprite(_dead_tex, DEAD_POS, true)
	add_child(_dead)

	# start with both a touch dim; the speaker lights up when they talk
	_prot.modulate = Color(0.7, 0.7, 0.74)
	_dead.modulate = Color(0.7, 0.7, 0.74)

func _big_sprite(tex: Texture2D, pos: Vector2, flip: bool) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = true
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var th: float = max(1.0, tex.get_height())
	var s: float = TARGET_H / th
	sp.scale = Vector2(s, s)
	if flip:
		sp.scale.x *= -1
	sp.position = pos
	return sp

# ------------------------------------------------ small speaker portrait
func _build_speaker_portrait() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 80          # above the park, sits over the Dialogic textbox area
	add_child(cl)

	_portrait_frame = Panel.new()
	_portrait_frame.position = Vector2(28, 470)
	_portrait_frame.size = Vector2(150, 150)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.10, 0.09, 0.12, 0.92)
	box.set_corner_radius_all(8)
	box.set_border_width_all(3)
	box.border_color = Color(0.85, 0.78, 0.62, 0.9)
	box.set_content_margin_all(8)
	_portrait_frame.add_theme_stylebox_override("panel", box)
	cl.add_child(_portrait_frame)

	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait.offset_left = 8
	_portrait.offset_top = 8
	_portrait.offset_right = -8
	_portrait.offset_bottom = -8
	_portrait_frame.add_child(_portrait)

	_portrait_frame.visible = false

# ---------------------------------------------------------------- speaker fx
func _on_speaker_updated(character: DialogicCharacter) -> void:
	var speaker_name := ""
	if character != null:
		speaker_name = character.display_name
	if speaker_name == DEAD_NAME:
		_focus(_dead, _prot)
		_set_portrait(_dead_tex, true)
	else:
		# protagonist (and his own internal-thought lines) light the left side
		_focus(_prot, _dead)
		_set_portrait(_prot_portrait_tex, false)

## Brighten + gently pop the speaker, dim the listener.
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

# ---------------------------------------------------------------- resolve
func _on_timeline_ended() -> void:
	if _finished:
		return
	_finished = true
	if _portrait_frame:
		_portrait_frame.visible = false
	await Game.say("Some doors only close once.", 3.0)
	GameState.complete_stage("Bargaining", "The meeting — some doors only close once.")
	# Let the park fade with the flashback rather than cutting out.
	if _ambience and is_instance_valid(_ambience):
		create_tween().tween_property(_ambience, "volume_db", -40.0, 1.6)
	# Bleed reverses straight into Depression: he surfaces from the flashback still
	# sitting on the couch (stage_depression opens there), drained, unable to move.
	await Game.fade_out(1.6)
	Game.change_scene("res://scenes/stages/stage_depression.tscn")
