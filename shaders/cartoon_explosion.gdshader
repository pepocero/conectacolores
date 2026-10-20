// Cartoon explosion — celebración al completar nivel (todas las bolas a la vez).
// Origen: https://godotshaders.com/shader/cartoon-explosion-effect/ (RayL019)
// Port de Shadertoy: https://www.shadertoy.com/view/X3dGz2
// Licencia por defecto Shadertoy: CC BY-NC-SA 3.0 (revisar antes de publicar comercialmente).
// Adaptado: UV local + uniform explosion_time (one-shot 0..2) en lugar de bucle con TIME.

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
// Tiempo de la explosión (0..~2). Lo anima GDScript.
uniform float explosion_time : hint_range(0.0, 2.0, 0.01) = 0.0;
// Relación ancho/alto del rectángulo (width/height).
uniform float aspect : hint_range(0.2, 5.0, 0.01) = 1.0;

vec3 n_rand3(vec3 p) {
	vec3 r =
		fract(
			sin(
				vec3(
					dot(p, vec3(127.1, 311.7, 371.8)),
					dot(p, vec3(269.5, 183.3, 456.1)),
					dot(p, vec3(352.5, 207.3, 198.67))
				)
			) * 43758.5453
		) * 2.0 - 1.0;
	return normalize(vec3(r.x / cos(r.x), r.y / cos(r.y), r.z / cos(r.z)));
}

float noise(vec3 p) {
	vec3 fv = fract(p);
	vec3 nv = floor(p);
	vec3 u = fv * fv * fv * (fv * (fv * 6.0 - 15.0) + 10.0);
	return mix(
		mix(
			mix(
				dot(n_rand3(nv + vec3(0.0, 0.0, 0.0)), fv - vec3(0.0, 0.0, 0.0)),
				dot(n_rand3(nv + vec3(1.0, 0.0, 0.0)), fv - vec3(1.0, 0.0, 0.0)),
				u.x
			),
			mix(
				dot(n_rand3(nv + vec3(0.0, 1.0, 0.0)), fv - vec3(0.0, 1.0, 0.0)),
				dot(n_rand3(nv + vec3(1.0, 1.0, 0.0)), fv - vec3(1.0, 1.0, 0.0)),
				u.x
			),
			u.y
		),
		mix(
			mix(
				dot(n_rand3(nv + vec3(0.0, 0.0, 1.0)), fv - vec3(0.0, 0.0, 1.0)),
				dot(n_rand3(nv + vec3(1.0, 0.0, 1.0)), fv - vec3(1.0, 0.0, 1.0)),
				u.x
			),
			mix(
				dot(n_rand3(nv + vec3(0.0, 1.0, 1.0)), fv - vec3(0.0, 1.0, 1.0)),
				dot(n_rand3(nv + vec3(1.0, 1.0, 1.0)), fv - vec3(1.0, 1.0, 1.0)),
				u.x
			),
			u.y
		),
		u.z
	);
}

float worley(vec3 s) {
	vec3 si = floor(s);
	vec3 sf = fract(s);
	float m_dist = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			for (int z = -1; z <= 1; z++) {
				vec3 neighbor = vec3(float(x), float(y), float(z));
				vec3 point = fract(n_rand3(si + neighbor));
				point = 0.5 + 0.5 * sin(disperse * explosion_time + 6.2831 * point);
				vec3 diff = neighbor + point - sf;
				m_dist = min(m_dist, length(diff));
			}
		}
	}
	return m_dist;
}

float boom(vec2 p) {
	float repeat = clamp(explosion_time * boom_repeat, 0.001, 1.999);
	float shape = 1.0 - pow(distance(vec3(p, 0.0), vec3(0.0)), 2.0) / (repeat * boom_shape) - repeat * 2.0;
	float distortion = noise(vec3(p * boom_distortion, explosion_time * 0.5));
	float bubbles = boom_bubbles - pow(worley(vec3(p * 1.2, explosion_time * 2.0)), 3.0);
	float effects = boom_bw * bubbles + (1.0 - boom_bw) * distortion;
	return shape + effects;
}

float smoke(vec2 p) {
	float repeat = clamp(explosion_time * smoke_repeat, 0.001, 1.999);
	float shape = 1.0 - pow(distance(vec3(p - vec2(0.0, 2.0) * pow(repeat / 1.45, 2.0) * 1.5, 0.0), vec3(0.0)), 2.0) / (repeat * smoke_shape) - pow(repeat * 1.5, 0.5);
	float distortion = noise(vec3(p * smoke_distortion - vec2(0.0, 2.0) * pow(repeat / 1.45, 2.0) * 1.5, explosion_time * 0.1));
	float bubbles = smoke_bubbles - pow(worley(vec3((p / pow(repeat, 0.35)) - vec2(0.0, 2.0) * pow(repeat / 1.65, 2.0) * 1.5, explosion_time * 0.1)), 2.0);
	float effects = smoke_bw * bubbles + (1.0 - smoke_bw) * distortion;
	return shape + effects;
}

float f(vec2 p) {
	float b = boom(p);
	float s = smoke(p);
	return b > s ? b : s;
}

vec2 grad(vec2 x) {
	vec2 h = vec2(0.01, 0.0);
	return vec2(f(x + h.xy) - f(x - h.xy), f(x + h.yx) - f(x - h.yx)) / (2.0 * h.x);
}

float border(vec2 uv) {
	float b = f(uv);
	vec2 g = grad(uv);
	float de = abs(b) / max(length(g), 0.0001);
	float eps = 0.01;
	return smoothstep(1.0 * eps, 2.0 * eps, de);
}

float posterize(float v, float n) {
	return floor(v * n) / max(n - 1.0, 1.0);
}

void fragment() {
	vec2 uv = UV;
	uv.y = 1.0 - uv.y;
	vec2 pos = (uv - vec2(0.5, 0.48)) * vec2(aspect, 1.0);
	pos *= size;
	pos -= disp;

	float boom_val = boom(pos);
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
	boom_col -= vec3(1.0 - boom_a);

	float smoke_val = smoke(pos);
	float smoke_a = step(0.0, smoke_val);
	float smoke_idx = clamp(posterize(smoke_val, 3.0) * 3.0, 0.0, 2.0);
	vec3 smoke_col = smoke_pal1;
	if (smoke_idx >= 2.0) {
		smoke_col = smoke_pal3;
	} else if (smoke_idx >= 1.0) {
		smoke_col = smoke_pal2;
	}
	smoke_col -= vec3(1.0 - smoke_a);

	float b = step(1.0, border(pos));
	float bw = step(smoke_val * 1.25, boom_val);
	vec3 color = bw * boom_col + (1.0 - bw) * smoke_col;
	float alpha = bw * boom_a + (1.0 - bw) * smoke_a;
	alpha *= b;
	alpha *= 1.0 - smoothstep(1.55, 1.95, explosion_time);
	COLOR = vec4(color, alpha);
}
