shader_type canvas_item;
render_mode unshaded, blend_mix;

// Starfield adaptado (Art of Code / Martijn Steinrucken).
// Perfil ligero en movil: pocas capas, sin vecinos, sin rayos.

uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform int layers : hint_range(1, 8) = 4;
uniform bool use_rays = true;
uniform bool use_neighbors = true;
uniform bool animate = true;
uniform float warp : hint_range(0.05, 3.5) = 0.35;
uniform float time_scale : hint_range(0.0, 2.0) = 1.0;

uniform vec3 nebula_top = vec3(0.12, 0.05, 0.28);
uniform vec3 nebula_mid = vec3(0.04, 0.08, 0.22);
uniform vec3 nebula_bot = vec3(0.02, 0.02, 0.08);
uniform vec4 veil_color = vec4(0.01, 0.01, 0.05, 0.55);
uniform vec4 haze_a = vec4(0.35, 0.1, 0.55, 0.08);
uniform vec4 haze_b = vec4(0.1, 0.25, 0.55, 0.07);

const float PI_F = 3.14159265;

mat2 rot(float theta) {
	float c = cos(theta);
	float s = sin(theta);
	return mat2(vec2(c, -s), vec2(s, c));
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.23, 456.34));
	p += dot(p, p + 45.45);
	return fract(p.x * p.y);
}

float star(vec2 uv, float flare) {
	float d = length(uv);
	float m = 0.02 / max(d, 0.001);
	if (use_rays && flare > 0.001) {
		float rays = max(0.0, 1.0 - abs(uv.x * uv.y * 10000.0));
		m += rays * flare;
		vec2 uvr = uv * rot(PI_F * 0.25);
		rays = max(0.0, 1.0 - abs(uvr.x * uvr.y * 10000.0));
		m += rays * 0.3 * flare;
	}
	m *= smoothstep(1.0, 0.2, d);
	return m;
}

vec3 star_layer(vec2 uv, float t) {
	vec3 col = vec3(0.0);
	vec2 gv = fract(uv) - 0.5;
	vec2 id = floor(uv);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			if (!use_neighbors && (x != 0 || y != 0)) {
				continue;
			}
			vec2 offset = vec2(float(x), float(y));
			float n = hash21(id + offset);
			float size = fract(n * 534.0);
			float flare = use_rays ? smoothstep(0.9, 0.1, size) : 0.0;
			vec2 p = gv - offset - vec2(n - 0.5, fract(n * 165.0) - 0.5);
			float s = star(p, flare);
			vec3 colors = sin(vec3(0.2, 0.3, 0.9) * fract(n * 2434.0) * 123.0) * 0.5 + 0.5;
			colors *= vec3(1.0, 0.5, 1.0 + size);
			if (animate) {
				s *= sin(t * 3.0 + n * 18.3) * 0.5 + 1.0;
			}
			col += s * size * colors;
		}
	}
	return col;
}

void fragment() {
	vec2 frag = UV * viewport_size;
	vec2 uv = (frag - 0.5 * viewport_size) / max(viewport_size.y, 1.0);
	float r = length(uv);
	uv *= 1.0 + warp * 0.08 * r;

	float t = animate ? TIME * 0.05 * time_scale * (0.7 + warp * 0.55) : 0.0;
	if (animate) {
		uv *= rot(t * 0.35);
	}

	float gy = clamp(UV.y, 0.0, 1.0);
	vec3 neb = mix(nebula_top, nebula_mid, smoothstep(0.0, 0.55, gy));
	neb = mix(neb, nebula_bot, smoothstep(0.45, 1.0, gy));
	vec3 col = neb;
	col = mix(col, veil_color.rgb, veil_color.a);

	vec2 ha = (UV - vec2(0.32, 0.40)) * vec2(viewport_size.x / max(viewport_size.y, 1.0), 1.0);
	vec2 hb = (UV - vec2(0.72, 0.66)) * vec2(viewport_size.x / max(viewport_size.y, 1.0), 1.0);
	col += haze_a.rgb * haze_a.a * exp(-dot(ha, ha) * 6.0);
	col += haze_b.rgb * haze_b.a * exp(-dot(hb, hb) * 7.0);

	float n_layers = float(clamp(layers, 1, 8));
	for (int i = 0; i < 8; i++) {
		if (float(i) >= n_layers) {
			break;
		}
		float fi = float(i);
		float depth = fract(fi / n_layers + t);
		float scale = mix(18.0, 0.6, depth);
		float fade = depth * smoothstep(1.0, 0.9, depth);
		col += star_layer(uv * scale + fi * 343.0, TIME * time_scale) * fade;
	}

	COLOR = vec4(col, 1.0);
}
