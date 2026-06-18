extends Node
## ─────────────────────────────────────────────
##  Sfx — autoloaded as `Sfx`
##  Fire-and-forget one-shot sound effects from anywhere:
##      Sfx.play("res://assets/Sound/New_Rustling_Rug.wav")
##
##  Each call spawns a short-lived AudioStreamPlayer that frees itself when the
##  clip ends, so overlapping sounds never cut each other off. Streams are cached
##  so the same file isn't reloaded every time.
## ─────────────────────────────────────────────

var _cache := {}

## Play `path` once. Optional volume (dB) and pitch. Returns the player (or null
## if the file is missing) in case the caller wants to stop/track it.
func play(path: String, volume_db := 0.0, pitch := 1.0) -> AudioStreamPlayer:
	if not ResourceLoader.exists(path):
		push_warning("Sfx.play: missing file %s" % path)
		return null
	var stream: AudioStream = _cache.get(path)
	if stream == null:
		stream = load(path)
		_cache[path] = stream
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p
