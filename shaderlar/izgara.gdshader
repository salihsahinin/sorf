// Dünya uzayında ızgara: hız algısı için yüzeylere eşit aralıklı çizgi basar.
shader_type spatial;

uniform vec3 renk : source_color = vec3(0.85, 0.87, 0.9);
uniform vec3 cizgi : source_color = vec3(0.2, 0.25, 0.3);
uniform float aralik = 2.0;
uniform float kalinlik = 0.03;

varying vec3 dunya;

void vertex() {
	dunya = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 g = abs(fract(dunya / aralik) - 0.5);
	float kenar = max(g.x, g.z);
	float c = step(0.5 - kalinlik, kenar);
	ALBEDO = mix(renk, cizgi, c);
	ROUGHNESS = 0.8;
}
