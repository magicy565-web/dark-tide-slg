shader_type spatial;
render_mode unshaded, cull_disabled;

// Distance from nearest revealed tile: 0.0 = edge, 1.0 = full dense fog
uniform float fog_density : hint_range(0.0, 1.0) = 1.0;
// Master alpha for fade-in / fade-out transitions
uniform float alpha_multiplier : hint_range(0.0, 1.0) = 1.0;
// Base fog color (dark brownish)
uniform vec4 fog_color : source_color = vec4(0.35, 0.3, 0.22, 1.0);
// Edge tint (lighter)
uniform vec4 edge_color : source_color = vec4(0.45, 0.42, 0.35, 1.0);

// Noise animation speed
uniform float scroll_speed : hint_range(0.0, 2.0) = 0.15;
// Noise scale
uniform float noise_scale : hint_range(0.5, 10.0) = 3.0;
// Pulse intensity
uniform float pulse_strength : hint_range(0.0, 0.3) = 0.08;
// Pulse speed
uniform float pulse_speed : hint_range(0.1, 5.0) = 1.2;

// ── Procedural noise helpers ──
vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f); // smoothstep
	float a = dot(hash22(i), vec2(1.0));
	float b = dot(hash22(i + vec2(1.0, 0.0)), vec2(1.0));
	float c = dot(hash22(i + vec2(0.0, 1.0)), vec2(1.0));
	float d = dot(hash22(i + vec2(1.0, 1.0)), vec2(1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * value_noise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	// World-space UV from vertex position for seamless tiling across hexes
	vec2 uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;

	// Scrolling noise
	float t = TIME * scroll_speed;
	float n1 = fbm(uv * noise_scale + vec2(t * 0.7, t * 0.3));
	float n2 = fbm(uv * noise_scale * 1.5 + vec2(-t * 0.4, t * 0.6));
	float noise_val = mix(n1, n2, 0.5);

	// Breathing pulse
	float pulse = 1.0 + pulse_strength * sin(TIME * pulse_speed + uv.x * 0.5);

	// Blend fog color: dense center is dark, edges are lighter
	vec3 col = mix(edge_color.rgb, fog_color.rgb, fog_density);

	// Modulate color with noise for cloud pattern
	col = mix(col, col * 1.3, noise_val * 0.4);

	// Compute base alpha:
	//   fog_density controls how thick the fog is (distance-based)
	//   At density 1.0 (far from revealed): alpha ~0.55
	//   At density 0.0 (right at edge): alpha ~0.12
	float base_alpha = mix(0.12, 0.55, fog_density);

	// Add noise variation to alpha for cloud-like appearance
	float alpha = base_alpha * pulse;
	alpha *= mix(0.7, 1.0, noise_val);

	// Apply transition multiplier (for tweened fade in/out)
	alpha *= alpha_multiplier;

	ALBEDO = col;
	ALPHA = clamp(alpha, 0.0, 0.7);
}
