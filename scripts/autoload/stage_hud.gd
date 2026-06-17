extends CanvasLayer
## Bottom-left grief-stage progress indicator. Five abstract pips fill, in order,
## as the player resolves each stage; the pip for the stage they're currently on
## gently pulses. No stage names are shown — the progression stays wordless so it
## never spoils the grief-stage reveal. Autoloaded, so it rides on top of every
## scene (the house hub and the dream stages alike) but sits BELOW the global
## fade/title layer (Game = layer 100), so transitions still cover it cleanly.

func _ready() -> void:
	layer = 60
	var bar := PipBar.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

## The drawn bar. Repaints every frame so the current pip can pulse.
class PipBar extends Control:
	const MARGIN_X := 22.0      # gap from the left edge
	const MARGIN_Y := 22.0      # gap from the bottom edge
	const PIP_W := 26.0
	const PIP_H := 8.0
	const GAP := 8.0

	const COL_DONE := Color(0.86, 0.74, 0.55)          # resolved: warm amber
	const COL_CUR_HI := Color(0.97, 0.91, 0.79)        # current pip, peak of pulse
	const COL_PENDING := Color(0.40, 0.39, 0.43, 0.55) # not yet reached: dim
	const COL_TRACK := Color(0.0, 0.0, 0.0, 0.40)      # subtle dark backing

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var n: int = GameState.STAGES.size()
		if n <= 0:
			return
		var vp := get_viewport_rect().size
		var y := vp.y - MARGIN_Y - PIP_H
		var done: int = GameState.completed.size()
		var cur: int = GameState.current_index
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 3.0)

		for i in range(n):
			var x := MARGIN_X + i * (PIP_W + GAP)
			var r := Rect2(x, y, PIP_W, PIP_H)
			# dark backing so the pips read against any background
			draw_rect(Rect2(x - 1.0, y - 1.0, PIP_W + 2.0, PIP_H + 2.0), COL_TRACK)
			var col: Color
			if i < done:
				col = COL_DONE
			elif i == cur:
				# pulse between the warm "done" tone and a brighter highlight
				col = COL_DONE.lerp(COL_CUR_HI, pulse)
			else:
				col = COL_PENDING
			draw_rect(r, col)
