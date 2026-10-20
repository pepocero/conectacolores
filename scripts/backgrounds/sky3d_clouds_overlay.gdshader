// Nubes 2D inspiradas en Sky3D (noiseClouds + SNoise), para fondos UI.
shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D cumulus_texture : filter_linear_mipmap, repeat_enable;
uniform sampler2D cirrus_texture : filter_linear_mipmap, repeat_enable;
uniform vec2 cumulus_position = vec2(0.0);
uniform vec2 cirrus_position1 = vec2(0.0);
uniform vec2 cirrus_position2 = vec2(0.0);
uniform float coverage : hint_range(0.0, 1.0) = 0.45;
uniform float intensity : hint_range(0.0, 2.0) = 0.85;
uniform float cloud_scale : hint_range(0.2, 4.0) = 1.15;
uniform float soft_edge : hint_range(0.05, 0.8) = 0.32;
uniform float sky_bottom : hint_range(0.05, 1.0) = 0.48;
uniform vec4 cloud_tint : source_color = vec4(1.0, 0.96, 0.92, 1.0);
uniform vec4 cloud_shadow : source_color = vec4(0.75, 0.72, 0.78, 1.0);

float sample_cumulus(vec2 uv) {
	float a = texture(cumulus_texture, uv * cloud_scale + cumulus_position).r;
	float b = texture(cumulus_texture, uv * cloud_scale * 1.73 + cumulus_position * 1.31 + vec2(0.17, 0.31)).r;
	float c = texture(cumulus_texture, uv * cloud_scale * 0.62 + cumulus_position * 0.7 + vec2(0.41, 0.09)).r;
	return a * 0.5 + b * 0.32 + c * 0.18;
}

float sample_cirrus(vec2 uv) {
	float a = texture(cirrus_texture, uv * vec2(0.16, 0.11) + cirrus_position1).r;
	float b = texture(cirrus_texture, uv * vec2(0.16, 0.11) + cirrus_position2).r;
	return (a + b) * 0.5;
}

void fragment() {
	vec2 uv = UV;
	vec2 cloud_uv = vec2(uv.x, uv.y * 0.85);

	float dens = sample_cumulus(cloud_uv);
	float cirrus = sample_cirrus(cloud_uv);
	dens = dens * 0.82 + cirrus * 0.28;

	float cov = 1.0 - coverage;
	dens = smoothstep(cov, cov + soft_edge, dens);

	float mask = 1.0 - smoothstep(sky_bottom - 0.12, sky_bottom + 0.02, uv.y);
	mask *= smoothstep(0.0, 0.06, uv.y);

	float shade = mix(0.55, 1.0, dens);
	vec3 tint = mix(cloud_shadow.rgb, cloud_tint.rgb, shade);
	float alpha = dens * intensity * mask * cloud_tint.a;

	COLOR = vec4(tint, alpha);
}
