// Zemin: dünya uzayında katmanlı değer gürültüsü ile çim tonu; uzakta düzleşir (titreme olmasın).
shader_type spatial;

uniform vec3 acik : source_color = vec3(0.42, 0.52, 0.30);
uniform vec3 koyu : source_color = vec3(0.24, 0.33, 0.18);

varying vec3 dunya;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float gurultu(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	dunya = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = dunya.xz;
	float n = gurultu(p * 0.05) * 0.5 + gurultu(p * 0.4) * 0.3 + gurultu(p * 3.0) * 0.2;
	float uzak = clamp(length(CAMERA_POSITION_WORLD - dunya) / 300.0, 0.0, 1.0);
	n = mix(n, 0.5, uzak);
	ALBEDO = mix(koyu, acik, n);
	ROUGHNESS = 0.95;
}
