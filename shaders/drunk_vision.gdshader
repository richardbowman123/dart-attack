shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

// Drunk vision post-processing.
// Runs on a QuadMesh sized to fill the camera's FOV, positioned in front of it.
// blend_mix + render_priority 127 = renders last in transparent pass.
// depth_test_disabled = draws over all scene geometry.
// hint_screen_texture reads the fully-rendered 3D scene.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float sway_time = 0.0;

void fragment() {
	// Pass through when sober
	if (intensity < 0.01) {
		ALBEDO = texture(screen_texture, SCREEN_UV).rgb;
		ALPHA = 1.0;
		return;
	}

	// ── Sway — whole screen drifts side to side (kicks in above 0.65) ──
	float sway_str = smoothstep(0.65, 1.0, intensity);
	vec2 sway = vec2(
		sin(sway_time * 1.5) * sway_str * 0.025,
		cos(sway_time * 2.1) * sway_str * 0.015
	);
	vec2 uv = SCREEN_UV + sway;

	// ── Two-ring 9-tap blur — inner (tight) + outer (wide) ──
	float r1 = intensity * 0.012;  // Inner ring ~9px at full
	float r2 = intensity * 0.030;  // Outer ring ~22px at full
	vec3 color = texture(screen_texture, uv).rgb * 0.22;
	// Inner ring — 4 cardinal taps
	color += texture(screen_texture, uv + vec2(r1, 0.0)).rgb * 0.12;
	color += texture(screen_texture, uv - vec2(r1, 0.0)).rgb * 0.12;
	color += texture(screen_texture, uv + vec2(0.0, r1)).rgb * 0.12;
	color += texture(screen_texture, uv - vec2(0.0, r1)).rgb * 0.12;
	// Outer ring — 4 cardinal taps
	color += texture(screen_texture, uv + vec2(r2, 0.0)).rgb * 0.075;
	color += texture(screen_texture, uv - vec2(r2, 0.0)).rgb * 0.075;
	color += texture(screen_texture, uv + vec2(0.0, r2)).rgb * 0.075;
	color += texture(screen_texture, uv - vec2(0.0, r2)).rgb * 0.075;
	// Weights: 0.22 + 4*0.12 + 4*0.075 = 1.00

	// ── Double vision — offset ghost image blended in ──
	float dv_mix = smoothstep(0.05, 0.7, intensity) * 0.5;
	float dv_off = intensity * 0.05;  // ~36px offset at full
	vec2 dv_uv = uv + vec2(dv_off, dv_off * 0.35);
	vec3 dv_color = texture(screen_texture, dv_uv).rgb * 0.5;
	dv_color += texture(screen_texture, dv_uv + vec2(r1, 0.0)).rgb * 0.25;
	dv_color += texture(screen_texture, dv_uv - vec2(r1, 0.0)).rgb * 0.25;
	color = mix(color, dv_color, dv_mix);

	// ── Warm colour shift — amber tint (kicks in above 0.3) ──
	float warmth = smoothstep(0.3, 1.0, intensity);
	color.r += warmth * 0.12;
	color.g += warmth * 0.04;
	color.b -= warmth * 0.10;

	// ── Vignette — darken edges hard (kicks in above 0.65) ──
	float vig_str = smoothstep(0.65, 1.0, intensity) * 2.5;
	vec2 vig_uv = SCREEN_UV - 0.5;
	float vig = 1.0 - dot(vig_uv, vig_uv) * vig_str;
	color *= clamp(vig, 0.0, 1.0);

	ALBEDO = color;
	ALPHA = 1.0;
}
