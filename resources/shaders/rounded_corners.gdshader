shader_type canvas_item;

uniform float corner_radius : hint_range(0.0, 0.5) = 0.15;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	vec2 uv = abs(UV - 0.5) * 2.0;
	vec2 corner = uv - 1.0 + corner_radius;
	float dist = length(max(corner, 0.0));
	
	float alpha = 1.0 - smoothstep(corner_radius - 0.01, corner_radius + 0.01, dist);
	
	COLOR = tex_color;
	COLOR.a *= alpha;
}
