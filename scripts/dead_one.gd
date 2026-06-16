extends RefCounted
class_name DeadOne
## Helper for the lost relative's sprite.
##
## The artist supplied a single sheet (Dead_one.png) with two poses stacked
## vertically on a transparent background: a 3/4 pose on top and a front-facing
## pose on the bottom. Rather than hard-code pixel coordinates (which would break
## if the art is re-exported), we scan the image alpha at load time, split it into
## its separate poses, and hand back AtlasTextures cropped to each one.
##
## Use DeadOne.front() for the front-facing pose (the clear, face-on portrait) and
## DeadOne.three_quarter() for the side-ish pose.

const SHEET := "res://assets/art/characters/Dead_one.png"
const ALPHA_CUTOFF := 16          # pixels dimmer than this count as empty
const GAP_ROWS := 4               # this many empty rows in a row = a new pose

static var _cache: Array[Rect2] = []

## Returns the bounding boxes of every pose found on the sheet, top to bottom.
static func poses() -> Array[Rect2]:
	if not _cache.is_empty():
		return _cache
	var tex: Texture2D = load(SHEET)
	if tex == null:
		return _cache
	var img: Image = tex.get_image()
	if img == null:
		return _cache
	var w := img.get_width()
	var h := img.get_height()

	# which rows contain any visible pixel
	var row_has: Array[bool] = []
	row_has.resize(h)
	for y in range(h):
		var found := false
		for x in range(w):
			if img.get_pixel(x, y).a * 255.0 > ALPHA_CUTOFF:
				found = true
				break
		row_has[y] = found

	# group contiguous content rows into clusters (tolerating tiny gaps)
	var clusters: Array = []        # each: [start_y, end_y]
	var start := -1
	var gap := 0
	for y in range(h):
		if row_has[y]:
			if start == -1:
				start = y
			gap = 0
		else:
			if start != -1:
				gap += 1
				if gap >= GAP_ROWS:
					clusters.append([start, y - gap])
					start = -1
					gap = 0
	if start != -1:
		clusters.append([start, h - 1])

	# tighten each cluster horizontally and store as a Rect2
	for c in clusters:
		var y0: int = c[0]
		var y1: int = c[1]
		var minx := w
		var maxx := 0
		for y in range(y0, y1 + 1):
			for x in range(w):
				if img.get_pixel(x, y).a * 255.0 > ALPHA_CUTOFF:
					minx = min(minx, x)
					maxx = max(maxx, x)
		if maxx >= minx:
			_cache.append(Rect2(minx, y0, maxx - minx + 1, y1 - y0 + 1))

	return _cache

static func _atlas(region: Rect2) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = load(SHEET)
	at.region = region
	return at

## Front-facing pose (the lowest one on the sheet). Falls back to the whole
## texture if detection somehow finds nothing.
static func front() -> Texture2D:
	var p := poses()
	if p.is_empty():
		return load(SHEET)
	return _atlas(p[p.size() - 1])

## The 3/4 / side-ish pose (the topmost one).
static func three_quarter() -> Texture2D:
	var p := poses()
	if p.is_empty():
		return load(SHEET)
	return _atlas(p[0])
