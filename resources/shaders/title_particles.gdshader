shader_type canvas_item;

uniform float speed : hint_range(0.0, 1.0) = 0.10;
uniform float brightness : hint_range(0.0, 3.0) = 1.8;

// -- 浪漫粉金调：樱花粉 ⇄ 暖金色 ⇄ 奶油白 ⇄ 玫瑰粉 --
vec3 romantic_color(float seed) {
	vec3 sakura  = vec3(0.98, 0.72, 0.80); // 樱花粉
	vec3 gold    = vec3(1.00, 0.88, 0.55); // 暖金色
	vec3 cream   = vec3(1.00, 0.94, 0.80); // 奶油白
	vec3 rose    = vec3(0.92, 0.52, 0.65); // 玫瑰粉

	float t = fract(seed * 9.37);
	if (t < 0.33) {
		return mix(sakura, gold, t * 3.03);
	} else if (t < 0.66) {
		return mix(gold, cream, (t - 0.33) * 3.03);
	} else {
		return mix(cream, rose, (t - 0.66) * 3.03);
	}
}

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = vec3(0.0);

	for (int i = 0; i < 50; i++) {
		float fi = float(i);
		float seed_a = hash(fi);
		float seed_b = hash(fi + 1.0);
		float seed_c = hash(fi + 2.0);
		float seed_d = hash(fi + 3.0);
		float seed_e = hash(fi + 4.0);

		float px = seed_a;
		float speed_var = 0.2 + seed_c * 0.8;
		float py = fract(seed_b + TIME * speed * speed_var);
		vec2 pos = vec2(px, py);

		float d = length(uv - pos);
		// 粒子光晕范围：8~30 像素级别（在 1920px 宽屏幕上）
		float size = 0.004 + seed_d * 0.012;
		float glow = smoothstep(size * 4.0, 0.0, d);
		float twinkle = sin(TIME * (1.0 + seed_b * 3.0) + seed_c * 6.283) * 0.25 + 0.75;
		float edge_fade = smoothstep(0.0, 0.03, py) * smoothstep(1.0, 0.97, py);

		vec3 pcolor = romantic_color(seed_e);
		col += pcolor * glow * twinkle * edge_fade * (0.5 + seed_b * 0.5) * brightness;
	}

	// 保证 alpha 足够不透明
	float a = clamp(length(col) * 1.2, 0.0, 1.0);
	COLOR = vec4(col, a);
}
