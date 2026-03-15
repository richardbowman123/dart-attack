shader_type canvas_item;

// Drunk vision post-processing — canvas_item shader on a full-screen ColorRect.
// Sits on a CanvasLayer (layer 10) above all game UI.
// Each effect is controlled by its own uniform, driven from DrinkManager.

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 1.0) = 0.0;
uniform float double_vision : hint_range(0.0, 1.0) = 0.0;
uniform float sway_amount : hint_range(0.0, 1.0) = 0.0;
uniform float sway_speed : hint_range(0.0, 5.0) = 1.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.0;
uniform float warmth : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;

	// ── Sway — sinusoidal bob (vertical + horizontal) ──
	uv.y += sin(TIME * sway_speed) * sway_amount * 0.02;
	uv.x += cos(TIME * sway_speed * 0.7) * sway_amount * 0.015;

	// ── Blur — 9-sample box blur ──
	vec2 texel = 1.0 / vec2(textureSize(SCREEN_TEXTURE, 0));
	vec2 off = texel * blur_amount * 10.0;

	vec4 colour = texture(SCREEN_TEXTURE, uv);
	colour += texture(SCREEN_TEXTURE, uv + vec2(-off.x, -off.y));
	colour += texture(SCREEN_TEXTURE, uv + vec2( 0.0,  -off.y));
	colour += texture(SCREEN_TEXTURE, uv + vec2( off.x, -off.y));
	colour += texture(SCREEN_TEXTURE, uv + vec2(-off.x,  0.0));
	colour += texture(SCREEN_TEXTURE, uv + vec2( off.x,  0.0));
	colour += texture(SCREEN_TEXTURE, uv + vec2(-off.x,  off.y));
	colour += texture(SCREEN_TEXTURE, uv + vec2( 0.0,   off.y));
	colour += texture(SCREEN_TEXTURE, uv + vec2( off.x,  off.y));
	colour /= 9.0;

	// ── Double vision — horizontal ghost image ──
	vec4 ghost = texture(SCREEN_TEXTURE, uv + vec2(double_vision * 0.03, 0.0));
	colour = mix(colour, ghost, 0.5);

	// ── Vignette — darken edges ──
	float dist = distance(SCREEN_UV, vec2(0.5, 0.5));
	float vignette = 1.0 - smoothstep(0.4, 0.9, dist);
	colour.rgb *= mix(1.0, vignette, vignette_strength);

	// ── Warmth — warm yellow tint ──
	colour.r = min(colour.r + warmth * 0.15, 1.0);
	colour.g = min(colour.g + warmth * 0.05, 1.0);
	colour.b = max(colour.b - warmth * 0.1, 0.0);

	COLOR = colour;
}
