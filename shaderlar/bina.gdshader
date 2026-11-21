// Bina cephesi: model uzayında kat (3,4 m) ve pencere (2,6 m) ızgarası; cam yansıtır, duvar mat.
// Doku dosyası yok; desen konumdan hesaplanır. Taban rengi köşe renginden (bina başına).
shader_type spatial;

varying vec3 yerel;
varying vec3 dn;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	yerel = VERTEX;
	dn = NORMAL;
}

void fragment() {
	vec3 taban = COLOR.rgb;
	if (abs(dn.y) > 0.5) {
		// Çatı: koyu, hafif lekeli beton.
		float n = hash(floor(yerel.xz * 0.5));
		ALBEDO = taban * (0.45 + 0.1 * n);
		ROUGHNESS = 0.95;
	} else {
		float u = abs(dn.x) > abs(dn.z) ? yerel.z : yerel.x;
		float v = yerel.y;
		float kat = 3.4;
		float fy = fract(v / kat);
		float fx = fract(u / 2.6);
		float pencere = step(0.14, fx) * step(fx, 0.86) * step(0.28, fy) * step(fy, 0.86) * step(0.8, v);
		float kusak = step(0.92, fy);  // kat arası beton kuşak
		// Pencere başına küçük ton farkı: perde, iç ışık.
		float ic = hash(floor(vec2(u / 2.6, v / kat)));
		vec3 cam = mix(vec3(0.08, 0.11, 0.14), vec3(0.22, 0.26, 0.3), ic * 0.6);
		vec3 duvar = taban * (0.92 + 0.08 * hash(floor(vec2(u, v) * 2.0))) * (1.0 - 0.12 * kusak);
		ALBEDO = mix(duvar, cam, pencere);
		METALLIC = pencere * 0.5;
		ROUGHNESS = mix(0.85, 0.08, pencere);
		SPECULAR = mix(0.4, 0.9, pencere);
	}
}
