extends Sprite2D
class_name ObjectiveGlow
## A soft, breathing warm halo that marks the CURRENT objective in the house — the
## sympathy cards to read, the bed to sleep in, the couch to sit on, and so on — so
## the next thing to do is always visually obvious in the grey room. Purely
## cosmetic: drop one at a world position (or bind it to a node so it follows the
## furniture), then call dismiss() once the objective is resolved.
##
## Usage:
##   var g := ObjectiveGlow.new()
##   world.add_child(g)
##   g.mark(Vector2(x, y))            # fixed spot
##   # ...or...
##   g.bind_to(some_sprite, Vector2(0, -8))   # follows the node
##   ...
##   g.dismiss()

const GLOW_TEX := "res://assets/art/fx/glow_warm.png"

var _follow: Node2D = null
var _follow_offset := Vector2.ZERO
var _pulse: Tween

func _init() -> void:
	if ResourceLoader.exists(GLOW_TEX):
		texture = load(GLOW_TEX)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Draw on an absolute layer well above the y-sorted furniture so the beacon is
	# never swallowed by a sprite in front of it.
	z_as_relative = false
	z_index = 25
	scale = Vector2(2.4, 2.4)
	modulate = Color(1.0, 0.94, 0.78, 0.0)   # warm, starts invisible then fades in

func _ready() -> void:
	# fade in, then breathe
	var inb := create_tween()
	inb.tween_property(self, "modulate:a", 0.85, 0.6)
	_pulse = create_tween().set_loops()
	_pulse.tween_property(self, "modulate:a", 0.45, 1.1).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(self, "modulate:a", 0.85, 1.1).set_trans(Tween.TRANS_SINE)

## Park the glow at a fixed world position.
func mark(pos: Vector2) -> void:
	global_position = pos

## Follow a node each frame (so it tracks furniture that can be dragged/moved).
func bind_to(node: Node2D, offset := Vector2.ZERO) -> void:
	_follow = node
	_follow_offset = offset
	if is_instance_valid(node):
		global_position = node.global_position + offset

func _process(_dt: float) -> void:
	if _follow and is_instance_valid(_follow):
		global_position = _follow.global_position + _follow_offset

## Fade out and free. Safe to call once the objective is done.
func dismiss() -> void:
	set_process(false)
	if _pulse and _pulse.is_valid():
		_pulse.kill()
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	t.tween_callback(queue_free)
