shader_type canvas_item;

// Digital-glitch / RGB-split twitch for title & logo cards.
// The image sits mostly stable with a faint shimmer, then occasional short
// "bug" bursts split the colour channels, tear horizontal slices and jump the
// whole frame a little. Node modulate alpha is preserved so fade in/out works.

uniform float intensity : hint_range(0.0, 2.0) = 1.0;  // overall strength
uniform float rgb_px = 6.0;                            // max channel split (px) in a burst
uniform float speed = 1.0;                             // time scale

float rand(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	vec4 mod_col = COLOR;            // node modulate (carries the fade alpha)
	float t = TIME * speed;

	// Burst gate: only a minority of time slots are "glitching" -> twitchy, not constant.
	float slot = floor(t * 9.0);
	float burst = step(0.80, rand(slot));
	float amt = intensity * (0.18 + burst * 1.0);

	// Per-band horizontal tear, only during a burst.
	float band = floor(UV.y * 28.0);
	float tear = (rand(band + slot * 3.7) - 0.5) * 0.05 * burst * intensity;

	// Occasional whole-image vertical jump.
	float jump = (rand(slot * 1.3) - 0.5) * 0.015 * burst * intensity;

	vec2 uv = UV + vec2(tear, jump);

	// RGB split: sample red/blue offset sideways from green, scaled px -> UV.
	vec2 off = TEXTURE_PIXEL_SIZE * rgb_px * amt;
	float r = texture(TEXTURE, uv + vec2(off.x, 0.0)).r;
	vec4 cg = texture(TEXTURE, uv);
	float b = texture(TEXTURE, uv - vec2(off.x, 0.0)).b;

	COLOR = vec4(vec3(r, cg.g, b) * mod_col.rgb, cg.a * mod_col.a);
}
