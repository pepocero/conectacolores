// Variante móvil del boom cartoon: mismo look aproximado y uniforms,
// sin worley / noise / border(grad) (fill-rate + fragment cost).

shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec3 boom_pal1 : source_color = vec3(0.2, 0.15, 0.3);
uniform vec3 boom_pal2 : source_color = vec3(0.9, 0.15, 0.05);
uniform vec3 boom_pal3 : source_color = vec3(0.9, 0.5, 0.1);
uniform vec3 boom_pal4 : source_color = vec3(0.95, 0.95, 0.35);

uniform vec3 smoke_pal1 : source_color = vec3(0.2, 0.15, 0.3);
uniform vec3 smoke_pal2 : source_color = vec3(0.35, 0.3, 0.45);
uniform vec3 smoke_pal3 : source_color = vec3(0.5, 0.45, 0.6);

uniform float size : hint_range(0.1, 50.0, 0.1) = 4.2;
uniform float disperse : hint_range(0.1, 10.0, 0.1) = 1.0;
uniform float boom_repeat : hint_range(0.0, 10.0, 0.1) = 1.0;
uniform float boom_shape : hint_range(0.1, 20.0, 0.1) = 12.0;
uniform float boom_distortion : hint_range(0.0, 10.0, 0.1) = 0.5;
uniform float boom_bubbles : hint_range(0.0, 10.0, 0.1) = 0.5;
uniform float boom_bw : hint_range(0.0, 10.0, 0.1) = 0.5;

uniform float smoke_repeat : hint_range(0.0, 10.0, 0.1) = 1.0;
uniform float smoke_shape : hint_range(0.0, 30.0, 0.1) = 16.0;
uniform float smoke_distortion : hint_range(0.0, 10.0, 0.1) = 1.5;
uniform float smoke_bubbles : hint_range(0.0, 10.0, 0.1) = 0.5;
uniform float smoke_bw : hint_range(0.0, 10.0, 0.1) = 0.75;

uniform vec2 disp = vec2(0.0);
uniform float explosion_time : hint_range(0.0, 2.0, 0.01) = 0.0;
uniform float aspect : hint_range(0.2, 5.0, 0.01) = 1.0;

float posterize(float v, float n) {
	return floor(v * n) / max(n - 1.0, 1.0);
}

void fragment() {
	vec2 uv = UV;
	uv.y = 1.0 - uv.y;
	vec2 pos = (uv - vec2(0.5, 0.48)) * vec2(aspect, 1.0);
	pos *= size;
	pos -= disp;

	float repeat = clamp(explosion_time * boom_repeat, 0.001, 1.999);
	float dist = length(pos);
	// Misma envolvente radial que el boom completo (pico ~ explosion_time 0.25).
	float boom_val = 1.0 - (dist * dist) / (repeat * boom_shape) - repeat * 2.0;
	// Ondulación barata (sin noise 3D).
	boom_val += 0.08 * sin(dist * 6.0 - explosion_time * 8.0) * boom_distortion;

	float boom_a = step(0.0, boom_val);
	float boom_idx = clamp(posterize(boom_val, 4.0) * 4.0, 0.0, 3.0);
	vec3 boom_col = boom_pal1;
	if (boom_idx >= 3.0) {
		boom_col = boom_pal4;
	} else if (boom_idx >= 2.0) {
		boom_col = boom_pal3;
	} else if (boom_idx >= 1.0) {
		boom_col = boom_pal2;
	}

	float s_repeat = clamp(explosion_time * smoke_repeat, 0.001, 1.999);
	vec2 smoke_pos = pos - vec2(0.0, 1.2) * pow(s_repeat / 1.45, 2.0);
	float smoke_dist = length(smoke_pos);
	float smoke_val = 1.0 - (smoke_dist * smoke_dist) / (s_repeat * smoke_shape) - pow(s_repeat * 1.5, 0.5);
	smoke_val += 0.06 * sin(smoke_dist * 4.0 + explosion_time * 3.0);

	float smoke_a = step(0.0, smoke_val);
	float smoke_idx = clamp(posterize(smoke_val, 3.0) * 3.0, 0.0, 2.0);
	vec3 smoke_col = smoke_pal1;
	if (smoke_idx >= 2.0) {
		smoke_col = smoke_pal3;
	} else if (smoke_idx >= 1.0) {
		smoke_col = smoke_pal2;
	}

	float bw = step(smoke_val * 1.25, boom_val);
	vec3 color = bw * boom_col + (1.0 - bw) * smoke_col;
	float alpha = bw * boom_a + (1.0 - bw) * smoke_a;
	// Borde suave barato (sustituye border/grad).
	float edge = smoothstep(-0.15, 0.05, max(boom_val, smoke_val));
	alpha *= edge;
	alpha *= 1.0 - smoothstep(1.55, 1.95, explosion_time);
	COLOR = vec4(color, alpha);
}
